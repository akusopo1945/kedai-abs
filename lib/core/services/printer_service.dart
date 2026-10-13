import '../../models/order.dart';
import '../../models/store_profile.dart';
import '../utils/currency_formatter.dart';

class PrinterService {
  static final PrinterService instance = PrinterService._();
  PrinterService._();

  bool isConnected = false;
  String? connectedDeviceName;

  /// Generate plain-text thermal receipt representation
  String generateReceiptText({
    required OrderModel order,
    required StoreProfile store,
  }) {
    final buffer = StringBuffer();
    final width = store.paperWidth == 80 ? 42 : 32;
    final divider = '=' * width;
    final dashDivider = '-' * width;

    // Header (Center aligned)
    buffer.writeln(_centerText(store.name.toUpperCase(), width));
    buffer.writeln(_centerText(store.address, width));
    buffer.writeln(_centerText('Telp: ${store.phone}', width));
    buffer.writeln(divider);

    // Order Info
    buffer.writeln('No. Struk : ${order.invoiceNumber}');
    buffer.writeln('Waktu     : ${CurrencyFormatter.formatDate(order.createdAt)}');
    if (order.customerName != null && order.customerName!.isNotEmpty) {
      buffer.writeln('Pelanggan : ${order.customerName}');
    }
    buffer.writeln('Metode    : ${order.paymentMethod.toUpperCase()}');
    buffer.writeln(dashDivider);

    // Items
    for (final item in order.items) {
      buffer.writeln(item.productName);
      final qtyAndPrice = '  ${item.quantity} x ${CurrencyFormatter.format(item.unitPrice)}';
      final subtotal = CurrencyFormatter.format(item.subtotal);
      buffer.writeln(_twoColumnText(qtyAndPrice, subtotal, width));
    }

    buffer.writeln(dashDivider);

    // Totals
    buffer.writeln(_twoColumnText('Total', CurrencyFormatter.format(order.totalAmount), width));
    if (order.discountAmount > 0) {
      buffer.writeln(_twoColumnText('Diskon', '-${CurrencyFormatter.format(order.discountAmount)}', width));
    }
    buffer.writeln(_twoColumnText('Total Bayar', CurrencyFormatter.format(order.finalAmount), width));
    buffer.writeln(_twoColumnText('Tunai Diterima', CurrencyFormatter.format(order.paymentAmount), width));
    buffer.writeln(_twoColumnText('Kembalian', CurrencyFormatter.format(order.changeAmount), width));

    buffer.writeln(divider);

    // Footer
    for (final line in store.receiptFooter.split('\n')) {
      buffer.writeln(_centerText(line.trim(), width));
    }
    buffer.writeln('\n\n'); // Feed lines

    return buffer.toString();
  }

  String _centerText(String text, int width) {
    if (text.length >= width) return text.substring(0, width);
    final leftPadding = (width - text.length) ~/ 2;
    return ' ' * leftPadding + text;
  }

  String _twoColumnText(String left, String right, int width) {
    final space = width - left.length - right.length;
    if (space > 0) {
      return left + (' ' * space) + right;
    }
    return '$left $right';
  }
}
