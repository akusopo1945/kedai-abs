import '../core/constants/app_constants.dart';

class StoreProfile {
  final String name;
  final String address;
  final String phone;
  final String receiptFooter;
  final int paperWidth; // 58 or 80 mm
  final String serverUrl;

  StoreProfile({
    this.name = 'Angkringan Bersua Sejenak',
    this.address = 'Jl. Raya Wagir, Hal. SDN Sitirejo 4 (Barat SMPN 1 Wagir)',
    this.phone = '6281249176420',
    this.receiptFooter = 'Matur Nuwun Sampun Pinarak!\nKhas Yogyakarta • Arang & Wedangan',
    this.paperWidth = 58,
    this.serverUrl = AppConstants.defaultServerUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'address': address,
      'phone': phone,
      'receipt_footer': receiptFooter,
      'paper_width': paperWidth,
      'server_url': serverUrl,
    };
  }

  factory StoreProfile.fromMap(Map<String, dynamic> map) {
    return StoreProfile(
      name: map['name'] as String? ?? 'Angkringan Bersua Sejenak',
      address: map['address'] as String? ?? 'Jl. Raya Wagir, Hal. SDN Sitirejo 4 (Barat SMPN 1 Wagir)',
      phone: map['phone'] as String? ?? '6281249176420',
      receiptFooter: map['receipt_footer'] as String? ?? 'Matur Nuwun Sampun Pinarak!',
      paperWidth: map['paper_width'] as int? ?? 58,
      serverUrl: map['server_url'] as String? ?? AppConstants.defaultServerUrl,
    );
  }
}
