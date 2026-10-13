class StoreProfile {
  final String name;
  final String address;
  final String phone;
  final String receiptFooter;
  final int paperWidth; // 58 or 80 mm

  StoreProfile({
    this.name = 'Kedai Kopi & Kasir',
    this.address = 'Jl. Melati No. 12, Jakarta',
    this.phone = '0812-3456-7890',
    this.receiptFooter = 'Terima Kasih Atas Kunjungan Anda!\nBarang yang sudah dibeli tidak dapat ditukar.',
    this.paperWidth = 58,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'address': address,
      'phone': phone,
      'receipt_footer': receiptFooter,
      'paper_width': paperWidth,
    };
  }

  factory StoreProfile.fromMap(Map<String, dynamic> map) {
    return StoreProfile(
      name: map['name'] as String? ?? 'Kedai Kopi & Kasir',
      address: map['address'] as String? ?? 'Jl. Melati No. 12, Jakarta',
      phone: map['phone'] as String? ?? '0812-3456-7890',
      receiptFooter: map['receipt_footer'] as String? ?? 'Terima Kasih Atas Kunjungan Anda!',
      paperWidth: map['paper_width'] as int? ?? 58,
    );
  }
}
