import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/order.dart';
import '../../providers/pos_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/stat_badge.dart';
import '../closing/closing_screen.dart';
import '../debts/debt_screen.dart';
import '../pos/receipt_screen.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pos = context.watch<PosProvider>();
    final summary = pos.reportSummary;
    final orders = pos.reportOrders;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Laporan & Closing'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_outlined, color: AppTheme.primary),
            tooltip: 'Salin Rekap CSV',
            onPressed: orders.isEmpty ? null : () => _copyCsv(context, pos),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.primary),
            tooltip: 'Muat ulang',
            onPressed: () => _refresh(pos),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _refresh(pos),
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildShiftCard(context, pos),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final entry
                            in PosProvider.reportRanges.entries) ...[
                          _buildRangeChip(pos, entry.key, entry.value),
                          const SizedBox(width: 8),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: StatBadge(
                          title: 'Total Omzet',
                          value: CurrencyFormatter.format(summary.revenue),
                          icon: Icons.account_balance_wallet_outlined,
                          iconColor: AppTheme.primary,
                          backgroundColor: AppTheme.primaryLight,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: StatBadge(
                          title: summary.unknownCostCount == 0
                              ? 'Laba Bersih'
                              : 'Laba (HPP tercatat)',
                          value: CurrencyFormatter.format(summary.profit),
                          icon: Icons.trending_up,
                          iconColor: AppTheme.accent,
                          backgroundColor:
                              AppTheme.accent.withValues(alpha: 0.12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: StatBadge(
                          title: 'Transaksi',
                          value: '${summary.transactionCount}',
                          icon: Icons.receipt_long_outlined,
                          iconColor: AppTheme.warning,
                          backgroundColor:
                              AppTheme.warning.withValues(alpha: 0.12),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: StatBadge(
                          title: 'Piutang Aktif',
                          value: CurrencyFormatter.format(pos.outstandingDebt),
                          icon: Icons.menu_book_outlined,
                          iconColor: AppTheme.danger,
                          backgroundColor:
                              AppTheme.danger.withValues(alpha: 0.1),
                        ),
                      ),
                    ],
                  ),
                  if (summary.unknownCostCount > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${summary.unknownCostCount} transaksi online belum memiliki '
                      'data modal produk; laba belum mencakup transaksi tersebut.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.warning,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Riwayat Transaksi',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        '${summary.transactionCount} Total',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ]),
              ),
            ),
            if (orders.isEmpty)
              const SliverToBoxAdapter(
                child: EmptyState(
                  icon: Icons.history_toggle_off,
                  title: 'Belum Ada Transaksi',
                  message:
                      'Transaksi kasir pada periode ini akan tercatat di sini.',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                sliver: SliverList.separated(
                  itemCount: orders.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) =>
                      _buildOrderTile(context, orders[index]),
                ),
              ),
            if (pos.reportHasMore)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: Text(
                    'Menampilkan ${PosProvider.historyLimit} transaksi terbaru. '
                    'Gunakan Salin Rekap CSV untuk data lengkap.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _refresh(PosProvider pos) async {
    await pos.loadReports();
    await pos.loadDebts();
  }

  Future<void> _copyCsv(BuildContext context, PosProvider pos) async {
    final messenger = ScaffoldMessenger.of(context);
    final csv = await pos.generateOrdersCsv();
    await Clipboard.setData(ClipboardData(text: csv));
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Rekap CSV periode ini disalin ke clipboard.'),
        backgroundColor: AppTheme.primary,
      ),
    );
  }

  Widget _buildShiftCard(BuildContext context, PosProvider pos) {
    final shift = pos.currentShift;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                shift == null ? Icons.lock_outline : Icons.lock_open_outlined,
                color: shift == null ? AppTheme.textMuted : AppTheme.success,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  shift == null
                      ? 'Kasir belum dibuka (otomatis saat transaksi pertama)'
                      : 'Shift berjalan sejak ${CurrencyFormatter.formatDate(shift.openedAt)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ClosingScreen()),
                  ),
                  icon: const Icon(Icons.lock_clock_outlined, size: 18),
                  label: const Text('Tutup Kasir'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DebtScreen()),
                  ),
                  icon: const Icon(Icons.menu_book_outlined, size: 18),
                  label: Text('Kasbon (${pos.debtOrders.length})'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRangeChip(PosProvider pos, String key, String label) {
    final isSelected = pos.reportRange == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => pos.setReportRange(key),
      selectedColor: AppTheme.primary,
      backgroundColor: AppTheme.surface,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? Colors.white : AppTheme.textSecondary,
      ),
      side: BorderSide(color: isSelected ? AppTheme.primary : AppTheme.border),
      showCheckmark: false,
    );
  }

  Widget _buildOrderTile(BuildContext context, OrderModel order) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: order.isDebt
              ? AppTheme.danger.withValues(alpha: 0.5)
              : AppTheme.border,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                order.invoiceNumber,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            Text(
              CurrencyFormatter.format(order.finalAmount),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${CurrencyFormatter.formatDate(order.createdAt)} • ${order.paymentMethod}'
              '${order.source == OrderModel.sourceQr ? ' • QR' : ''}',
              style:
                  const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
            if (order.customerName != null)
              Text(
                'Pelanggan: ${order.customerName}',
                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
              ),
            if (order.isDebt)
              Text(
                'KASBON • sisa ${CurrencyFormatter.format(order.outstandingAmount)}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.danger,
                ),
              ),
          ],
        ),
        trailing: const Icon(
          Icons.chevron_right,
          size: 20,
          color: AppTheme.textMuted,
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ReceiptScreen(order: order)),
        ),
      ),
    );
  }
}
