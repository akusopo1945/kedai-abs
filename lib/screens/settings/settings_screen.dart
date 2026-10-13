import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/store_profile.dart';
import '../../providers/pos_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;
  late TextEditingController _footerController;
  int _paperWidth = 58;

  @override
  void initState() {
    super.initState();
    final profile = Provider.of<PosProvider>(context, listen: false).storeProfile;
    _nameController = TextEditingController(text: profile.name);
    _addressController = TextEditingController(text: profile.address);
    _phoneController = TextEditingController(text: profile.phone);
    _footerController = TextEditingController(text: profile.receiptFooter);
    _paperWidth = profile.paperWidth;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _footerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pos = context.watch<PosProvider>();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Pengaturan Toko & Printer'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section 1: Store Profile
              const Text(
                'Profil Toko & Struk',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Nama Kedai / Usaha *'),
                      validator: (v) => v == null || v.isEmpty ? 'Nama wajib diisi' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _addressController,
                      decoration: const InputDecoration(labelText: 'Alamat Usaha'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Nomor Telepon / WhatsApp'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _footerController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Catatan Footer Struk',
                        hintText: 'Contoh: Terima Kasih Atas Kunjungan Anda!',
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Section 2: Printer Setup
              const Text(
                'Pengaturan Printer Thermal',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ukuran Kertas Thermal',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<int>(
                            title: const Text('58 mm', style: TextStyle(fontSize: 13)),
                            subtitle: const Text('Printer mini portabel', style: TextStyle(fontSize: 11)),
                            value: 58,
                            groupValue: _paperWidth,
                            contentPadding: EdgeInsets.zero,
                            onChanged: (val) {
                              if (val != null) setState(() => _paperWidth = val);
                            },
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<int>(
                            title: const Text('80 mm', style: TextStyle(fontSize: 13)),
                            subtitle: const Text('Printer desktop standar', style: TextStyle(fontSize: 11)),
                            value: 80,
                            groupValue: _paperWidth,
                            contentPadding: EdgeInsets.zero,
                            onChanged: (val) {
                              if (val != null) setState(() => _paperWidth = val);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.save_outlined, size: 20),
                  label: const Text('Simpan Pengaturan'),
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      final updated = StoreProfile(
                        name: _nameController.text.trim(),
                        address: _addressController.text.trim(),
                        phone: _phoneController.text.trim(),
                        receiptFooter: _footerController.text.trim(),
                        paperWidth: _paperWidth,
                      );
                      await pos.updateStoreProfile(updated);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Pengaturan toko berhasil diperbarui'),
                            backgroundColor: AppTheme.accent,
                          ),
                        );
                      }
                    }
                  },
                ),
              ),

              const SizedBox(height: 32),

              // System Info
              Center(
                child: Column(
                  children: [
                    const Icon(Icons.offline_bolt_outlined, color: AppTheme.accent, size: 28),
                    const SizedBox(height: 4),
                    const Text(
                      'Sistem Beroperasi 100% Offline (SQLite Lokal)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Versi ${AppConstants.appVersion} • Kedai POS UMKM',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
