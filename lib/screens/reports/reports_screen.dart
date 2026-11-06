import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../providers/pos_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/stat_badge.dart';
import '../pos/receipt_screen.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pos = context.watch<PosProvider>();
    final summary = pos.filteredSummary;
    final orders = pos.filteredOrders;
    final revenue = summary['revenue'] ?? 0;
    final profit = summary['profit'] ?? 0;
    final count = (summary['transactions'] ?? 0).toInt();
    final unknownCostCount =
        (summary['unknown_cost_transactions'] ?? 0).toInt();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Laporan & Riwayat Penjualan'),
        actions: [
          if (orders.isNotEmpty)
            IconButton(
              icon:
                  const Icon(Icons.download_outlined, color: AppTheme.primary),
              tooltip: 'Salin Rekap CSV',
              onPressed: () async {
                final csv = pos.generateOrdersCsv();
                await Clipboard.setData(ClipboardData(text: csv));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Rekap CSV (${orders.length} transaksi) disalin ke clipboard.',
                    ),
                    backgroundColor: AppTheme.primary,
                  ),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.primary),
            onPressed: () {
              pos.loadTodaySummary();
              pos.loadOrderHistory();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date Range Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildRangeChip(pos, 'today', 'Hari Ini'),
                  const SizedBox(width: 8),
                  _buildRangeChip(pos, '7d', '7 Hari Terakhir'),
                  const SizedBox(width: 8),
                  _buildRangeChip(pos, 'month', 'Bulan Ini'),
                  const SizedBox(width: 8),
                  _buildRangeChip(pos, 'all', 'Semua Waktu'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Section Title
            const Text(
              'Ringkasan Penjualan',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            // Stat Cards Grid
            Row(
              children: [
                Expanded(
                  child: StatBadge(
                    title: 'Total Omzet',
                    value: CurrencyFormatter.format(revenue),
                    icon: Icons.account_balance_wallet_outlined,
                    iconColor: AppTheme.primary,
                    backgroundColor: AppTheme.primaryLight,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StatBadge(
                    title: unknownCostCount == 0
                        ? 'Laba Bersih'
                        : 'Laba (HPP tercatat)',
                    value: CurrencyFormatter.format(profit),
                    icon: Icons.trending_up,
                    iconColor: AppTheme.accent,
                    backgroundColor: AppTheme.accent.withOpacity(0.12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            StatBadge(
              title: 'Total Transaksi Selesai',
              value: '$count Transaksi',
              icon: Icons.receipt_long_outlined,
              iconColor: AppTheme.warning,
              backgroundColor: AppTheme.warning.withOpacity(0.12),
            ),
            if (unknownCostCount > 0) ...[
              const SizedBox(height: 8),
              Text(
                '$unknownCostCount transaksi online belum memiliki data modal produk; laba belum mencakup transaksi tersebut.',
                style: const TextStyle(fontSize: 12, color: AppTheme.warning),
              ),
            ],

            const SizedBox(height: 24),

            // History Section Title
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
                  '${orders.length} Total',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Order History List
            if (orders.isEmpty)
              const EmptyState(
                icon: Icons.history_toggle_off,
                title: 'Belum Ada Transaksi',
                message:
                    'Transaksi kasir yang telah diselesaikan akan tercatat di sini.',
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: orders.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final order = orders[index];

                  return Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            order.invoiceNumber,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
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
                            '${CurrencyFormatter.formatDate(order.createdAt)} • ${order.paymentMethod}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          if (order.customerName != null)
                            Text(
                              'Pelanggan: ${order.customerName}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.textMuted,
                              ),
                            ),
                        ],
                      ),
                      trailing: const Icon(
                        Icons.chevron_right,
                        size: 20,
                        color: AppTheme.textMuted,
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ReceiptScreen(order: order),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
          ],
        ),
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
      side: BorderSide(
        color: isSelected ? AppTheme.primary : AppTheme.border,
      ),
      showCheckmark: false,
    );
  }
}
