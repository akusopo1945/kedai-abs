import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/currency_formatter.dart';

class QrisView extends StatelessWidget {
  final Uint8List image;
  final double size;

  const QrisView({super.key, required this.image, this.size = 200});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Image.memory(
        image,
        width: size,
        height: size,
        fit: BoxFit.contain,
        // Nearest-neighbour keeps QR modules sharp when scaled.
        filterQuality: FilterQuality.none,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => SizedBox(
          width: size,
          height: size,
          child: const Center(
            child: Text(
              'Gambar QRIS tidak bisa dibaca. Unggah ulang di Pengaturan.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

/// White full-screen QRIS so customers can scan it easily.
Future<void> showQrisFullScreen(
  BuildContext context, {
  required Uint8List image,
  required String storeName,
  double? amount,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (context) => Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: const Text('Scan QRIS'),
        ),
        body: SafeArea(
          child: Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Leave room for the store name and total under the code.
                final side =
                    (constraints.maxHeight - 160 < constraints.maxWidth - 48
                            ? constraints.maxHeight - 160
                            : constraints.maxWidth - 48)
                        .clamp(160.0, 520.0);
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      storeName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    QrisView(image: image, size: side - 16),
                    if (amount != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Total: ${CurrencyFormatter.format(amount)}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryDark,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
}
