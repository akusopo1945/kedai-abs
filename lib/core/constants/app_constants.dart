class AppConstants {
  static const String appName = 'Kedai POS';
  static const String appVersion = '1.0.0';
  static const String dbName = 'kedai_pos.db';
  static const int dbVersion = 1;

  // Default Categories
  static const List<String> defaultCategories = [
    'Semua',
    'Makanan',
    'Minuman',
    'Camilan',
    'Paket Hemat',
    'Lainnya',
  ];

  // Quick cash payment chips
  static const List<int> quickCashDenominations = [
    10000,
    20000,
    50000,
    100000,
  ];
}
