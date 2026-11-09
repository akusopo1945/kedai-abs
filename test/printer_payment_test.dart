import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kedai_abs/core/constants/app_constants.dart';
import 'package:kedai_abs/core/database/database_helper.dart';
import 'package:kedai_abs/core/services/printer_service.dart';
import 'package:kedai_abs/models/order.dart';
import 'package:kedai_abs/models/payment_settings.dart';
import 'package:kedai_abs/models/store_profile.dart';
import 'package:kedai_abs/providers/pos_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

int _count(List<int> haystack, List<int> needle) {
  var count = 0;
  for (var i = 0; i + needle.length <= haystack.length; i++) {
    var match = true;
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) {
        match = false;
        break;
      }
    }
    if (match) count++;
  }
  return count;
}

const _init = [0x1B, 0x40];
const _drawer = [0x1B, 0x70, 0x00, 0x19, 0xFA];
const _cut = [0x1D, 0x56, 0x42, 0x00];
const _boldOn = [0x1B, 0x45, 0x01];

OrderModel _order({String method = 'Tunai', String? note}) => OrderModel(
      invoiceNumber: 'INV-20261109-183455-AB12',
      createdAt: DateTime(2026, 11, 9, 18, 34),
      totalAmount: 21000,
      finalAmount: 21000,
      paymentAmount: 50000,
      changeAmount: 29000,
      paymentMethod: method,
      paymentNote: note,
      customerName: 'Mbak Ayu',
      tableNumber: 'Meja 07',
      items: [
        OrderItem(
          productId: 1,
          productName: 'Wedang Uwuh Kraton Spesial Rempah Lengkap',
          selectedOption: 'Panas',
          unitPrice: 7000,
          buyPrice: 2500,
          quantity: 3,
          subtotal: 21000,
        ),
      ],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];

  void mockChannel(Future<Object?>? Function(MethodCall call) handler) {
    calls.clear();
    messenger.setMockMethodCallHandler(PrinterService.channel, (call) {
      calls.add(call);
      return handler(call);
    });
  }

  tearDown(
      () => messenger.setMockMethodCallHandler(PrinterService.channel, null));

  group('Receipt layout', () {
    for (final paper in [58, 80]) {
      test('every line fits $paper mm paper', () {
        final width = ReceiptBuilder.widthForPaper(paper);
        final lines = PrinterService.instance.buildReceipt(
          order: _order(
              method: 'Transfer',
              note: 'Ke BCA 1234567890 a.n. Kedai Bersua Sejenak | Ref 998877'),
          store: StoreProfile(
              name: 'Angkringan Bersua Sejenak', paperWidth: paper),
        );
        for (final line in lines) {
          expect(line.text.length, lessThanOrEqualTo(width), reason: line.text);
        }
        final text = PrinterService.instance.renderText(lines);
        expect(text, contains('Ref 998877'));
        expect(text, contains('Transfer'));
        expect(text, isNot(contains('Kembalian')));
      });
    }

    test('pair falls back to two lines when it does not fit', () {
      final b = ReceiptBuilder(16)..pair('Pelanggan Setia', 'Rp 150.000');
      expect(
          b.lines.map((l) => l.text), ['Pelanggan Setia', '      Rp 150.000']);
    });

    test('sanitize keeps printable ASCII only', () {
      expect(ReceiptBuilder.sanitize('Kopi • Café “joss” – 5€'),
          'Kopi - Cafe "joss" - 5?');
    });

    test('debt receipt shows remaining balance', () {
      final debt = OrderModel(
        invoiceNumber: 'INV-1',
        createdAt: DateTime(2026),
        totalAmount: 10000,
        finalAmount: 10000,
        paymentAmount: 0,
        changeAmount: 0,
        paymentMethod: AppConstants.paymentDebt,
        paymentStatus: OrderModel.paymentUnpaid,
      );
      final text = PrinterService.instance
          .generateReceiptText(order: debt, store: StoreProfile());
      expect(text, contains('SISA KASBON'));
      expect(text, contains('BELUM LUNAS'));
    });
  });

  group('ESC/POS bytes', () {
    final lines = [
      const ReceiptLine('TOTAL', bold: true, large: true),
      const ReceiptLine('biasa'),
    ];

    test('initializes, styles, and resets', () {
      final bytes = PrinterService.instance.renderEscPos(lines);
      expect(bytes.sublist(0, 2), _init);
      expect(_count(bytes, _boldOn), 1);
      expect(_count(bytes, _drawer), 0);
      expect(_count(bytes, _cut), 0);
      expect(_count(bytes, ascii.encode('TOTAL')), 1);
    });

    test('copies, cut and drawer options', () {
      final bytes = PrinterService.instance
          .renderEscPos(lines, copies: 2, cut: true, openDrawer: true);
      expect(_count(bytes, _init), 2);
      expect(_count(bytes, _cut), 2);
      expect(_count(bytes, _drawer), 1, reason: 'drawer opens once');
    });
  });

  group('Bluetooth channel', () {
    const settings =
        PrinterSettings(address: '00:11:22:33:44:55', name: 'RPP02');

    test('lists paired printers sorted by name', () async {
      mockChannel((call) async => [
            {'name': 'Zebra', 'address': 'AA:AA:AA:AA:AA:AA'},
            {'name': 'Mini Printer', 'address': 'BB:BB:BB:BB:BB:BB'},
          ]);
      final devices = await PrinterService.instance.pairedPrinters();
      expect(devices.map((d) => d.name), ['Mini Printer', 'Zebra']);
    });

    test('sends bytes to the configured address', () async {
      mockChannel((call) async => true);
      await PrinterService.instance.printLines(
        [const ReceiptLine('halo')],
        settings,
      );
      expect(calls.single.method, 'print');
      final args = calls.single.arguments as Map;
      expect(args['address'], settings.address);
      expect(args['bytes'], isA<Uint8List>());
    });

    test('maps native errors to readable messages', () async {
      mockChannel((call) async =>
          throw PlatformException(code: 'BLUETOOTH_OFF', message: 'off'));
      await expectLater(
        PrinterService.instance.printLines([const ReceiptLine('x')], settings),
        throwsA(
          isA<PrinterException>()
              .having((e) => e.code, 'code', 'BLUETOOTH_OFF')
              .having((e) => e.message, 'message', contains('Nyalakan')),
        ),
      );
    });

    test('requires a selected printer', () async {
      await expectLater(
        PrinterService.instance
            .printLines([const ReceiptLine('x')], const PrinterSettings()),
        throwsA(isA<PrinterException>()
            .having((e) => e.code, 'code', 'NO_PRINTER')),
      );
    });
  });

  group('Payment settings and printing with the database', () {
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

    test('settings, QRIS image and accounts persist', () async {
      await pos.savePaymentSettings(
        pos.paymentSettings.copyWith(
          debtEnabled: false,
          requireReference: true,
          bankAccounts: const [
            BankAccount(
              bankName: 'BCA',
              accountNumber: '1234567890',
              accountHolder: 'Kedai ABS',
            ),
          ],
        ),
      );
      final qris = Uint8List.fromList(List.generate(300, (i) => i % 256));
      expect(await pos.saveQrisImage(qris), isNull);
      expect(
        await pos.saveQrisImage(
          Uint8List(PosProvider.maxQrisImageBytes + 1),
        ),
        isNotNull,
      );

      final reloaded = PosProvider();
      addTearDown(reloaded.dispose);
      await reloaded.loadLocalData();
      expect(reloaded.paymentSettings.bankAccounts.single.bankName, 'BCA');
      expect(reloaded.paymentSettings.requireReference, isTrue);
      expect(reloaded.qrisImage, qris);
      expect(reloaded.enabledPaymentMethods,
          isNot(contains(AppConstants.paymentDebt)));
      expect(reloaded.enabledSettlementMethods, [
        AppConstants.paymentCash,
        AppConstants.paymentQris,
        AppConstants.paymentTransfer
      ]);
    });

    test('checkout stores the payment note and backup keeps settings',
        () async {
      final qris = Uint8List.fromList([1, 2, 3, 4]);
      await pos.saveQrisImage(qris);
      pos.addToCart(pos.allProducts.firstWhere((p) => p.stock > 0));
      final order = await pos.checkout(
        paymentAmount: pos.cartTotal,
        paymentMethod: AppConstants.paymentTransfer,
        paymentNote: '  Ke BCA 123 | Ref 77  ',
      );
      expect(order!.paymentNote, 'Ke BCA 123 | Ref 77');

      final backup = await pos.exportBackupJson();
      await DatabaseHelper.useDatabaseAtPath(inMemoryDatabasePath);
      final fresh = PosProvider();
      addTearDown(fresh.dispose);
      await fresh.loadLocalData();
      expect(fresh.qrisImage, isNull);
      await fresh.restoreBackupJson(backup);
      expect(fresh.qrisImage, qris);
      await fresh.setReportRange('all');
      expect(fresh.reportOrders.single.paymentNote, 'Ke BCA 123 | Ref 77');
    });

    test('auto-print after a cash sale opens the drawer once', () async {
      mockChannel((call) async => true);
      await pos.savePrinterSettings(
        const PrinterSettings(
          address: '00:11:22:33:44:55',
          autoPrint: true,
          openCashDrawer: true,
          copies: 2,
        ),
      );
      calls.clear();
      pos.addToCart(pos.allProducts.firstWhere((p) => p.stock > 0));
      final order = await pos.checkout(
        paymentAmount: 100000,
        paymentMethod: AppConstants.paymentCash,
      );
      expect(await pos.handleCompletedSale(order!), isNull);
      final printCall = calls.singleWhere((c) => c.method == 'print');
      final bytes = (printCall.arguments as Map)['bytes'] as Uint8List;
      expect(_count(bytes, _drawer), 1);
      expect(_count(bytes, _init), 2);

      // Reprints never open the drawer.
      calls.clear();
      expect(await pos.printReceipt(order), isNull);
      final reprint = (calls.single.arguments as Map)['bytes'] as Uint8List;
      expect(_count(reprint, _drawer), 0);
    });

    test('non-cash sale with drawer only does not kick the drawer', () async {
      mockChannel((call) async => true);
      await pos.savePrinterSettings(
        const PrinterSettings(
          address: '00:11:22:33:44:55',
          openCashDrawer: true,
        ),
      );
      calls.clear();
      pos.addToCart(pos.allProducts.firstWhere((p) => p.stock > 0));
      final order = await pos.checkout(
        paymentAmount: 0,
        paymentMethod: AppConstants.paymentQris,
      );
      expect(await pos.handleCompletedSale(order!), isNull);
      expect(calls.where((c) => c.method == 'print'), isEmpty);
    });

    test('print failure is reported, sale stays saved', () async {
      mockChannel((call) async => call.method == 'print'
          ? throw PlatformException(code: 'PRINT_FAILED')
          : null);
      await pos.savePrinterSettings(
        const PrinterSettings(address: '00:11:22:33:44:55', autoPrint: true),
      );
      pos.addToCart(pos.allProducts.firstWhere((p) => p.stock > 0));
      final order = await pos.checkout(
        paymentAmount: 100000,
        paymentMethod: AppConstants.paymentCash,
      );
      final error = await pos.handleCompletedSale(order!);
      expect(error, contains('Gagal mencetak'));
      await pos.setReportRange('all');
      expect(pos.reportOrders.map((o) => o.id), contains(order.id));
    });
  });
}
