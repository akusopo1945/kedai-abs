import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';

class BillItemSummary {
  final String nama;
  final String? opsi;
  final int jumlah;
  final double hargaSatuan;
  final double subtotal;

  BillItemSummary({
    required this.nama,
    this.opsi,
    required this.jumlah,
    required this.hargaSatuan,
    required this.subtotal,
  });

  factory BillItemSummary.fromMap(Map<String, dynamic> map) {
    return BillItemSummary(
      nama: map['nama']?.toString() ?? '',
      opsi: map['opsi']?.toString(),
      jumlah: (map['jumlah'] as num?)?.toInt() ?? 1,
      hargaSatuan: (map['hargaSatuan'] as num?)?.toDouble() ?? 0.0,
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class BillSummary {
  final String nomorMeja;
  final String namaPemesan;
  final String waktuAwal;
  final double totalTagihan;
  final int jumlahPesanan;
  final List<dynamic> daftarPesanan;
  final List<BillItemSummary> items;

  BillSummary({
    required this.nomorMeja,
    required this.namaPemesan,
    required this.waktuAwal,
    required this.totalTagihan,
    required this.jumlahPesanan,
    required this.daftarPesanan,
    required this.items,
  });

  factory BillSummary.fromMap(Map<String, dynamic> map) {
    final rawItems = map['items'] as List<dynamic>? ?? [];
    return BillSummary(
      nomorMeja: (map['nomorMeja'] ?? map['meja'])?.toString() ?? '',
      namaPemesan: map['namaPemesan']?.toString() ?? 'Pelanggan',
      waktuAwal: map['waktuAwal']?.toString() ?? '',
      totalTagihan: (map['totalTagihan'] as num?)?.toDouble() ?? 0.0,
      jumlahPesanan: (map['jumlahPesanan'] ?? map['totalPesanan'] as num?)?.toInt() ?? 0,
      daftarPesanan: (map['daftarPesanan'] ?? map['orders'] as List<dynamic>?) ?? [],
      items: rawItems.map((e) => BillItemSummary.fromMap(e as Map<String, dynamic>)).toList(),
    );
  }
}

class ApiTestResult {
  final bool isSuccess;
  final int latencyMs;
  final String? warungName;
  final String? operationalMode;
  final String? message;

  ApiTestResult({
    required this.isSuccess,
    required this.latencyMs,
    this.warungName,
    this.operationalMode,
    this.message,
  });
}

class MenuJajanApiService {
  final String baseUrl;

  MenuJajanApiService({this.baseUrl = AppConstants.defaultServerUrl});

  String _cleanUrl(String path) {
    final cleanBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return '$cleanBase$cleanPath';
  }

  /// Format nomor meja: pastikan cocok dengan backend (misal "Meja 01" -> "01")
  static String normalizeMeja(String meja) {
    final trimmed = meja.trim();
    if (trimmed.toLowerCase().startsWith('meja ')) {
      return trimmed.substring(5).trim();
    }
    return trimmed;
  }

  Future<ApiTestResult> testConnection() async {
    final stopwatch = Stopwatch()..start();
    try {
      final res = await http.get(Uri.parse(_cleanUrl('/api/settings'))).timeout(const Duration(seconds: 4));
      stopwatch.stop();

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final settings = data is Map<String, dynamic> && data.containsKey('namaWarung')
            ? data
            : (data['data'] as Map<String, dynamic>? ?? {});

        return ApiTestResult(
          isSuccess: true,
          latencyMs: stopwatch.elapsedMilliseconds,
          warungName: settings['namaWarung']?.toString() ?? 'Angkringan Bersua Sejenak',
          operationalMode: settings['modeOperasional']?.toString() ?? 'buka',
          message: 'Koneksi API berhasil (${stopwatch.elapsedMilliseconds}ms)',
        );
      } else {
        return ApiTestResult(
          isSuccess: false,
          latencyMs: stopwatch.elapsedMilliseconds,
          message: 'Server merespons kode HTTP ${res.statusCode}',
        );
      }
    } catch (e) {
      stopwatch.stop();
      return ApiTestResult(
        isSuccess: false,
        latencyMs: stopwatch.elapsedMilliseconds,
        message: 'Koneksi gagal: ${e.toString().split(':').last.trim()}',
      );
    }
  }

  Future<bool> checkConnection() async {
    final result = await testConnection();
    return result.isSuccess;
  }

  Future<Map<String, dynamic>?> getSettings() async {
    try {
      final res = await http.get(Uri.parse(_cleanUrl('/api/settings'))).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        return decoded is Map<String, dynamic> ? decoded : null;
      }
    } catch (_) {}
    return null;
  }

  Future<List<dynamic>> getLiveMenu() async {
    try {
      final res = await http.get(Uri.parse(_cleanUrl('/api/menu'))).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic> && decoded.containsKey('data')) {
          return decoded['data'] as List<dynamic>;
        } else if (decoded is List) {
          return decoded;
        }
      }
    } catch (_) {}
    return [];
  }

  Future<List<dynamic>> getLiveOrders() async {
    try {
      final res = await http.get(Uri.parse(_cleanUrl('/api/orders'))).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic> && decoded.containsKey('data')) {
          return decoded['data'] as List<dynamic>;
        } else if (decoded is List) {
          return decoded;
        }
      }
    } catch (_) {}
    return [];
  }

  Future<List<BillSummary>> getLiveBills() async {
    try {
      final res = await http.get(Uri.parse(_cleanUrl('/api/bills'))).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        List<dynamic> list = [];
        if (decoded is Map<String, dynamic> && decoded.containsKey('data')) {
          list = decoded['data'] as List<dynamic>;
        } else if (decoded is List) {
          list = decoded;
        }
        return list.map((e) => BillSummary.fromMap(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<bool> updateOrderStatus(String orderId, String newStatus) async {
    try {
      final res = await http.patch(
        Uri.parse(_cleanUrl('/api/orders/$orderId/status')),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'status': newStatus}),
      ).timeout(const Duration(seconds: 4));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> settleBill(String rawMeja, {String metodeBayar = 'tunai'}) async {
    try {
      final mejaClean = normalizeMeja(rawMeja);
      final encodedMeja = Uri.encodeComponent(mejaClean);
      final res = await http.post(
        Uri.parse(_cleanUrl('/api/bills/$encodedMeja/settle')),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'metodeBayar': metodeBayar}),
      ).timeout(const Duration(seconds: 4));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> toggleMenuAvailability(String menuId) async {
    try {
      final res = await http.patch(
        Uri.parse(_cleanUrl('/api/menu/$menuId/toggle')),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 4));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
