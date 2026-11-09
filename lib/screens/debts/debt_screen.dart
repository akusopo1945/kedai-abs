import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/order.dart';
import '../../providers/pos_provider.dart';
import '../../widgets/empty_state.dart';
import '../pos/receipt_screen.dart';

class DebtScreen extends StatefulWidget {
  const DebtScreen({super.key});

  @override
  State<DebtScreen> createState() => _DebtScreenState();
}

class _DebtScreenState extends State<DebtScreen> {
  @override
  void initState() {
    super.initState();
    context.read<PosProvider>().loadDebts();
  }

  @override
  Widget build(BuildContext context) {
    final pos = context.watch<PosProvider>();
    final debts = pos.debtOrders;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Daftar Kasbon')),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total Piutang Aktif',
                  style: TextStyle(fontSize: 12, color: AppTheme.primaryDark),
                ),
                const SizedBox(height: 4),
                Text(
                  CurrencyFormatter.format(pos.outstandingDebt),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryDark,
                  ),
                ),
                Text(
                  '${debts.length} nota belum lunas',
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.primaryDark),
                ),
              ],
            ),
          ),
          Expanded(
            child: debts.isEmpty
                ? const EmptyState(
                    icon: Icons.verified_outlined,
                    title: 'Tidak Ada Kasbon',
                    message: 'Semua pelanggan sudah lunas.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: debts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) =>
                        _buildDebtCard(context, pos, debts[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDebtCard(
      BuildContext context, PosProvider pos, OrderModel order) {
    final ageDays = DateTime.now().difference(order.createdAt).inDays;
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ReceiptScreen(order: order)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      order.customerName ?? 'Tanpa nama',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    ageDays == 0 ? 'Hari ini' : '$ageDays hari',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: ageDays >= 7
                          ? AppTheme.danger
                          : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${order.invoiceNumber} • ${CurrencyFormatter.formatDate(order.createdAt)}',
                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
              ),
              if (order.customerPhone != null)
                Text(
                  order.customerPhone!,
                  style:
                      const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
              const SizedBox(height: 8),
              _amountRow('Total nota', order.finalAmount),
              if (order.paidAmount > 0)
                _amountRow('Sudah dibayar', order.paidAmount),
              _amountRow('Sisa', order.outstandingAmount, emphasize: true),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _shareReminder(pos, order),
                      icon: const Icon(Icons.share_outlined, size: 16),
                      label: const Text('Pengingat'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _receivePayment(context, pos, order),
                      icon: const Icon(Icons.payments_outlined, size: 16),
                      label: const Text('Terima Bayar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _amountRow(String label, double amount, {bool emphasize = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          Text(
            CurrencyFormatter.format(amount),
            style: TextStyle(
              fontSize: emphasize ? 15 : 12,
              fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
              color: emphasize ? AppTheme.danger : AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _shareReminder(PosProvider pos, OrderModel order) async {
    final text = 'Halo ${order.customerName ?? ''}, ini pengingat kasbon di '
        '${pos.storeProfile.name}: nota ${order.invoiceNumber} tanggal '
        '${CurrencyFormatter.formatDateOnly(order.createdAt)}, sisa '
        '${CurrencyFormatter.format(order.outstandingAmount)}. Matur nuwun.';
    await SharePlus.instance.share(ShareParams(text: text));
  }

  Future<void> _receivePayment(
    BuildContext context,
    PosProvider pos,
    OrderModel order,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final result =
        await showDialog<({double amount, String method, String note})>(
      context: context,
      builder: (_) => _PaymentDialog(
        order: order,
        methods: pos.enabledSettlementMethods,
      ),
    );
    if (result == null) return;

    final error = await pos.receiveDebtPayment(
      order,
      result.amount,
      result.method,
      note: result.note,
    );
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          error ??
              'Pembayaran ${CurrencyFormatter.format(result.amount)} dari '
                  '${order.customerName ?? 'pelanggan'} tercatat.',
        ),
        backgroundColor: error == null ? AppTheme.accent : AppTheme.danger,
      ),
    );
  }
}

class _PaymentDialog extends StatefulWidget {
  final OrderModel order;
  final List<String> methods;

  const _PaymentDialog({required this.order, required this.methods});

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  late final TextEditingController _amountController = TextEditingController(
    text: widget.order.outstandingAmount.toStringAsFixed(0),
  );
  String _method = AppConstants.paymentCash;
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final outstanding = widget.order.outstandingAmount;
    final amount = double.tryParse(_amountController.text) ?? 0;
    final error = amount <= 0
        ? 'Isi nominal pembayaran.'
        : amount > outstanding
            ? 'Melebihi sisa ${CurrencyFormatter.format(outstanding)}.'
            : null;

    return AlertDialog(
      title: Text('Terima Bayar • ${widget.order.customerName ?? ''}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sisa kasbon: ${CurrencyFormatter.format(outstanding)}',
            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Nominal dibayar',
              prefixText: 'Rp ',
              errorText: error,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final method in widget.methods)
                ChoiceChip(
                  label: Text(method),
                  selected: _method == method,
                  onSelected: (_) => setState(() => _method = method),
                ),
            ],
          ),
          if (_method != AppConstants.paymentCash)
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'No. Referensi (opsional)',
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: error != null
              ? null
              : () => Navigator.pop(
                    context,
                    (
                      amount: amount,
                      method: _method,
                      note: _noteController.text,
                    ),
                  ),
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
