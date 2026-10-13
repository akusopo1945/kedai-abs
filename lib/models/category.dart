class Category {
  final int? id;
  final String name;
  final String? icon;

  Category({
    this.id,
    required this.name,
    this.icon,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'icon': icon,
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as int?,
      name: map['name'] as String,
      icon: map['icon'] as String?,
    );
  }
}
