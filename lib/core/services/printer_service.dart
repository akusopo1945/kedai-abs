import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';

import '../../models/order.dart';
import '../../models/payment_settings.dart';
import '../../models/store_profile.dart';
import '../constants/app_constants.dart';
import '../utils/currency_formatter.dart';

/// One laid-out receipt line. [text] is already padded and never exceeds the
/// paper width, so plain-text and ESC/POS output share the same layout.
class ReceiptLine {
  final String text;
  final bool bold;

  /// Double-height text; width is unchanged so padding stays valid.
  final bool large;

  const ReceiptLine(this.text, {this.bold = false, this.large = false});
}

enum ReceiptAlign { left, center, right }

class ReceiptBuilder {
  final int width;
  final List<ReceiptLine> lines = [];

  ReceiptBuilder(this.width);

  /// Characters per line for Font A on common thermal printers.
  static int widthForPaper(int paperWidthMm) => paperWidthMm >= 80 ? 48 : 32;

  void text(
    String value, {
    ReceiptAlign align = ReceiptAlign.left,
    bool bold = false,
    bool large = false,
  }) {
    for (final raw in sanitize(value).split('\n')) {
      for (final chunk in _wrap(raw.trim())) {
        lines.add(ReceiptLine(_align(chunk, align), bold: bold, large: large));
      }
    }
  }

  void divider([String char = '-']) => lines.add(ReceiptLine(char * width));

  void blank() => lines.add(const ReceiptLine(''));

  /// Label on the left, value on the right; wraps when they do not fit.
  void pair(String left, String right,
      {bool bold = false, bool large = false}) {
    final l = sanitize(left).trim();
    final r = sanitize(right).trim();
    if (l.length + 1 + r.length <= width) {
      lines.add(
        ReceiptLine(
          l + ' ' * (width - l.length - r.length) + r,
          bold: bold,
          large: large,
        ),
      );
      return;
    }
    text(l, bold: bold, large: large);
    text(r, align: ReceiptAlign.right, bold: bold, large: large);
  }

  String _align(String value, ReceiptAlign align) {
    final space = width - value.length;
    if (space <= 0) return value;
    switch (align) {
      case ReceiptAlign.left:
        return value;
      case ReceiptAlign.center:
        return ' ' * (space ~/ 2) + value;
      case ReceiptAlign.right:
        return ' ' * space + value;
    }
  }

  List<String> _wrap(String value) {
    if (value.isEmpty) return [''];
    final result = <String>[];
    var current = '';
    for (var word in value.split(RegExp(r'\s+'))) {
      while (word.length > width) {
        if (current.isNotEmpty) {
          result.add(current);
          current = '';
        }
        result.add(word.substring(0, width));
        word = word.substring(width);
      }
      if (word.isEmpty) continue;
      if (current.isEmpty) {
        current = word;
      } else if (current.length + 1 + word.length <= width) {
        current = '$current $word';
      } else {
        result.add(current);
        current = word;
      }
    }
    if (current.isNotEmpty) result.add(current);
    return result;
  }

  static const Map<String, String> _replacements = {
    '\u00A0': ' ',
    '\u2022': '-',
    '\u2013': '-',
    '\u2014': '-',
    '\u2018': "'",
    '\u2019': "'",
    '\u201C': '"',
    '\u201D': '"',
    '\u2026': '...',
    'à': 'a',
    'á': 'a',
    'â': 'a',
    'ä': 'a',
    'À': 'A',
    'Á': 'A',
    'è': 'e',
    'é': 'e',
    'ê': 'e',
    'ë': 'e',
    'È': 'E',
    'É': 'E',
    'ì': 'i',
    'í': 'i',
    'î': 'i',
    'ï': 'i',
    'ò': 'o',
    'ó': 'o',
    'ô': 'o',
    'ö': 'o',
    'Ó': 'O',
    'Ö': 'O',
    'ù': 'u',
    'ú': 'u',
    'û': 'u',
    'ü': 'u',
    'Ü': 'U',
    'ñ': 'n',
    'Ñ': 'N',
    'ç': 'c',
    'Ç': 'C',
  };

  /// Thermal printers use 8-bit code pages; keep receipts printable ASCII.
  static String sanitize(String value) {
    final buffer = StringBuffer();
    for (final rune in value.runes) {
      final char = String.fromCharCode(rune);
      final replacement = _replacements[char];
      if (replacement != null) {
        buffer.write(replacement);
      } else if (rune == 0x0A || (rune >= 0x20 && rune <= 0x7E)) {
        buffer.write(char);
      } else if (rune == 0x09) {
        buffer.write(' ');
      } else {
        buffer.write('?');
      }
    }
    return buffer.toString();
  }
}

class PrinterException implements Exception {
  final String code;
  final String message;

  const PrinterException(this.code, this.message);

  @override
  String toString() => message;
}

class BluetoothPrinterDevice {
  final String name;
  final String address;

  const BluetoothPrinterDevice({required this.name, required this.address});
}

