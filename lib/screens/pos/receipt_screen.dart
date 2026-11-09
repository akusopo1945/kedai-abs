import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/printer_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/order.dart';
import '../../providers/pos_provider.dart';
import '../settings/printer_settings_screen.dart';

class ReceiptScreen extends StatelessWidget {
  final OrderModel order;

  const ReceiptScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final pos = context.watch<PosProvider>();
    final store = pos.storeProfile;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Struk Pembayaran'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Receipt Card Container
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Success Icon Badge
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: AppTheme.accent,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Transaksi Berhasil!',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    CurrencyFormatter.formatDate(order.createdAt),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: AppTheme.border),
                  const SizedBox(height: 16),

                  // Store Header
                  Text(
                    store.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    store.address,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    'Telp: ${store.phone}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildDashedLine(),
                  const SizedBox(height: 16),

                  // Order Details
                  _buildRow('No. Invoice', order.invoiceNumber),
                  if (order.customerName != null)
                    _buildRow('Pelanggan', order.customerName!),
                  _buildRow('Metode Bayar', order.paymentMethod),
                  if (order.paymentNote != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        order.paymentNote!,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  _buildDashedLine(),
                  const SizedBox(height: 16),

                  // Item List
                  ...order.items.map((item) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.productName,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                Text(
                                  '${item.quantity} x ${CurrencyFormatter.format(item.unitPrice)}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            CurrencyFormatter.format(item.subtotal),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 12),
                  const Divider(color: AppTheme.border),
                  const SizedBox(height: 12),

                  // Summary Totals
                  _buildRow(
                    'Subtotal',
                    CurrencyFormatter.format(order.totalAmount),
                  ),
                  if (order.discountAmount > 0)
                    _buildRow(
                      'Diskon',
                      '-${CurrencyFormatter.format(order.discountAmount)}',
                      valueColor: AppTheme.danger,
                    ),
                  _buildRow(
                    'Total',
                    CurrencyFormatter.format(order.finalAmount),
                    isBold: true,
                  ),
                  if (order.isDebt) ...[
                    _buildRow(
                      'Sudah Dibayar',
                      CurrencyFormatter.format(order.paidAmount),
                    ),
                    _buildRow(
                      'Sisa Kasbon',
                      CurrencyFormatter.format(order.outstandingAmount),
                      valueColor: AppTheme.danger,
                      isBold: true,
                    ),
                  ] else if (order.paymentMethod ==
                      AppConstants.paymentDebt) ...[
                    _buildRow(
                      'Status',
                      'Kasbon lunas',
                      valueColor: AppTheme.accent,
                      isBold: true,
                    ),
                  ] else ...[
                    _buildRow(
                      'Diterima',
                      CurrencyFormatter.format(order.paymentAmount),
                    ),
                    _buildRow(
                      'Kembalian',
                      CurrencyFormatter.format(order.changeAmount),
                      valueColor: AppTheme.accent,
                      isBold: true,
                    ),
                  ],

                  const SizedBox(height: 20),
                  _buildDashedLine(),
                  const SizedBox(height: 16),

                  // Receipt Footer
                  Text(
                    store.receiptFooter,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textMuted,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Print & share actions
            _ReceiptActions(order: order),
            const SizedBox(height: 10),

            // New Transaction Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Mulai Transaksi Baru'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(
    String label,
    String value, {
    bool isBold = false,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
              color: AppTheme.textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              color: valueColor ?? AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashedLine() {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final boxWidth = constraints.constrainWidth();
        const dashWidth = 4.0;
        const dashHeight = 1.0;
        final dashCount = (boxWidth / (2 * dashWidth)).floor();
        return Flex(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          direction: Axis.horizontal,
          children: List.generate(dashCount, (_) {
            return const SizedBox(
              width: dashWidth,
              height: dashHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(color: AppTheme.border),
              ),
            );
          }),
        );
      },
    );
  }
}

class _ReceiptActions extends StatefulWidget {
  final OrderModel order;

  const _ReceiptActions({required this.order});

  @override
  State<_ReceiptActions> createState() => _ReceiptActionsState();
}

class _ReceiptActionsState extends State<_ReceiptActions> {
  bool _printing = false;

  Future<void> _print(PosProvider pos) async {
    final messenger = ScaffoldMessenger.of(context);
    if (!pos.printerSettings.isConfigured) {
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Printer belum dipilih.'),
          action: SnackBarAction(
            label: 'Atur',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PrinterSettingsScreen()),
            ),
          ),
        ),
      );
      return;
    }
    setState(() => _printing = true);
    final error = await pos.printReceipt(widget.order);
    if (mounted) setState(() => _printing = false);
    messenger.showSnackBar(
      SnackBar(
        content: Text(error ?? 'Struk ${widget.order.invoiceNumber} dicetak.'),
        backgroundColor: error == null ? AppTheme.accent : AppTheme.danger,
        duration: Duration(seconds: error == null ? 2 : 5),
      ),
    );
  }

  Future<void> _share(PosProvider pos) async {
    final text = PrinterService.instance.generateReceiptText(
      order: widget.order,
      store: pos.storeProfile,
    );
    try {
      await SharePlus.instance.share(
        ShareParams(text: text, subject: 'Struk ${widget.order.invoiceNumber}'),
      );
    } catch (_) {
      // Share sheet unavailable: fall back to the clipboard.
      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Teks struk disalin ke clipboard.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pos = context.read<PosProvider>();
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _printing ? null : () => _print(pos),
              icon: _printing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.print_outlined, size: 20),
              label: const Text('Cetak Struk'),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () => _share(pos),
              icon: const Icon(Icons.share_outlined, size: 20),
              label: const Text('Kirim'),
            ),
          ),
        ),
      ],
    );
  }
}
