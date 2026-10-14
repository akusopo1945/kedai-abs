import 'package:flutter_test/flutter_test.dart';
import 'package:kedai_abs/core/services/printer_service.dart';
import 'package:kedai_abs/core/utils/currency_formatter.dart';
import 'package:kedai_abs/models/cart_item.dart';
import 'package:kedai_abs/models/order.dart';
import 'package:kedai_abs/models/product.dart';
import 'package:kedai_abs/models/store_profile.dart';

void main() {
  group('Product Model Tests', () {
    test('Calculates profit and profitMargin correctly', () {
      final product = Product(
        name: 'Kopi Susu Aren',
        category: 'Minuman',
        buyPrice: 8000,
        sellPrice: 18000,
        stock: 50,
      );

      expect(product.profit, 10000);
      expect(product.profitMargin, closeTo(55.55, 0.01));
    });
  });

  group('CartItem Model Tests', () {
    test('Calculates subtotal and total profit with quantity', () {
      final product = Product(
        name: 'Croissant Butter',
        category: 'Makanan',
        buyPrice: 12000,
        sellPrice: 25000,
        stock: 10,
      );

      final cartItem = CartItem(product: product, quantity: 3);
      expect(cartItem.subtotal, 75000);
      expect(cartItem.totalProfit, 39000);
    });
  });

  group('CurrencyFormatter Tests', () {
    test('Formats IDR currency correctly', () {
      expect(CurrencyFormatter.format(15000), contains('15.000'));
      expect(CurrencyFormatter.format(0), contains('0'));
    });

    test('Short format works for big amounts', () {
      expect(CurrencyFormatter.formatShort(1500000), contains('1.5 jt'));
      expect(CurrencyFormatter.formatShort(50000), contains('50 rb'));
    });
  });

  group('PrinterService Tests', () {
    test('Generates structured receipt text with store header and items', () {
      final store = StoreProfile(
        name: 'Kedai Berkah',
        address: 'Jl. Sudirman No. 1',
        phone: '08123456789',
        paperWidth: 58,
      );

      final order = OrderModel(
        invoiceNumber: 'INV-20261013-0001',
        createdAt: DateTime(2026, 10, 13, 14, 30),
        tableNumber: 'Meja 04',
        totalAmount: 36000,
        discountAmount: 0,
        finalAmount: 36000,
        paymentAmount: 50000,
        changeAmount: 14000,
        paymentMethod: 'Tunai',
        items: [
          OrderItem(
            productId: 1,
            productName: 'Sate Kulit Ayam Madu',
            selectedOption: 'Bakar Pedas Membara',
            unitPrice: 18000,
            buyPrice: 8000,
            quantity: 2,
            subtotal: 36000,
          ),
        ],
      );

      final receipt = PrinterService.instance.generateReceiptText(
        order: order,
        store: store,
      );

      expect(receipt, contains('KEDAI BERKAH'));
      expect(receipt, contains('INV-20261013-0001'));
      expect(receipt, contains('Meja 04'));
      expect(receipt, contains('Sate Kulit Ayam Madu (Bakar Pedas Membara)'));
      expect(receipt, contains('Kembalian'));
    });
  });
}