class PrinterService {
  static final PrinterService instance = PrinterService._();
  PrinterService._();

  static const MethodChannel channel =
      MethodChannel('kedai_abs/bluetooth_printer');

  // ESC/POS commands.
  static const List<int> _init = [0x1B, 0x40];
  static const List<int> _boldOn = [0x1B, 0x45, 0x01];
  static const List<int> _boldOff = [0x1B, 0x45, 0x00];
  static const List<int> _sizeLarge = [0x1D, 0x21, 0x01];
  static const List<int> _sizeNormal = [0x1D, 0x21, 0x00];
  static const List<int> _partialCut = [0x1D, 0x56, 0x42, 0x00];
  static const List<int> _openDrawer = [0x1B, 0x70, 0x00, 0x19, 0xFA];

  /// Plain-text receipt, used for copy/share and as the printed layout.
  String generateReceiptText({
    required OrderModel order,
    required StoreProfile store,
  }) {
    return renderText(buildReceipt(order: order, store: store));
  }

  List<ReceiptLine> buildReceipt({
    required OrderModel order,
    required StoreProfile store,
  }) {
    final b = ReceiptBuilder(ReceiptBuilder.widthForPaper(store.paperWidth));
    b.text(store.name.toUpperCase(),
        align: ReceiptAlign.center, bold: true, large: true);
    if (store.address.trim().isNotEmpty) {
      b.text(store.address, align: ReceiptAlign.center);
    }
    if (store.phone.trim().isNotEmpty) {
      b.text('Telp: ${store.phone}', align: ReceiptAlign.center);
    }
    b.divider('=');

    b.pair('No', order.invoiceNumber);
    b.pair('Waktu', CurrencyFormatter.formatDate(order.createdAt));
    if (order.tableNumber != null && order.tableNumber!.isNotEmpty) {
      b.pair('Meja', order.tableNumber!);
    }
    if (order.customerName != null && order.customerName!.isNotEmpty) {
      b.pair('Pelanggan', order.customerName!);
    }
    b.divider();

    for (final item in order.items) {
      final option =
          item.selectedOption != null && item.selectedOption!.isNotEmpty
              ? ' (${item.selectedOption})'
              : '';
      b.text('${item.productName}$option');
      b.pair(
        '  ${item.quantity} x ${CurrencyFormatter.format(item.unitPrice)}',
        CurrencyFormatter.format(item.subtotal),
      );
      if (item.note != null && item.note!.trim().isNotEmpty) {
        b.text('  Catatan: ${item.note}');
      }
    }
    b.divider();

    if (order.discountAmount > 0) {
      b.pair('Subtotal', CurrencyFormatter.format(order.totalAmount));
      b.pair('Diskon', '-${CurrencyFormatter.format(order.discountAmount)}');
    }
    b.pair('TOTAL', CurrencyFormatter.format(order.finalAmount),
        bold: true, large: true);

    if (order.isDebt) {
      b.pair('Metode', AppConstants.paymentDebt);
      b.pair('Dibayar', CurrencyFormatter.format(order.paidAmount));
      b.pair('SISA KASBON', CurrencyFormatter.format(order.outstandingAmount),
          bold: true);
    } else if (order.paymentMethod == AppConstants.paymentDebt) {
      b.pair('Metode', AppConstants.paymentDebt);
      b.pair('Status', 'LUNAS', bold: true);
    } else if (AppConstants.isCashMethod(order.paymentMethod)) {
      b.pair('Tunai', CurrencyFormatter.format(order.paymentAmount));
      b.pair('Kembalian', CurrencyFormatter.format(order.changeAmount));
    } else {
      b.pair('Metode', order.paymentMethod);
    }
    if (order.paymentNote != null && order.paymentNote!.trim().isNotEmpty) {
      b.text(order.paymentNote!);
    }

    b.divider('=');
    if (order.isDebt) {
      b.text('** BELUM LUNAS **', align: ReceiptAlign.center, bold: true);
    }
    for (final line in store.receiptFooter.split('\n')) {
      if (line.trim().isNotEmpty) b.text(line, align: ReceiptAlign.center);
    }
    return b.lines;
  }

  /// Simple document from `Label: value` lines, e.g. a closing report.
  List<ReceiptLine> buildDocument({
    required String title,
    required List<String> body,
    required int paperWidth,
  }) {
    final b = ReceiptBuilder(ReceiptBuilder.widthForPaper(paperWidth));
    b.text(title, align: ReceiptAlign.center, bold: true, large: true);
    b.divider('=');
    for (final line in body) {
      final separator = line.indexOf(': ');
      if (separator > 0) {
        b.pair(line.substring(0, separator), line.substring(separator + 2));
      } else {
        b.text(line);
      }
    }
    b.divider('=');
    b.text(CurrencyFormatter.formatDate(DateTime.now()),
        align: ReceiptAlign.center);
    return b.lines;
  }

