import 'package:flutter_test/flutter_test.dart';
import 'package:kedai_abs/core/constants/app_constants.dart';
import 'package:kedai_abs/core/database/database_helper.dart';
import 'package:kedai_abs/models/order.dart';
import 'package:kedai_abs/models/product.dart';
import 'package:kedai_abs/providers/pos_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late PosProvider pos;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await DatabaseHelper.useDatabaseAtPath(inMemoryDatabasePath);
    pos = PosProvider();
    await pos.loadLocalData();
  });

  tearDown(() => pos.dispose());

  Product firstProduct() => pos.allProducts.firstWhere((p) => p.stock >= 10);

  Future<OrderModel> sell({
    int qty = 2,
    String method = AppConstants.paymentCash,
    String? customer,
  }) async {
    final product = firstProduct();
    for (var i = 0; i < qty; i++) {
      pos.addToCart(product);
    }
    final order = await pos.checkout(
      paymentAmount: pos.cartTotal,
      paymentMethod: method,
      customerName: customer,
    );
    return order!;
  }

  test('cash checkout opens a shift, records payment and deducts stock',
      () async {
    final product = firstProduct();
    final order = await sell(qty: 2);

    expect(order.id, isNotNull);
    expect(order.uuid, isNotNull);
    expect(order.isDebt, isFalse);
    expect(pos.currentShift, isNotNull);
    expect(order.shiftId, pos.currentShift!.id);
    expect(
      pos.allProducts.firstWhere((p) => p.id == product.id).stock,
      product.stock - 2,
    );

    final summary = await pos.loadCurrentShiftSummary();
    expect(summary!.sales.transactionCount, 1);
    expect(summary.sales.revenue, product.sellPrice * 2);
    expect(summary.cashIn, product.sellPrice * 2);
    expect(summary.expectedCash, product.sellPrice * 2);
  });

  test('invoice numbers stay unique for back-to-back sales', () async {
    final invoices = <String>{};
    for (var i = 0; i < 5; i++) {
      invoices.add((await sell(qty: 1)).invoiceNumber);
    }
    expect(invoices.length, 5);
  });

  test('kasbon counts as sale once and repayments as cash only', () async {
    final debt = await sell(
      qty: 2,
      method: AppConstants.paymentDebt,
      customer: 'Mas Joko',
    );
    final total = debt.finalAmount;
    expect(debt.isDebt, isTrue);
    expect(pos.outstandingDebt, total);
    expect(pos.debtOrders.single.customerName, 'Mas Joko');

    var summary = await pos.loadCurrentShiftSummary();
    expect(summary!.sales.revenue, total);
    expect(summary.newDebt, total);
    expect(summary.cashIn, 0);

    final partial = (total / 2).roundToDouble();
    expect(
      await pos.receiveDebtPayment(debt, partial, AppConstants.paymentCash),
      isNull,
    );
    expect(pos.debtOrders.single.outstandingAmount, total - partial);

    // Overpaying the remaining balance is rejected.
    expect(
      await pos.receiveDebtPayment(
        pos.debtOrders.single,
        total,
        AppConstants.paymentCash,
      ),
      isNotNull,
    );

    expect(
      await pos.receiveDebtPayment(
        pos.debtOrders.single,
        total - partial,
        AppConstants.paymentQris,
      ),
      isNull,
    );
    expect(pos.debtOrders, isEmpty);
    expect(pos.outstandingDebt, 0);

    summary = await pos.loadCurrentShiftSummary();
    expect(summary!.sales.revenue, total, reason: 'repayment is not a sale');
    expect(summary.debtCollected, total);
    expect(summary.cashIn, partial);
    expect(summary.paymentsByMethod[AppConstants.paymentQris], total - partial);
  });

  test('kasbon requires a customer name', () async {
    pos.addToCart(firstProduct());
    expect(
      () => pos.checkout(
        paymentAmount: 0,
        paymentMethod: AppConstants.paymentDebt,
      ),
      throwsArgumentError,
    );
  });

  test('open bills persist across app restarts', () async {
    final product = firstProduct();
    pos.setSelectedTable('Meja 03');
    pos.addToCart(product);
    pos.addToCart(product);
    expect(await pos.holdCurrentCartToTable(), isTrue);
    expect(pos.cartCount, 0);

    final restarted = PosProvider();
    addTearDown(restarted.dispose);
    await restarted.loadLocalData();
    expect(restarted.heldTableOrders['Meja 03']!.single.quantity, 2);

    expect(restarted.resumeHeldTableOrder('Meja 03'), isTrue);
    expect(restarted.cartCount, 2);
    expect(restarted.closingBlocker, isNotNull);

    // Clearing a resumed bill returns it to the table list.
    restarted.clearCart();
    await restarted.loadLocalData();
    expect(restarted.heldTableOrders.containsKey('Meja 03'), isTrue);

    expect(restarted.resumeHeldTableOrder('Meja 03'), isTrue);
    await restarted.checkout(
      paymentAmount: restarted.cartTotal,
      paymentMethod: AppConstants.paymentCash,
    );
    await restarted.loadLocalData();
    expect(restarted.heldTableOrders, isEmpty);
    expect(restarted.closingBlocker, isNull);
  });

  test('resume refuses to mix bills into a non-empty cart', () async {
    final product = firstProduct();
    pos.addToCart(product);
    await pos.holdCurrentCartToTable('Meja 01');
    pos.addToCart(product);
    expect(pos.resumeHeldTableOrder('Meja 01'), isFalse);
    expect(pos.heldTableOrders.containsKey('Meja 01'), isTrue);
  });

  test('closing locks the shift and the next sale starts a new one', () async {
    final first = await sell(qty: 1);
    await pos.setOpeningCash(50000);

    final closed = await pos.closeCurrentShift(countedCash: 50000);
    expect(closed.shift.isOpen, isFalse);
    expect(closed.expectedCash, 50000 + first.finalAmount);
    expect(closed.shift.cashDifference, -first.finalAmount);
    expect(pos.currentShift, isNull);

    final second = await sell(qty: 1);
    expect(second.shiftId, isNot(first.shiftId));
    final summary = await pos.loadCurrentShiftSummary();
    expect(summary!.sales.transactionCount, 1);
  });

  test('backup restores all data and rejects foreign files', () async {
    final order = await sell(
      qty: 1,
      method: AppConstants.paymentDebt,
      customer: 'Bu Sri',
    );
    pos.addToCart(firstProduct());
    await pos.holdCurrentCartToTable('Meja 05');
    final backup = await pos.exportBackupJson();

    await DatabaseHelper.useDatabaseAtPath(inMemoryDatabasePath);
    final fresh = PosProvider();
    addTearDown(fresh.dispose);
    await fresh.loadLocalData();
    expect(fresh.debtOrders, isEmpty);

    await fresh.restoreBackupJson(backup);
    expect(fresh.debtOrders.single.uuid, order.uuid);
    expect(fresh.outstandingDebt, order.finalAmount);
    expect(fresh.heldTableOrders.containsKey('Meja 05'), isTrue);
    expect(fresh.currentShift, isNotNull);

    expect(
      () => fresh.restoreBackupJson('{"app":"lain"}'),
      throwsFormatException,
    );
    expect(() => fresh.restoreBackupJson('bukan json'), throwsFormatException);
  });

  test('restoring a pre-v5 backup backfills payments for paid orders',
      () async {
    final legacy = await pos.exportBackupJson();
    // Simulate an old backup: no payment ledger, no v5 order columns.
    final legacyWithOrder = legacy
        .replaceFirst(
          '"schema_version":${AppConstants.dbVersion}',
          '"schema_version":4',
        )
        .replaceFirst(
          '"orders":[]',
          '"orders":[{"id":7,"invoice_number":"INV-LAMA","created_at":"2026-01-02T10:00:00.000",'
              '"total_amount":15000,"discount_amount":0,"final_amount":15000,'
              '"payment_amount":20000,"change_amount":5000,"payment_method":"Tunai",'
              '"status":"selesai","cost_known":1}]',
        );
    expect(legacyWithOrder, contains('INV-LAMA'));
    expect(legacyWithOrder, contains('"schema_version":4'));

    await pos.restoreBackupJson(legacyWithOrder);
    await pos.setReportRange('all');
    final restored = pos.reportOrders.single;
    expect(restored.uuid, 'legacy-7');
    expect(restored.isDebt, isFalse);
    expect(restored.paidAmount, 15000);
    expect(pos.reportSummary.revenue, 15000);
  });
}
