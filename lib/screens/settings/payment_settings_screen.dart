import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../models/payment_settings.dart';
import '../../providers/pos_provider.dart';
import '../../widgets/qris_view.dart';

class PaymentSettingsScreen extends StatelessWidget {
  const PaymentSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pos = context.watch<PosProvider>();
    final settings = pos.paymentSettings;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Pengaturan Pembayaran')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section('Metode yang Ditampilkan di Kasir'),
          _card([
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.payments_outlined),
              title: Text('Tunai'),
              subtitle: Text('Selalu aktif'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.qr_code_2),
              title: const Text('QRIS'),
              value: settings.qrisEnabled,
              onChanged: (value) => pos
                  .savePaymentSettings(settings.copyWith(qrisEnabled: value)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.account_balance_outlined),
              title: const Text('Transfer Bank / E-Wallet'),
              value: settings.transferEnabled,
              onChanged: (value) => pos.savePaymentSettings(
                settings.copyWith(transferEnabled: value),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.menu_book_outlined),
              title: const Text('Kasbon'),
              subtitle: const Text('Kasbon lama tetap bisa dilunasi.'),
              value: settings.debtEnabled,
              onChanged: (value) => pos
                  .savePaymentSettings(settings.copyWith(debtEnabled: value)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.tag),
              title: const Text('Wajib isi No. Referensi'),
              subtitle: const Text(
                'Untuk QRIS dan transfer, agar setiap dana masuk bisa dicocokkan.',
              ),
              value: settings.requireReference,
              onChanged: (value) => pos.savePaymentSettings(
                settings.copyWith(requireReference: value),
              ),
            ),
          ]),
          const SizedBox(height: 20),
          _section('Kode QRIS'),
          _card([
            if (pos.qrisImage != null) ...[
              Center(
                child: GestureDetector(
                  onTap: () => showQrisFullScreen(
                    context,
                    image: pos.qrisImage!,
                    storeName: pos.storeProfile.name,
                  ),
                  child: QrisView(image: pos.qrisImage!, size: 200),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Uji dulu: scan gambar ini dari aplikasi bank/e-wallet lain dan '
                'pastikan nama merchant benar sebelum dipakai.',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 12),
            ] else
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'Unggah gambar QRIS statis dari penyedia (bank/payment '
                  'gateway). Gambar disimpan di HP dan ikut dalam cadangan data.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _pickQris(context, pos),
                    icon: const Icon(Icons.upload_outlined, size: 18),
                    label: Text(
                      pos.qrisImage == null ? 'Unggah QRIS' : 'Ganti Gambar',
                    ),
                  ),
                ),
                if (pos.qrisImage != null) ...[
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: () => _removeQris(context, pos),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Hapus'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.danger,
                      side: const BorderSide(color: AppTheme.danger),
                    ),
                  ),
                ],
              ],
            ),
          ]),
          const SizedBox(height: 20),
          _section('Rekening Bank / E-Wallet'),
          _card([
            if (settings.bankAccounts.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'Belum ada rekening. Rekening ditampilkan di kasir saat '
                  'pelanggan memilih Transfer.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ),
            for (var i = 0; i < settings.bankAccounts.length; i++)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.account_balance_wallet_outlined),
                title: Text(
                  '${settings.bankAccounts[i].bankName} • '
                  '${settings.bankAccounts[i].accountNumber}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle:
                    Text('a.n. ${settings.bankAccounts[i].accountHolder}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      tooltip: 'Ubah',
                      onPressed: () => _editAccount(context, pos, index: i),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: AppTheme.danger,
                      ),
                      tooltip: 'Hapus',
                      onPressed: () => _deleteAccount(context, pos, i),
                    ),
                  ],
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _editAccount(context, pos),
                icon: const Icon(Icons.add),
                label: const Text('Tambah Rekening'),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Future<void> _pickQris(BuildContext context, PosProvider pos) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1600,
        imageQuality: 90,
        requestFullMetadata: false,
      );
      if (file == null) return;
      final error = await pos.saveQrisImage(await file.readAsBytes());
      messenger.showSnackBar(
        SnackBar(
          content: Text(error ?? 'Gambar QRIS tersimpan.'),
          backgroundColor: error == null ? AppTheme.accent : AppTheme.danger,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Gagal membuka galeri: $e'),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
  }

  Future<void> _removeQris(BuildContext context, PosProvider pos) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus gambar QRIS?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirm == true) await pos.saveQrisImage(null);
  }

  Future<void> _editAccount(
    BuildContext context,
    PosProvider pos, {
    int? index,
  }) async {
    final accounts = pos.paymentSettings.bankAccounts;
    final account = await showDialog<BankAccount>(
      context: context,
      builder: (_) => _BankAccountDialog(
        initial: index == null ? null : accounts[index],
      ),
    );
    if (account == null) return;
    final updated = List<BankAccount>.from(accounts);
    if (index == null) {
      updated.add(account);
    } else {
      updated[index] = account;
    }
    await pos.savePaymentSettings(
      pos.paymentSettings.copyWith(bankAccounts: updated),
    );
  }

  Future<void> _deleteAccount(
    BuildContext context,
    PosProvider pos,
    int index,
  ) async {
    final account = pos.paymentSettings.bankAccounts[index];
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus rekening?'),
        content: Text(account.label),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final updated = List<BankAccount>.from(pos.paymentSettings.bankAccounts)
      ..removeAt(index);
    await pos.savePaymentSettings(
      pos.paymentSettings.copyWith(bankAccounts: updated),
    );
  }

  static Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
      );

  static Widget _card(List<Widget> children) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      );
}

class _BankAccountDialog extends StatefulWidget {
  final BankAccount? initial;

  const _BankAccountDialog({this.initial});

  @override
  State<_BankAccountDialog> createState() => _BankAccountDialogState();
}

class _BankAccountDialogState extends State<_BankAccountDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _bankController =
      TextEditingController(text: widget.initial?.bankName);
  late final _numberController =
      TextEditingController(text: widget.initial?.accountNumber);
  late final _holderController =
      TextEditingController(text: widget.initial?.accountHolder);

  @override
  void dispose() {
    _bankController.dispose();
    _numberController.dispose();
    _holderController.dispose();
    super.dispose();
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Wajib diisi' : null;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'Tambah Rekening' : 'Ubah Rekening'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _bankController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Bank / E-Wallet',
                hintText: 'BCA, BRI, DANA, ...',
              ),
              validator: _required,
            ),
            TextFormField(
              controller: _numberController,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'Nomor Rekening / HP'),
              validator: _required,
            ),
            TextFormField(
              controller: _holderController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Atas Nama'),
              validator: _required,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(
              context,
              BankAccount(
                bankName: _bankController.text.trim(),
                accountNumber: _numberController.text.trim(),
                accountHolder: _holderController.text.trim(),
              ),
            );
          },
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
