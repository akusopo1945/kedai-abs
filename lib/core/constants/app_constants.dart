class AppConstants {
  static const String appName = 'Kedai POS - Angkringan Bersua Sejenak';
  static const String appVersion = '1.1.0';
  static const String dbName = 'kedai_pos_abs.db';
  static const int dbVersion = 2;

  // Default Categories for Angkringan Bersua Sejenak
  static const List<String> defaultCategories = [
    'Semua',
    'Sate-satean',
    'Nasi Kucing',
    'Gorengan',
    'Wedangan',
    'Minuman Dingin',
  ];

  // Default Tables
  static const List<String> defaultTables = [
    'Meja 01',
    'Meja 02',
    'Meja 03',
    'Meja 04',
    'Meja 05',
    'Meja 06',
    'Meja 07',
    'Meja 08',
    'Meja 09',
    'Meja 10',
    'Meja 11',
    'Meja 12',
    'Bungkus / Takeaway',
  ];

  // Quick cash payment chips
  static const List<int> quickCashDenominations = [
    10000,
    20000,
    50000,
    100000,
  ];

  // Default Sync Server URL (menu-jajan PM2 backend)
  static const String defaultServerUrl = 'http://127.0.0.1:3015';
}
