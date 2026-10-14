import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../providers/pos_provider.dart';
import '../../widgets/empty_state.dart';

class TableBillsScreen extends StatefulWidget {
  const TableBillsScreen({super.key});

  @override
  State<TableBillsScreen> createState() => _TableBillsScreenState();
}

class _TableBillsScreenState extends State<TableBillsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pos = context.watch<PosProvider>();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Meja & Pesanan Online',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            Text(
              'Tagihan Meja & Self-Order QR',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Sinkronisasi Ulang',
            onPressed: () async {
              await pos.checkOnlineSync();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Data berhasil diperbarui dari server online')),
                );
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: [
            Tab(
              text: 'Tagihan Meja (${pos.liveBills.length})',
            ),
            Tab(
              text: 'Antrean Masuk (${pos.liveOnlineOrders.where((o) => o['status'] != 'selesai').length})',
            ),
          ],
        ),
      ),
      body: !pos.isOnlineSyncAvailable
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        color: AppTheme.primaryLight,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.cloud_off_outlined, color: AppTheme.primary, size: 32),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Mode Offline Mandiri',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Aplikasi kasir berjalan 100% lokal via SQLite. Hubungkan ke server Angkringan ABS lokal untuk sinkronisasi tagihan meja dan pesanan QR otomatis.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => pos.checkOnlineSync(),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Coba Sambungkan'),
                    ),
                  ],
                ),
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTableBillsTab(pos),
                _buildOnlineOrdersTab(pos),
              ],
            ),
    );
  }

  Widget _buildTableBillsTab(PosProvider pos) {
    if (pos.liveBills.isEmpty) {
      return const EmptyState(
        icon: Icons.table_restaurant_outlined,
        title: 'Tidak Ada Tagihan Terbuka',
        message: 'Semua meja belum ada pesanan aktif atau sudah lunas.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: pos.liveBills.length,
      itemBuilder: (context, index) {
        final bill = pos.liveBills[index];

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border),
          ),
          child: ExpansionTile(
            shape: const Border(),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.table_bar, color: AppTheme.primaryDark, size: 20),
            ),
            title: Text(
              'Meja ${bill.meja}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            subtitle: Text(
              '${bill.totalPesanan} Pesanan • Total ${CurrencyFormatter.format(bill.totalTagihan)}',
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              const Divider(color: AppTheme.borderSubtle),
              ...bill.orders.map((ord) {
                final items = ord['items'] as List<dynamic>? ?? [];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Order #${ord['id']?.toString().substring(0, 8) ?? ''}',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppTheme.primary),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: ord['status'] == 'selesai'
                                  ? AppTheme.success.withOpacity(0.12)
                                  : AppTheme.accent.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              ord['status']?.toString().toUpperCase() ?? 'PENDING',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: ord['status'] == 'selesai' ? AppTheme.success : AppTheme.accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ...items.map((it) => Text(
                            '• ${it['jumlah']}x ${it['nama']} (${it['opsiPilihan'] ?? '-'}) - ${CurrencyFormatter.format((it['subtotal'] as num?)?.toDouble() ?? 0)}',
                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          )),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text('Lunaskan Meja ${bill.meja}?'),
                        content: Text('Total tagihan senilai ${CurrencyFormatter.format(bill.totalTagihan)} akan ditandai lunas.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
                          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Lunaskan')),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await pos.settleTableBill(bill.meja);
                    }
                  },
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Tandai Meja Selesai & Lunas'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOnlineOrdersTab(PosProvider pos) {
    if (pos.liveOnlineOrders.isEmpty) {
      return const EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'Belum Ada Pesanan Masuk',
        message: 'Pesanan mandiri dari scan QR pelanggan akan muncul di sini secara real-time.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: pos.liveOnlineOrders.length,
      itemBuilder: (context, index) {
        final order = pos.liveOnlineOrders[index];
        final items = (order['items'] as List<dynamic>?) ?? [];
        final status = order['status']?.toString() ?? 'pending';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Meja ${order['nomorMeja'] ?? '-'}',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppTheme.primaryDark),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        order['namaPelanggan'] ?? 'Pelanggan',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                    ],
                  ),
                  Text(
                    CurrencyFormatter.format((order['totalHarga'] as num?)?.toDouble() ?? 0),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.primary),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...items.map((it) => Text(
                    '${it['jumlah']}x ${it['nama']} ${it['opsiPilihan'] != null ? "(${it['opsiPilihan']})" : ""}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  )),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (status == 'pending') ...[
                    OutlinedButton(
                      onPressed: () => pos.updateOnlineOrderStatus(order['id'], 'diproses'),
                      child: const Text('Terima & Bakar'),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (status == 'diproses') ...[
                    ElevatedButton(
                      onPressed: () => pos.updateOnlineOrderStatus(order['id'], 'selesai'),
                      child: const Text('Siap Disajikan'),
                    ),
                  ],
                  if (status == 'selesai') ...[
                    const Chip(
                      label: Text('Selesai Disajikan', style: TextStyle(fontSize: 11, color: AppTheme.success)),
                      backgroundColor: AppTheme.borderSubtle,
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
