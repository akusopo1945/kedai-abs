import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../providers/pos_provider.dart';
import 'receipt_screen.dart';

class CheckoutSheet extends StatefulWidget {
  const CheckoutSheet({super.key});

  @override
  State<CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<CheckoutSheet> {
  final TextEditingController _cashController = TextEditingController();
  final TextEditingController _customerController = TextEditingController();
  String _selectedPaymentMethod = 'Tunai';
  double _paidAmount = 0.0;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    final pos = Provider.of<PosProvider>(context, listen: false);
    _paidAmount = pos.cartTotal;
    _cashController.text = pos.cartTotal.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _cashController.dispose();
    _customerController.dispose();
    super.dispose();
  }

  void _setAmount(double amount) {
    setState(() {
      _paidAmount = amount;
      _cashController.text = amount.toStringAsFixed(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final pos = context.watch<PosProvider>();
    final total = pos.cartTotal;
    final change = (_paidAmount - total).clamp(0.0, double.infinity);
    final canPay = _selectedPaymentMethod != 'Tunai' || _paidAmount >= total;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle Bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Sheet Title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Pembayaran',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  '${pos.cartCount} Item',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Customer Name
            TextField(
              controller: _customerController,
              decoration: const InputDecoration(
                labelText: 'Nama Pelanggan (Opsional)',
                prefixIcon: Icon(Icons.person_outline, size: 20),
              ),
            ),
            const SizedBox(height: 16),

            // Payment Methods
            const Text(
              'Metode Pembayaran',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildMethodChip('Tunai', Icons.payments_outlined),
                const SizedBox(width: 8),
                _buildMethodChip('QRIS', Icons.qr_code_scanner),
                const SizedBox(width: 8),
                _buildMethodChip('Transfer', Icons.account_balance_outlined),
              ],
            ),
            const SizedBox(height: 16),

            // Total Tagihan Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Tagihan',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.primaryDark,
                    ),
                  ),
                  Text(
                    CurrencyFormatter.format(total),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryDark,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Cash input & chips if Tunai
            if (_selectedPaymentMethod == 'Tunai') ...[
              TextField(
                controller: _cashController,
                keyboardType: TextInputType.number,
                onChanged: (val) {
                  setState(() {
                    _paidAmount = double.tryParse(val) ?? 0.0;
                  });
                },
                decoration: const InputDecoration(
                  labelText: 'Nominal Uang Diterima',
                  prefixText: 'Rp ',
                  prefixIcon: Icon(Icons.money, size: 20),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    label: const Text('Uang Pas'),
                    onPressed: () => _setAmount(total),
                    backgroundColor: _paidAmount == total
                        ? AppTheme.primaryLight
                        : AppTheme.surface,
                  ),
                  ...AppConstants.quickCashDenominations.map((denom) {
                    if (denom >= total) {
                      return ActionChip(
                        label: Text(CurrencyFormatter.formatShort(denom)),
                        onPressed: () => _setAmount(denom.toDouble()),
                        backgroundColor: _paidAmount == denom
                            ? AppTheme.primaryLight
                            : AppTheme.surface,
                      );
                    }
                    return const SizedBox.shrink();
                  }),
                ],
              ),
              const SizedBox(height: 16),

              // Change Calculation
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: change > 0 ? AppTheme.surface : AppTheme.borderSubtle,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Kembalian',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    Text(
                      CurrencyFormatter.format(change),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: change > 0 ? AppTheme.accent : AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: (!canPay || _isProcessing)
                    ? null
                    : () async {
                        setState(() => _isProcessing = true);
                        final createdOrder = await pos.checkout(
                          paymentAmount: _selectedPaymentMethod == 'Tunai'
                              ? _paidAmount
                              : total,
                          paymentMethod: _selectedPaymentMethod,
                          customerName: _customerController.text.trim().isEmpty
                              ? null
                              : _customerController.text.trim(),
                        );

                        if (mounted) {
                          Navigator.pop(context); // Close sheet
                          if (createdOrder != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ReceiptScreen(order: createdOrder),
                              ),
                            );
                          }
                        }
                      },
                child: _isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Konfirmasi & Selesaikan Transaksi',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMethodChip(String method, IconData icon) {
    final isSelected = _selectedPaymentMethod == method;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          setState(() {
            _selectedPaymentMethod = method;
            if (method != 'Tunai') {
              final pos = Provider.of<PosProvider>(context, listen: false);
              _paidAmount = pos.cartTotal;
            }
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryLight : AppTheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppTheme.primary : AppTheme.border,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
              ),
              const SizedBox(height: 4),
              Text(
                method,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
