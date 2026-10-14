class Product {
  final int? id;
  final String name;
  final String? sku;
  final String category;
  final double buyPrice;
  final double sellPrice;
  final int stock;
  final String? imageUrl;
  final bool isActive;
  final List<String> opsiList;
  final String? tagKuliner;
  final String? badgeKhusus;
  final String? description;

  Product({
    this.id,
    required this.name,
    this.sku,
    required this.category,
    required this.buyPrice,
    required this.sellPrice,
    required this.stock,
    this.imageUrl,
    this.isActive = true,
    this.opsiList = const [],
    this.tagKuliner,
    this.badgeKhusus,
    this.description,
  });

  double get profit => sellPrice - buyPrice;
  double get profitMargin => sellPrice > 0 ? (profit / sellPrice) * 100 : 0;
  bool get hasOptions => opsiList.isNotEmpty;

  Product copyWith({
    int? id,
    String? name,
    String? sku,
    String? category,
    double? buyPrice,
    double? sellPrice,
    int? stock,
    String? imageUrl,
    bool? isActive,
    List<String>? opsiList,
    String? tagKuliner,
    String? badgeKhusus,
    String? description,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      category: category ?? this.category,
      buyPrice: buyPrice ?? this.buyPrice,
      sellPrice: sellPrice ?? this.sellPrice,
      stock: stock ?? this.stock,
      imageUrl: imageUrl ?? this.imageUrl,
      isActive: isActive ?? this.isActive,
      opsiList: opsiList ?? this.opsiList,
      tagKuliner: tagKuliner ?? this.tagKuliner,
      badgeKhusus: badgeKhusus ?? this.badgeKhusus,
      description: description ?? this.description,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'sku': sku,
      'category': category,
      'buy_price': buyPrice,
      'sell_price': sellPrice,
      'stock': stock,
      'image_url': imageUrl,
      'is_active': isActive ? 1 : 0,
      'opsi_list': opsiList.join(','),
      'tag_kuliner': tagKuliner,
      'badge_khusus': badgeKhusus,
      'description': description,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    final opsiRaw = map['opsi_list'] as String?;
    final opsiParsed = (opsiRaw != null && opsiRaw.isNotEmpty)
        ? opsiRaw.split(',').map((e) => e.trim()).toList()
        : <String>[];

    return Product(
      id: map['id'] as int?,
      name: map['name'] as String,
      sku: map['sku'] as String?,
      category: map['category'] as String,
      buyPrice: (map['buy_price'] as num).toDouble(),
      sellPrice: (map['sell_price'] as num).toDouble(),
      stock: map['stock'] as int,
      imageUrl: map['image_url'] as String?,
      isActive: (map['is_active'] as int) == 1,
      opsiList: opsiParsed,
      tagKuliner: map['tag_kuliner'] as String?,
      badgeKhusus: map['badge_khusus'] as String?,
      description: map['description'] as String?,
    );
  }
}