  List<ReceiptLine> buildTestPage(StoreProfile store) {
    final width = ReceiptBuilder.widthForPaper(store.paperWidth);
    final b = ReceiptBuilder(width);
    b.text('TES PRINTER', align: ReceiptAlign.center, bold: true, large: true);
    b.text(store.name, align: ReceiptAlign.center);
    b.divider('=');
    b.text('Kertas ${store.paperWidth} mm, $width karakter per baris.');
    b.text('1234567890' * (width ~/ 10 + 1));
    b.pair('Kiri', 'Kanan');
    b.pair('Tebal', CurrencyFormatter.format(15000), bold: true);
    b.divider();
    b.text('Jika garis di atas tidak terpotong dan teks rapi, '
        'printer siap digunakan.');
    return b.lines;
  }

  String renderText(List<ReceiptLine> lines) =>
      lines.map((line) => line.text.trimRight()).join('\n');

  Uint8List renderEscPos(
    List<ReceiptLine> lines, {
    int copies = 1,
    bool cut = false,
    bool openDrawer = false,
    int feedLines = 4,
  }) {
    final bytes = BytesBuilder(copy: false);
    final count = copies.clamp(1, 3);
    for (var copy = 0; copy < count; copy++) {
      bytes.add(_init);
      if (openDrawer && copy == 0) bytes.add(_openDrawer);
      var bold = false;
      var large = false;
      for (final line in lines) {
        if (line.bold != bold) {
          bytes.add(line.bold ? _boldOn : _boldOff);
          bold = line.bold;
        }
        if (line.large != large) {
          bytes.add(line.large ? _sizeLarge : _sizeNormal);
          large = line.large;
        }
        bytes.add(ascii.encode(line.text.trimRight()));
        bytes.addByte(0x0A);
      }
      if (bold) bytes.add(_boldOff);
      if (large) bytes.add(_sizeNormal);
      bytes.add([0x1B, 0x64, feedLines]);
      if (cut) bytes.add(_partialCut);
    }
    return bytes.takeBytes();
  }

  Uint8List drawerKickBytes() => Uint8List.fromList([..._init, ..._openDrawer]);

  // --- Bluetooth (classic SPP, paired devices only) ---
  Future<List<BluetoothPrinterDevice>> pairedPrinters() async {
    final result = await _invoke<List<Object?>>('getPairedPrinters');
    return [
      for (final item in result ?? const <Object?>[])
        if (item is Map)
          BluetoothPrinterDevice(
            name: item['name'] as String? ?? 'Tanpa nama',
            address: item['address'] as String,
          ),
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  Future<void> sendBytes(String address, Uint8List bytes) async {
    await _invoke<Object?>(
      'print',
      {'address': address, 'bytes': bytes},
    );
  }

  Future<void> disconnect() async {
    try {
      await channel.invokeMethod<void>('disconnect');
    } on Object {
      // Nothing to release when the channel is unavailable.
    }
  }

  Future<T?> _invoke<T>(String method, [Object? arguments]) async {
    try {
      return await channel
          .invokeMethod<T>(method, arguments)
          .timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw const PrinterException(
        'TIMEOUT',
        'Printer tidak merespons. Pastikan printer menyala dan dekat dengan HP.',
      );
    } on MissingPluginException {
      throw const PrinterException(
        'UNSUPPORTED',
        'Cetak Bluetooth hanya tersedia di aplikasi Android.',
      );
    } on PlatformException catch (e) {
      throw PrinterException(e.code, _messageFor(e));
    }
  }

  static String _messageFor(PlatformException e) {
    switch (e.code) {
      case 'PERMISSION_DENIED':
        return 'Izin Bluetooth ditolak. Izinkan "Perangkat di sekitar" untuk '
            'Kedai POS di Pengaturan Android.';
      case 'BLUETOOTH_UNAVAILABLE':
        return 'HP ini tidak mendukung Bluetooth.';
      case 'BLUETOOTH_OFF':
        return 'Bluetooth mati. Nyalakan Bluetooth lalu coba lagi.';
      case 'INVALID_ADDRESS':
        return 'Printer tidak valid. Pilih ulang printer di Pengaturan.';
      case 'PRINT_FAILED':
        return 'Gagal mencetak. Pastikan printer menyala, sudah dipasangkan, '
            'dan tidak sedang dipakai HP lain.';
      default:
        return e.message ?? 'Printer error (${e.code}).';
    }
  }

  /// Prints [lines] with the user's printer settings. Throws
  /// [PrinterException] when no printer is configured or printing fails.
  Future<void> printLines(
    List<ReceiptLine> lines,
    PrinterSettings settings, {
    bool openDrawer = false,
    int? copies,
  }) async {
    final address = settings.address;
    if (address == null || address.isEmpty) {
      throw const PrinterException(
        'NO_PRINTER',
        'Printer belum dipilih. Atur di Pengaturan > Printer Bluetooth.',
      );
    }
    final bytes = renderEscPos(
      lines,
      copies: copies ?? settings.copies,
      cut: settings.autoCut,
      openDrawer: openDrawer,
    );
    await sendBytes(address, bytes);
  }
}
