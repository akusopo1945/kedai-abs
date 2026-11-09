import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/backup_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/shift.dart';
import '../../providers/pos_provider.dart';

class ClosingScreen extends StatefulWidget {
  const ClosingScreen({super.key});

  @override
  State<ClosingScreen> createState() => _ClosingScreenState();
}

class _ClosingScreenState extends State<ClosingScreen> {
  final _countedController = TextEditingController();
  final _noteController = TextEditingController();
  final _openingController = TextEditingController();
  ShiftSummary? _summary;
  bool _loading = true;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _countedController.dispose();
    _noteController.dispose();
    _openingController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final summary = await context.read<PosProvider>().loadCurrentShiftSummary();
    if (!mounted) return;
    setState(() {
      _summary = summary;
      _loading = false;
    });
  }

  static double? _parseAmount(String text) {
    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.isEmpty ? null : double.parse(digits);
  }

  Future<void> _editOpeningCash() async {
    final pos = context.read<PosProvider>();
    _openingController.text =
        (_summary?.shift.openingCash ?? 0).toStringAsFixed(0);
    final value = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Modal Awal Kas'),
        content: TextField(
          controller: _openingController,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(prefixText: 'Rp '),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(
              ctx,
              _parseAmount(_openingController.text) ?? 0,
            ),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (value == null) return;
    await pos.setOpeningCash(value);
    await _load();
  }

  Future<void> _closeShift(ShiftSummary summary, double counted) async {
    final pos = context.read<PosProvider>();
    final difference = counted - summary.expectedCash;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tutup kasir sekarang?'),
        content: Text(
          'Setelah ditutup, transaksi shift ini dikunci dan masuk rekap final.\n\n'
          'Kas seharusnya: ${CurrencyFormatter.format(summary.expectedCash)}\n'
          'Uang di laci: ${CurrencyFormatter.format(counted)}\n'
          'Selisih: ${_signed(difference)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Tutup Kasir'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _closing = true);
    final messenger = ScaffoldMessenger.of(context);
    final ShiftSummary closed;
    try {
      final note = _noteController.text.trim();
      closed = await pos.closeCurrentShift(
        countedCash: counted,
        note: note.isEmpty ? null : note,
      );
    } on StateError catch (e) {
      if (mounted) setState(() => _closing = false);
      messenger.showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppTheme.danger),
      );
      return;
    }

    final report = buildClosingReport(closed, pos.storeProfile.name);
    if (!mounted) return;
    await _shareBackup(report);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kasir ditutup'),
        content: const Text(
          'Rekap shift tersimpan. Pastikan file cadangan sudah terkirim ke '
          'Google Drive atau WhatsApp pemilik.',
        ),
        actions: [
          if (pos.printerSettings.isConfigured)
            TextButton(
              onPressed: () => _printReport(report),
              child: const Text('Cetak Rekap'),
            ),
          TextButton(
            onPressed: () => _shareBackup(report),
            child: const Text('Kirim Cadangan Lagi'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Selesai'),
          ),
        ],
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _printReport(String report) async {
    final pos = context.read<PosProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final lines = report.split('\n').where((line) => line.trim().isNotEmpty);
    final error = await pos.printDocument(lines.first, lines.skip(1).toList());
    messenger.showSnackBar(
      SnackBar(
        content: Text(error ?? 'Rekap closing dicetak.'),
        backgroundColor: error == null ? AppTheme.accent : AppTheme.danger,
      ),
    );
  }

  Future<void> _shareBackup(String report) async {
    final pos = context.read<PosProvider>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await BackupService.shareBackup(pos, message: report);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Gagal membuat cadangan: $e'),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pos = context.watch<PosProvider>();
    final summary = _summary;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Tutup Kasir (Closing)')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : summary == null
              ? _buildNoShift(pos)
              : _buildSummary(pos, summary),
    );
  }

  Widget _buildNoShift(PosProvider pos) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_open_outlined,
                size: 48, color: AppTheme.primary),
            const SizedBox(height: 12),
            const Text(
              'Belum ada shift berjalan',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Shift dibuka otomatis saat transaksi pertama. Isi modal awal '
              'kas sekarang jika ada uang kembalian di laci.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _editOpeningCash,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Buka Kasir & Isi Modal Awal'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary(PosProvider pos, ShiftSummary summary) {
    final blocker = pos.closingBlocker;
    final counted = _parseAmount(_countedController.text);
    final difference = counted == null ? null : counted - summary.expectedCash;
    final openQrBills = pos.isOnlineSyncAvailable ? pos.liveBills.length : 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _card([
          _row('Shift dibuka',
              CurrencyFormatter.formatDate(summary.shift.openedAt)),
          Row(
            children: [
              Expanded(
                child: _row(
                  'Modal awal kas',
                  CurrencyFormatter.format(summary.shift.openingCash),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                tooltip: 'Ubah modal awal',
                onPressed: _editOpeningCash,
              ),
            ],
          ),
        ]),
        const SizedBox(height: 12),
        _sectionTitle('Penjualan Shift'),
        _card([
          _row('Transaksi', '${summary.sales.transactionCount}'),
          _row('Omzet', CurrencyFormatter.format(summary.sales.revenue),
              bold: true),
          _row('Kasbon baru (belum dibayar)',
              CurrencyFormatter.format(summary.newDebt)),
          _row(
            summary.sales.unknownCostCount == 0
                ? 'Laba'
                : 'Laba (HPP tercatat)',
            CurrencyFormatter.format(summary.sales.profit),
          ),
        ]),
        const SizedBox(height: 12),
        _sectionTitle('Uang Masuk Shift Ini'),
        _card([
          if (summary.paymentsByMethod.isEmpty)
            _row('Belum ada pembayaran', CurrencyFormatter.format(0)),
          for (final entry in summary.paymentsByMethod.entries)
            _row(entry.key, CurrencyFormatter.format(entry.value)),
          if (summary.debtCollected > 0)
            _row(
              'Termasuk pelunasan kasbon',
              CurrencyFormatter.format(summary.debtCollected),
            ),
          const Divider(),
          _row(
            'Kas seharusnya di laci',
            CurrencyFormatter.format(summary.expectedCash),
            bold: true,
          ),
          const Text(
            'Modal awal + pembayaran tunai (QRIS dan transfer tidak masuk laci).',
            style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
          ),
        ]),
        const SizedBox(height: 12),
        _card([
          _row(
            'Total piutang aktif',
            CurrencyFormatter.format(summary.outstandingDebt),
          ),
        ]),
        const SizedBox(height: 16),
        _sectionTitle('Hitung Uang di Laci'),
        TextField(
          controller: _countedController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Uang tunai fisik di laci',
            prefixText: 'Rp ',
          ),
        ),
        if (difference != null) ...[
          const SizedBox(height: 8),
          Text(
            difference == 0
                ? 'Kas cocok.'
                : 'Selisih ${_signed(difference)} '
                    '(${difference > 0 ? 'lebih' : 'kurang'})',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: difference == 0 ? AppTheme.success : AppTheme.danger,
            ),
          ),
        ],
        const SizedBox(height: 10),
        TextField(
          controller: _noteController,
          decoration: const InputDecoration(
            labelText: 'Catatan closing (opsional)',
          ),
        ),
        const SizedBox(height: 16),
        if (blocker != null) _notice(blocker, AppTheme.danger),
        if (openQrBills > 0)
          _notice(
            'Masih ada $openQrBills tagihan meja QR yang belum dilunasi.',
            AppTheme.warning,
          ),
        const SizedBox(height: 8),
        SizedBox(
          height: 50,
          child: ElevatedButton.icon(
            onPressed: blocker != null || counted == null || _closing
                ? null
                : () => _closeShift(summary, counted),
            icon: _closing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.lock_outline),
            label: const Text('Tutup Kasir & Kirim Cadangan'),
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
      );

  Widget _card(List<Widget> children) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      );

  Widget _row(String label, String value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.textSecondary),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      );

  Widget _notice(String text, Color color) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(text, style: TextStyle(fontSize: 12, color: color)),
      );
}

