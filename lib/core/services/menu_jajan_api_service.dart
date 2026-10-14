import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';

class BillSummary {
  final String meja;
  final int totalPesanan;
  final double totalTagihan;
  final List<dynamic> orders;

  BillSummary({
    required this.meja,
    required this.totalPesanan,
    required this.totalTagihan,
    required this.orders,
  });

  factory BillSummary.fromMap(Map<String, dynamic> map) {
    return BillSummary(
      meja: map['meja']?.toString() ?? '',
      totalPesanan: (map['totalPesanan'] as num?)?.toInt() ?? 0,
      totalTagihan: (map['totalTagihan'] as num?)?.toDouble() ?? 0.0,
      orders: (map['orders'] as List<dynamic>?) ?? [],
    );
  }
}

class MenuJajanApiService {
  final String baseUrl;

  MenuJajanApiService({this.baseUrl = AppConstants.defaultServerUrl});

  Future<bool> checkConnection() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/settings')).timeout(const Duration(seconds: 3));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> getSettings() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/settings')).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  Future<List<dynamic>> getLiveMenu() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/menu')).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as List<dynamic>;
      }
    } catch (_) {}
    return [];
  }

  Future<List<dynamic>> getLiveOrders() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/orders')).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as List<dynamic>;
      }
    } catch (_) {}
    return [];
  }

  Future<List<BillSummary>> getLiveBills() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/bills')).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        return data.map((e) => BillSummary.fromMap(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<bool> updateOrderStatus(String orderId, String newStatus) async {
    try {
      final res = await http.patch(
        Uri.parse('$baseUrl/api/orders/$orderId/status'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'status': newStatus}),
      ).timeout(const Duration(seconds: 4));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> settleBill(String meja) async {
    try {
      final encodedMeja = Uri.encodeComponent(meja);
      final res = await http.post(
        Uri.parse('$baseUrl/api/bills/$encodedMeja/settle'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 4));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
