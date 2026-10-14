import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../models/category.dart';
import '../../models/product.dart';
import '../../models/order.dart';
import '../../models/store_profile.dart';
import '../constants/app_constants.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB(AppConstants.dbName);
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: AppConstants.dbVersion,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Categories table
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        icon TEXT
      )
    ''');

    // Products table
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        sku TEXT,
        category TEXT NOT NULL,
        buy_price REAL NOT NULL,
        sell_price REAL NOT NULL,
        stock INTEGER NOT NULL DEFAULT 0,
        image_url TEXT,
        tag_kuliner TEXT,
        badge_khusus TEXT,
        description TEXT,
        opsi_list TEXT,
        is_active INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // Orders table
    await db.execute('''
      CREATE TABLE orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_number TEXT NOT NULL UNIQUE,
        created_at TEXT NOT NULL,
        total_amount REAL NOT NULL,
        discount_amount REAL NOT NULL DEFAULT 0,
        final_amount REAL NOT NULL,
        payment_amount REAL NOT NULL,
        change_amount REAL NOT NULL,
        payment_method TEXT NOT NULL,
        customer_name TEXT,
        table_number TEXT,
        status TEXT NOT NULL DEFAULT 'selesai'
      )
    ''');

    // Order items table
    await db.execute('''
      CREATE TABLE order_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        product_name TEXT NOT NULL,
        unit_price REAL NOT NULL,
        buy_price REAL NOT NULL,
        quantity INTEGER NOT NULL,
        subtotal REAL NOT NULL,
        note TEXT,
        selected_option TEXT,
        FOREIGN KEY (order_id) REFERENCES orders (id) ON DELETE CASCADE
      )
    ''');

    // Store settings table
    await db.execute('''
      CREATE TABLE store_settings (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        name TEXT NOT NULL,
        address TEXT NOT NULL,
        phone TEXT NOT NULL,
        receipt_footer TEXT NOT NULL,
        paper_width INTEGER NOT NULL DEFAULT 58,
        server_url TEXT NOT NULL DEFAULT 'http://13.211.188.77:3015'
      )
    ''');

    // Seed default data
    await _seedInitialData(db);
  }

  Future<void> _seedInitialData(Database db) async {
    // Seed categories
    for (final cat in AppConstants.defaultCategories) {
      if (cat != 'Semua') {
        await db.insert('categories', {'name': cat});
      }
    }

    // Seed authentic ABS products from menu-jajan
    final sampleProducts = [
      Product(
        name: 'Sate Kulit Ayam Madu',
        sku: 'SAT-01',
        category: 'Sate-satean',
        buyPrice: 1500,
        sellPrice: 3000,
        stock: 50,
        tagKuliner: 'Arang Batok',
        badgeKhusus: 'Favorit Meja',
        description: 'Kulit ayam pilihan ungkep bumbu kuning, kenyal gurih dengan karamelisasi manis pedas di atas arang batok.',
        opsiList: ['Bakar Manis Gurih', 'Bakar Pedas Membara', 'Langsung Makan'],
      ),
      Product(
        name: 'Sate Usus Bacem',
        sku: 'SAT-02',
        category: 'Sate-satean',
        buyPrice: 1500,
        sellPrice: 3000,
        stock: 40,
        tagKuliner: 'Bumbu Bacem',
        badgeKhusus: 'Paling Laris',
        description: 'Usus ayam bersih dibacem gula kelapa asli, gurih legit harum daun salam.',
        opsiList: ['Bakar Manis Gurih', 'Bakar Pedas Membara', 'Langsung Makan'],
      ),
      Product(
        name: 'Sate Telur Puyuh Karamel',
        sku: 'SAT-03',
        category: 'Sate-satean',
        buyPrice: 2000,
        sellPrice: 4000,
        stock: 35,
        tagKuliner: 'Resep Lawas',
        description: '4 butir telur puyuh utuh baceman medok pekat kecap kedelai hitam tradisional.',
        opsiList: ['Bakar Manis Gurih', 'Langsung Makan'],
      ),
      Product(
        name: 'Sate Ati Ampela Ungkep',
        sku: 'SAT-04',
        category: 'Sate-satean',
        buyPrice: 2000,
        sellPrice: 4000,
        stock: 30,
        tagKuliner: 'Rempah Ungkep',
        description: 'Potongan hati dan ampela ayam empuk kaya rempah ketumbar dan lengkuas.',
        opsiList: ['Bakar Manis Gurih', 'Bakar Pedas Membara', 'Langsung Makan'],
      ),
      Product(
        name: 'Sate Bakso Sapi Urat',
        sku: 'SAT-05',
        category: 'Sate-satean',
        buyPrice: 1800,
        sellPrice: 3500,
        stock: 45,
        tagKuliner: 'Saus Olesan',
        description: 'Bakso daging urat sapi gurih dioles racikan saus bakar barbeque pedas manis.',
        opsiList: ['Bakar Pedas Membara', 'Bakar Manis Gurih', 'Langsung Makan'],
      ),
      Product(
        name: 'Sego Kucing Sambal Teri',
        sku: 'NAS-01',
        category: 'Nasi Kucing',
        buyPrice: 1800,
        sellPrice: 3500,
        stock: 60,
        tagKuliner: 'Daun Pisang',
        badgeKhusus: 'Ikonik',
        description: 'Bungkusan daun pisang wangi berisi nasi pulen hangat dan sambal teri lombok ijo pedas nampol.',
        opsiList: ['Langsung Santap', 'Bakar Hangat'],
      ),
      Product(
        name: 'Sego Kucing Tempe Orek',
        sku: 'NAS-02',
        category: 'Nasi Kucing',
        buyPrice: 1800,
        sellPrice: 3500,
        stock: 50,
        tagKuliner: 'Khas Djogja',
        description: 'Nasi bungkus klasik dengan tumisan tempe orek manis legit bertabur bawang goreng renyah.',
        opsiList: ['Langsung Santap', 'Bakar Hangat'],
      ),
      Product(
        name: 'Nasi Bakar Ayam Suwir Kemangi',
        sku: 'NAS-03',
        category: 'Nasi Kucing',
        buyPrice: 4000,
        sellPrice: 7500,
        stock: 25,
        tagKuliner: 'Bakar Arang',
        badgeKhusus: 'Spesial',
        description: 'Nasi gurih santan rempah dengan isian ayam suwir bumbu rica pedas dan daun kemangi harum semerbak.',
      ),
      Product(
        name: 'Tempe Mendoan Anget (Porsi 2)',
        sku: 'GOR-01',
        category: 'Gorengan',
        buyPrice: 1800,
        sellPrice: 3500,
        stock: 40,
        tagKuliner: 'Kecap Rawit',
        badgeKhusus: 'Goreng Dadakan',
        description: 'Tempe lebar tepung basah berbumbu daun bawang kucai, disajikan dengan kecap rawit kental.',
        opsiList: ['Hangatkan / Bakar', 'Langsung Santap'],
      ),
      Product(
        name: 'Bala-Bala Bakwan Renyah',
        sku: 'GOR-02',
        category: 'Gorengan',
        buyPrice: 1000,
        sellPrice: 2000,
        stock: 50,
        tagKuliner: 'Renyah Gurih',
        description: 'Adonan sayur kubis, wortel, dan tauge garing di luar lembut di dalam.',
      ),
      Product(
        name: 'Kopi Joss Arang Membara',
        sku: 'WED-01',
        category: 'Wedangan',
        buyPrice: 2500,
        sellPrice: 6000,
        stock: 50,
        tagKuliner: 'Arang Merah',
        badgeKhusus: 'Legenda',
        description: 'Kopi tubruk robusta pekat yang dicelup potongan arang kayu mendidih berdesis. Rendah asam lambung.',
        opsiList: ['Panas Berdesis', 'Hangat'],
      ),
      Product(
        name: 'Wedang Jahe Susu Murni',
        sku: 'WED-02',
        category: 'Wedangan',
        buyPrice: 2500,
        sellPrice: 6000,
        stock: 45,
        tagKuliner: 'Jahe Merah',
        badgeKhusus: 'Penghangat',
        description: 'Geprekan jahe merah bakar aromatik diseduh air gula kelapa dan susu kental manis pekat.',
        opsiList: ['Panas', 'Hangat'],
      ),
      Product(
        name: 'Wedang Uwuh Kraton',
        sku: 'WED-03',
        category: 'Wedangan',
        buyPrice: 2500,
        sellPrice: 6000,
        stock: 40,
        tagKuliner: 'Rempah Kraton',
        description: 'Seduhan rempah secang merah, cengkeh, kayu manis, pala, dan gula batu kristal asli Imogiri.',
        opsiList: ['Panas Rempah', 'Hangat'],
      ),
      Product(
        name: 'Es Teh Melati Ginastel',
        sku: 'MIN-01',
        category: 'Minuman Dingin',
        buyPrice: 1500,
        sellPrice: 3500,
        stock: 100,
        tagKuliner: 'Ginastel Solo',
        badgeKhusus: 'Wajib Coba',
        description: 'Racikan 3 merk teh Jawa legendaris: Legi, Kentel, Sepet, dengan wangi melati alami.',
        opsiList: ['Es Dingin Segar', 'Hangat'],
      ),
      Product(
        name: 'Es Jeruk Peras Madu',
        sku: 'MIN-02',
        category: 'Minuman Dingin',
        buyPrice: 2000,
        sellPrice: 5000,
        stock: 50,
        tagKuliner: '100% Jeruk Asli',
        description: 'Jeruk peras murni asam manis segar dengan tetesan gula tebu murni.',
        opsiList: ['Es Dingin Segar', 'Hangat'],
      ),
    ];

    for (final p in sampleProducts) {
      await db.insert('products', p.toMap());
    }

    // Seed store settings
    final defaultStore = StoreProfile();
    await db.insert('store_settings', {'id': 1, ...defaultStore.toMap()});
  }

  // --- Products CRUD ---
  Future<List<Product>> getProducts({String? category, String? query}) async {
    final db = await instance.database;
    String whereClause = 'is_active = 1';
    List<dynamic> whereArgs = [];

    if (category != null && category.isNotEmpty && category != 'Semua') {
      whereClause += ' AND category = ?';
      whereArgs.add(category);
    }

    if (query != null && query.trim().isNotEmpty) {
      whereClause += ' AND (name LIKE ? OR sku LIKE ?)';
      whereArgs.add('%$query%');
      whereArgs.add('%$query%');
    }

    final result = await db.query(
      'products',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'name ASC',
    );

    return result.map((json) => Product.fromMap(json)).toList();
  }

  Future<int> insertProduct(Product product) async {
    final db = await instance.database;
    return await db.insert('products', product.toMap());
  }

  Future<int> updateProduct(Product product) async {
    final db = await instance.database;
    return await db.update(
      'products',
      product.toMap(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  Future<int> deleteProduct(int id) async {
    final db = await instance.database;
    // Soft delete
    return await db.update(
      'products',
      {'is_active': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- Categories CRUD ---
  Future<List<Category>> getCategories() async {
    final db = await instance.database;
    final result = await db.query('categories', orderBy: 'id ASC');
    return result.map((json) => Category.fromMap(json)).toList();
  }

  Future<int> insertCategory(String name) async {
    final db = await instance.database;
    return await db.insert('categories', {'name': name});
  }

  // --- Orders & Transactions ---
  Future<int> insertOrder(OrderModel order) async {
    final db = await instance.database;
    return await db.transaction((txn) async {
      // 1. Insert order
      final orderId = await txn.insert('orders', order.toMap());

      // 2. Insert items & deduct stock
      for (final item in order.items) {
        await txn.insert('order_items', {
          ...item.toMap(),
          'order_id': orderId,
        });

        // Deduct product stock
        await txn.rawUpdate('''
          UPDATE products 
          SET stock = MAX(0, stock - ?) 
          WHERE id = ?
        ''', [item.quantity, item.productId]);
      }

      return orderId;
    });
  }

  Future<List<OrderModel>> getOrders({DateTime? startDate, DateTime? endDate}) async {
    final db = await instance.database;
    String? whereClause;
    List<dynamic>? whereArgs;

    if (startDate != null && endDate != null) {
      whereClause = 'created_at BETWEEN ? AND ?';
      whereArgs = [startDate.toIso8601String(), endDate.toIso8601String()];
    }

    final orderRows = await db.query(
      'orders',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
    );

    List<OrderModel> orders = [];
    for (final row in orderRows) {
      final orderId = row['id'] as int;
      final itemRows = await db.query(
        'order_items',
        where: 'order_id = ?',
        whereArgs: [orderId],
      );
      final items = itemRows.map((e) => OrderItem.fromMap(e)).toList();
      orders.add(OrderModel.fromMap(row, items: items));
    }

    return orders;
  }

  Future<Map<String, double>> getSummary(DateTime start, DateTime end) async {
    final orders = await getOrders(startDate: start, endDate: end);

    double totalRevenue = 0;
    double totalCost = 0;

    for (final order in orders) {
      totalRevenue += order.finalAmount;
      for (final item in order.items) {
        totalCost += (item.buyPrice * item.quantity);
      }
    }

    final totalProfit = totalRevenue - totalCost;

    return {
      'revenue': totalRevenue,
      'profit': totalProfit,
      'transactions': orders.length.toDouble(),
    };
  }

  // --- Store Profile ---
  Future<StoreProfile> getStoreProfile() async {
    final db = await instance.database;
    final result = await db.query('store_settings', where: 'id = 1');
    if (result.isNotEmpty) {
      return StoreProfile.fromMap(result.first);
    }
    return StoreProfile();
  }

  Future<int> saveStoreProfile(StoreProfile profile) async {
    final db = await instance.database;
    return await db.update(
      'store_settings',
      profile.toMap(),
      where: 'id = 1',
    );
  }
}