String _signed(double value) {
  final formatted = CurrencyFormatter.format(value.abs());
  if (value > 0) return '+$formatted';
  if (value < 0) return '-$formatted';
  return formatted;
}

/// Plain-text closing report sent together with the backup file.
String buildClosingReport(ShiftSummary summary, String storeName) {
  final shift = summary.shift;
  final buffer = StringBuffer()
    ..writeln('Closing Kasir - $storeName')
    ..writeln(
      'Shift: ${CurrencyFormatter.formatDate(shift.openedAt)} s/d '
      '${shift.closedAt != null ? CurrencyFormatter.formatDate(shift.closedAt!) : '-'}',
    )
    ..writeln('Transaksi: ${summary.sales.transactionCount}')
    ..writeln('Omzet: ${CurrencyFormatter.format(summary.sales.revenue)}')
    ..writeln('Kasbon baru: ${CurrencyFormatter.format(summary.newDebt)}')
    ..writeln(
      'Pelunasan kasbon: ${CurrencyFormatter.format(summary.debtCollected)}',
    );
  for (final entry in summary.paymentsByMethod.entries) {
    buffer.writeln(
        'Masuk ${entry.key}: ${CurrencyFormatter.format(entry.value)}');
  }
  buffer
    ..writeln('Modal awal: ${CurrencyFormatter.format(shift.openingCash)}')
    ..writeln(
        'Kas seharusnya: ${CurrencyFormatter.format(summary.expectedCash)}');
  if (shift.countedCash != null) {
    buffer.writeln(
        'Kas dihitung: ${CurrencyFormatter.format(shift.countedCash!)}');
  }
  final difference = shift.cashDifference;
  if (difference != null) buffer.writeln('Selisih: ${_signed(difference)}');
  buffer.writeln(
    'Piutang aktif: ${CurrencyFormatter.format(summary.outstandingDebt)}',
  );
  if (shift.note != null) buffer.writeln('Catatan: ${shift.note}');
  buffer.writeln('Versi app: ${AppConstants.appVersion}');
  return buffer.toString();
}
