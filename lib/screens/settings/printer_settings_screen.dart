import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/printer_service.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/pos_provider.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  List<BluetoothPrinterDevice>? _devices;
  String? _loadError;
  bool _loading = false;
  bool _testing = false;

  Future<void> _loadDevices(PosProvider pos) async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final devices = await pos.pairedPrinters();
      if (!mounted) return;
      setState(() => _devices = devices);
    } on PrinterException catch (e) {
      if (!mounted) return;
      setState(() => _loadError = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _testPrint(PosProvider pos) async {
    setState(() => _testing = true);
    final messenger = ScaffoldMessenger.of(context);
    final error = await pos.printTestPage();
    if (mounted) setState(() => _testing = false);
    messenger.showSnackBar(
      SnackBar(
        content: Text(error ?? 'Halaman tes terkirim ke printer.'),
        backgroundColor: error == null ? AppTheme.accent : AppTheme.danger,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pos = context.watch<PosProvider>();
    final settings = pos.printerSettings;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Printer Bluetooth')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _card([
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                settings.isConfigured ? Icons.print : Icons.print_disabled,
                color: settings.isConfigured
                    ? AppTheme.success
                    : AppTheme.textMuted,
              ),
              title: Text(
                settings.isConfigured
                    ? settings.name ?? settings.address!
                    : 'Belum ada printer dipilih',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                settings.isConfigured
                    ? '${settings.address} • Kertas ${pos.storeProfile.paperWidth} mm'
                    : 'Pilih dari daftar printer yang sudah dipasangkan.',
              ),
              trailing: settings.isConfigured
                  ? IconButton(
                      icon: const Icon(Icons.link_off),
                      tooltip: 'Lepas printer',
                      onPressed: () =>
                          pos.savePrinterSettings(settings.withoutPrinter()),
                    )
                  : null,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _loading ? null : () => _loadDevices(pos),
                    icon: _loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.bluetooth_searching, size: 18),
                    label: const Text('Pilih Printer'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: !settings.isConfigured || _testing
                        ? null
                        : () => _testPrint(pos),
                    icon: _testing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.receipt_long, size: 18),
                    label: const Text('Tes Cetak'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ]),
          if (_loadError != null) ...[
            const SizedBox(height: 12),
            _notice(_loadError!, AppTheme.danger),
          ],
          if (_devices != null) ...[
            const SizedBox(height: 12),
            _card([
              if (_devices!.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Tidak ada perangkat yang dipasangkan. Nyalakan printer, '
                    'lalu pasangkan dulu lewat Pengaturan Bluetooth Android '
                    '(PIN biasanya 0000 atau 1234).',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              for (final device in _devices!)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    device.address == settings.address
                        ? Icons.check_circle
                        : Icons.bluetooth,
                    color: device.address == settings.address
                        ? AppTheme.success
                        : AppTheme.primary,
                  ),
                  title: Text(device.name),
                  subtitle: Text(device.address),
                  onTap: () async {
                    await pos.savePrinterSettings(
                      settings.copyWith(
                        address: device.address,
                        name: device.name,
                      ),
                    );
                    if (mounted) setState(() => _devices = null);
                  },
                ),
            ]),
          ],
          const SizedBox(height: 20),
          const Text(
            'Opsi Cetak',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          _card([
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Cetak otomatis setelah transaksi'),
              value: settings.autoPrint,
              onChanged: (value) =>
                  pos.savePrinterSettings(settings.copyWith(autoPrint: value)),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Jumlah salinan'),
              trailing: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 1, label: Text('1')),
                  ButtonSegment(value: 2, label: Text('2')),
                  ButtonSegment(value: 3, label: Text('3')),
                ],
                selected: {settings.copies},
                showSelectedIcon: false,
                onSelectionChanged: (value) => pos.savePrinterSettings(
                  settings.copyWith(copies: value.first),
                ),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Potong kertas otomatis'),
              subtitle:
                  const Text('Hanya untuk printer yang punya auto-cutter.'),
              value: settings.autoCut,
              onChanged: (value) =>
                  pos.savePrinterSettings(settings.copyWith(autoCut: value)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Buka laci kas saat bayar tunai'),
              subtitle: const Text(
                'Untuk laci kas yang tersambung ke printer (port RJ11).',
              ),
              value: settings.openCashDrawer,
              onChanged: (value) => pos.savePrinterSettings(
                settings.copyWith(openCashDrawer: value),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          const Text(
            'Ukuran kertas (58/80 mm) diatur di halaman Pengaturan utama. '
            'Printer yang didukung: printer thermal Bluetooth ESC/POS.',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _card(List<Widget> children) => Container(
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

  Widget _notice(String text, Color color) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(text, style: TextStyle(fontSize: 12, color: color)),
      );
}
