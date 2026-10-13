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
        customer_name TEXT
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
        paper_width INTEGER NOT NULL DEFAULT 58
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

    // Seed sample products
    final sampleProducts = [
      Product(
        name: 'Kopi Susu Gula Aren',
        sku: 'KOP-01',
        category: 'Minuman',
        buyPrice: 8000,
        sellPrice: 18000,
        stock: 50,
      ),
      Product(
        name: 'Americano Ice',
        sku: 'KOP-02',
        category: 'Minuman',
        buyPrice: 5000,
        sellPrice: 15000,
        stock: 45,
      ),
      Product(
        name: 'Matcha Latte',
        sku: 'NON-01',
        category: 'Minuman',
        buyPrice: 10000,
        sellPrice: 22000,
        stock: 30,
      ),
      Product(
        name: 'Croissant Butter',
        sku: 'PAS-01',
        category: 'Makanan',
        buyPrice: 12000,
        sellPrice: 25000,
        stock: 20,
      ),
      Product(
        name: 'Roti Bakar Keju Cokelat',
        sku: 'SNK-01',
        category: 'Makanan',
        buyPrice: 9000,
        sellPrice: 20000,
        stock: 25,
      ),
      Product(
        name: 'Kentang Goreng Crispy',
        sku: 'SNK-02',
        category: 'Camilan',
        buyPrice: 7000,
        sellPrice: 16000,
        stock: 35,
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
