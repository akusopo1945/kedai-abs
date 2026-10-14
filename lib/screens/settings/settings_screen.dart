import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/menu_jajan_api_service.dart';
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
  late TextEditingController _serverUrlController;
  int _paperWidth = 58;

  bool _isTestingApi = false;
  bool _isSyncingMenu = false;
  ApiTestResult? _lastTestResult;

  @override
  void initState() {
    super.initState();
    final profile = Provider.of<PosProvider>(context, listen: false).storeProfile;
    _nameController = TextEditingController(text: profile.name);
    _addressController = TextEditingController(text: profile.address);
    _phoneController = TextEditingController(text: profile.phone);
    _footerController = TextEditingController(text: profile.receiptFooter);
    _serverUrlController = TextEditingController(text: profile.serverUrl);
    _paperWidth = profile.paperWidth;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _footerController.dispose();
    _serverUrlController.dispose();
    super.dispose();
  }

  Future<void> _handleTestApi(PosProvider pos) async {
    setState(() {
      _isTestingApi = true;
      _lastTestResult = null;
    });

    final targetUrl = _serverUrlController.text.trim().isNotEmpty
        ? _serverUrlController.text.trim()
        : pos.storeProfile.serverUrl;

    final result = await pos.testApiConnection(targetUrl);

    if (mounted) {
      setState(() {
        _isTestingApi = false;
        _lastTestResult = result;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message ?? (result.isSuccess ? 'Terhubung!' : 'Koneksi gagal')),
          backgroundColor: result.isSuccess ? AppTheme.accent : AppTheme.danger,
        ),
      );
    }
  }

  Future<void> _handleSyncMenu(PosProvider pos) async {
    setState(() => _isSyncingMenu = true);

    final count = await pos.syncMenuFromOnline();

    if (mounted) {
      setState(() => _isSyncingMenu = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            count > 0
                ? '$count menu berhasil disinkronkan dari server online!'
                : 'Tidak ada perubahan menu atau server offline.',
          ),
          backgroundColor: count > 0 ? AppTheme.accent : AppTheme.textSecondary,
        ),
      );
    }
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
                        hintText: 'Contoh: Matur Nuwun Sampun Pinarak!',
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

              const SizedBox(height: 20),

              // Section 3: Server Sync (VPS / Local)
              const Text(
                'Koneksi Server Online & API (menu-jajan)',
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
                    TextFormField(
                      controller: _serverUrlController,
                      decoration: const InputDecoration(
                        labelText: 'URL Server / IP VPS *',
                        hintText: 'http://13.211.188.77:3015',
                        prefixIcon: Icon(Icons.dns_outlined, size: 20),
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'URL Server wajib diisi' : null,
                    ),
                    const SizedBox(height: 12),

                    // Test API & Sync Menu Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isTestingApi ? null : () => _handleTestApi(pos),
                            icon: _isTestingApi
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.network_check, size: 18),
                            label: Text(_isTestingApi ? 'Menguji...' : 'Tes Koneksi & API'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isSyncingMenu ? null : () => _handleSyncMenu(pos),
                            icon: _isSyncingMenu
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.sync, size: 18),
                            label: Text(_isSyncingMenu ? 'Menyinkronkan...' : 'Tarik Menu Web'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Status Result Box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: (_lastTestResult?.isSuccess ?? pos.isOnlineSyncAvailable)
                            ? AppTheme.success.withOpacity(0.08)
                            : AppTheme.danger.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: (_lastTestResult?.isSuccess ?? pos.isOnlineSyncAvailable)
                              ? AppTheme.success.withOpacity(0.3)
                              : AppTheme.danger.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            (_lastTestResult?.isSuccess ?? pos.isOnlineSyncAvailable)
                                ? Icons.check_circle
                                : Icons.error_outline,
                            size: 18,
                            color: (_lastTestResult?.isSuccess ?? pos.isOnlineSyncAvailable)
                                ? AppTheme.success
                                : AppTheme.danger,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (_lastTestResult?.isSuccess ?? pos.isOnlineSyncAvailable)
                                      ? 'Server Terhubung & Aktif'
                                      : 'Server Belum Terhubung',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: (_lastTestResult?.isSuccess ?? pos.isOnlineSyncAvailable)
                                        ? AppTheme.success
                                        : AppTheme.danger,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _lastTestResult?.message ??
                                      (pos.isOnlineSyncAvailable
                                          ? 'Sinkronisasi meja & pesanan mandiri QR online aktif.'
                                          : 'Pastikan IP VPS dan port 3015 terbuka di Security Group AWS.'),
                                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                ),
                                if (_lastTestResult?.warungName != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Warung: ${_lastTestResult!.warungName} (Mode: ${_lastTestResult!.operationalMode?.toUpperCase()}) • Latensi: ${_lastTestResult!.latencyMs}ms',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
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
                        serverUrl: _serverUrlController.text.trim(),
                      );
                      await pos.updateStoreProfile(updated);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Pengaturan toko & koneksi server berhasil disimpan'),
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
                      'Arsitektur Hybrid: Offline-First SQLite + Online Sync VPS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Versi ${AppConstants.appVersion} • Kedai POS Angkringan ABS',
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
