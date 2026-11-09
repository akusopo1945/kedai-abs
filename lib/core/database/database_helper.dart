import 'dart:math' show min;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../../models/cart_item.dart';
import '../../models/category.dart';
import '../../models/product.dart';
import '../../models/order.dart';
import '../../models/payment.dart';
import '../../models/shift.dart';
import '../../models/store_profile.dart';
import '../constants/app_constants.dart';
import '../utils/id_generator.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  static String? _pathOverride;

  /// Tables included in backups, parents before children.
  static const List<String> backupTables = [
    'categories',
    'products',
    'store_settings',
    'app_settings',
    'shifts',
    'orders',
    'order_items',
    'payments',
    'held_orders',
  ];

  DatabaseHelper._init();

  @visibleForTesting
  static Future<void> useDatabaseAtPath(String path) async {
    await _database?.close();
    _database = null;
    _pathOverride = path;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB(AppConstants.dbName);
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final path = _pathOverride ?? join(await getDatabasesPath(), filePath);

    return await openDatabase(
      path,
      version: AppConstants.dbVersion,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
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
        status TEXT NOT NULL DEFAULT 'selesai',
        cost_known INTEGER NOT NULL DEFAULT 1
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
    await _createIndexes(db);
    await _migrateToV5(db);
    await _migrateToV6(db);
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      await _addColumnIfMissing(db, 'products', 'tag_kuliner', 'TEXT');
      await _addColumnIfMissing(db, 'products', 'badge_khusus', 'TEXT');
      await _addColumnIfMissing(db, 'products', 'description', 'TEXT');
      await _addColumnIfMissing(db, 'products', 'opsi_list', 'TEXT');
      await _addColumnIfMissing(
        db,
        'products',
        'is_active',
        'INTEGER NOT NULL DEFAULT 1',
      );
      await _addColumnIfMissing(
        db,
        'orders',
        'discount_amount',
        'REAL NOT NULL DEFAULT 0',
      );
      await _addColumnIfMissing(db, 'orders', 'table_number', 'TEXT');
      await _addColumnIfMissing(
        db,
        'orders',
        'status',
        "TEXT NOT NULL DEFAULT 'selesai'",
      );
      await _addColumnIfMissing(
        db,
        'orders',
        'cost_known',
        'INTEGER NOT NULL DEFAULT 1',
      );
      await _addColumnIfMissing(db, 'order_items', 'note', 'TEXT');
      await _addColumnIfMissing(db, 'order_items', 'selected_option', 'TEXT');
      await _addColumnIfMissing(
        db,
        'store_settings',
        'paper_width',
        'INTEGER NOT NULL DEFAULT 58',
      );
      await _addColumnIfMissing(
        db,
        'store_settings',
        'server_url',
        "TEXT NOT NULL DEFAULT '${AppConstants.defaultServerUrl}'",
      );
    }
    if (oldVersion < 4) {
      await _createIndexes(db);
    }
    if (oldVersion < 5) {
      await _migrateToV5(db);
    }
    if (oldVersion < 6) {
      await _migrateToV6(db);
    }
  }

  /// Key-value settings (payment methods, QRIS image, printer) and the
  /// payment note on orders. Idempotent like [_migrateToV5].
  Future<void> _migrateToV6(DatabaseExecutor db) async {
    await _addColumnIfMissing(db, 'orders', 'payment_note', 'TEXT');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  /// Shifts, payments (cash ledger incl. debt repayments) and persisted open
  /// bills. Idempotent, so it is also safe after restoring older backups.
  Future<void> _migrateToV5(DatabaseExecutor db) async {
    await _addColumnIfMissing(db, 'orders', 'uuid', 'TEXT');
    await _addColumnIfMissing(db, 'orders', 'shift_id', 'INTEGER');
    await _addColumnIfMissing(
      db,
      'orders',
      'source',
      "TEXT NOT NULL DEFAULT 'pos'",
    );
    await _addColumnIfMissing(
      db,
      'orders',
      'payment_status',
      "TEXT NOT NULL DEFAULT 'lunas'",
    );
    await _addColumnIfMissing(
      db,
      'orders',
      'paid_amount',
      'REAL NOT NULL DEFAULT 0',
    );
    await _addColumnIfMissing(db, 'orders', 'customer_phone', 'TEXT');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS shifts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        opened_at TEXT NOT NULL,
        closed_at TEXT,
        opening_cash REAL NOT NULL DEFAULT 0,
        counted_cash REAL,
        expected_cash REAL,
        note TEXT,
        status TEXT NOT NULL DEFAULT 'open'
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        order_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        method TEXT NOT NULL,
        paid_at TEXT NOT NULL,
        shift_id INTEGER,
        note TEXT,
        FOREIGN KEY (order_id) REFERENCES orders (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS held_orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name TEXT NOT NULL,
        product_id INTEGER NOT NULL,
        selected_option TEXT,
        note TEXT,
        quantity INTEGER NOT NULL,
        held_at TEXT NOT NULL
      )
    ''');

    await _backfillV5(db);

    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_orders_uuid ON orders (uuid)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_orders_shift ON orders (shift_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_orders_payment_status ON orders (payment_status)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_payments_order ON payments (order_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_payments_shift ON payments (shift_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_held_orders_table ON held_orders (table_name)',
    );
  }

  /// Gives pre-v5 orders an identity and a matching payment record so cash
  /// reports stay consistent with history.
  Future<void> _backfillV5(DatabaseExecutor db) async {
    await db.execute(
      "UPDATE orders SET uuid = 'legacy-' || id WHERE uuid IS NULL OR uuid = ''",
    );
    await db.execute(
      "UPDATE orders SET source = 'qr' WHERE invoice_number LIKE 'QR-%' AND source = 'pos'",
    );
    await db.execute('''
      UPDATE orders SET paid_amount = final_amount
      WHERE payment_status = 'lunas' AND paid_amount = 0 AND final_amount > 0
        AND NOT EXISTS (SELECT 1 FROM payments p WHERE p.order_id = orders.id)
    ''');
    await db.execute('''
      INSERT INTO payments (uuid, order_id, amount, method, paid_at, shift_id)
      SELECT 'legacy-pay-' || o.id, o.id, o.final_amount, o.payment_method,
             o.created_at, o.shift_id
      FROM orders o
      WHERE o.payment_status = 'lunas' AND o.final_amount > 0
        AND NOT EXISTS (SELECT 1 FROM payments p WHERE p.order_id = o.id)
    ''');
  }

  Future<void> _createIndexes(DatabaseExecutor db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_products_active_cat ON products (is_active, category)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_orders_created_at ON orders (created_at DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON order_items (order_id)',
    );
  }

  Future<void> _addColumnIfMissing(
    DatabaseExecutor db,
    String table,
    String column,
    String definition,
  ) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    if (columns.any((entry) => entry['name'] == column)) return;
    await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
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
        description:
            'Kulit ayam pilihan ungkep bumbu kuning, kenyal gurih dengan karamelisasi manis pedas di atas arang batok.',
        opsiList: [
          'Bakar Manis Gurih',
          'Bakar Pedas Membara',
          'Langsung Makan',
        ],
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
        description:
            'Usus ayam bersih dibacem gula kelapa asli, gurih legit harum daun salam.',
        opsiList: [
          'Bakar Manis Gurih',
          'Bakar Pedas Membara',
          'Langsung Makan',
        ],
      ),
      Product(
        name: 'Sate Telur Puyuh Karamel',
        sku: 'SAT-03',
        category: 'Sate-satean',
        buyPrice: 2000,
        sellPrice: 4000,
        stock: 35,
        tagKuliner: 'Resep Lawas',
        description:
            '4 butir telur puyuh utuh baceman medok pekat kecap kedelai hitam tradisional.',
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
        description:
            'Potongan hati dan ampela ayam empuk kaya rempah ketumbar dan lengkuas.',
        opsiList: [
          'Bakar Manis Gurih',
          'Bakar Pedas Membara',
          'Langsung Makan',
        ],
      ),
      Product(
        name: 'Sate Bakso Sapi Urat',
        sku: 'SAT-05',
        category: 'Sate-satean',
        buyPrice: 1800,
        sellPrice: 3500,
        stock: 45,
        tagKuliner: 'Saus Olesan',
        description:
            'Bakso daging urat sapi gurih dioles racikan saus bakar barbeque pedas manis.',
        opsiList: [
          'Bakar Pedas Membara',
          'Bakar Manis Gurih',
          'Langsung Makan',
        ],
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
        description:
            'Bungkusan daun pisang wangi berisi nasi pulen hangat dan sambal teri lombok ijo pedas nampol.',
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
        description:
            'Nasi bungkus klasik dengan tumisan tempe orek manis legit bertabur bawang goreng renyah.',
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
        description:
            'Nasi gurih santan rempah dengan isian ayam suwir bumbu rica pedas dan daun kemangi harum semerbak.',
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
        description:
            'Tempe lebar tepung basah berbumbu daun bawang kucai, disajikan dengan kecap rawit kental.',
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
        description:
            'Adonan sayur kubis, wortel, dan tauge garing di luar lembut di dalam.',
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
        description:
            'Kopi tubruk robusta pekat yang dicelup potongan arang kayu mendidih berdesis. Rendah asam lambung.',
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
        description:
            'Geprekan jahe merah bakar aromatik diseduh air gula kelapa dan susu kental manis pekat.',
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
        description:
            'Seduhan rempah secang merah, cengkeh, kayu manis, pala, dan gula batu kristal asli Imogiri.',
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
        description:
            'Racikan 3 merk teh Jawa legendaris: Legi, Kentel, Sepet, dengan wangi melati alami.',
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
        description:
            'Jeruk peras murni asam manis segar dengan tetesan gula tebu murni.',
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
  Future<int> insertOrder(
    OrderModel order, {
    bool deductStock = true,
    PaymentModel? payment,
  }) async {
    final db = await instance.database;
    return await db.transaction((txn) async {
      // 1. Insert order
      final orderId = await txn.insert('orders', order.toMap());

      // 2. Insert items & deduct stock
      for (final item in order.items) {
        await txn.insert('order_items', {...item.toMap(), 'order_id': orderId});

        // Deduct product stock
        if (deductStock) {
          await txn.rawUpdate(
            '''
            UPDATE products
            SET stock = MAX(0, stock - ?)
            WHERE id = ?
          ''',
            [item.quantity, item.productId],
          );
        }
      }

      if (payment != null) {
        await txn.insert('payments', {...payment.toMap(), 'order_id': orderId});
      }

      return orderId;
    });
  }

  Future<bool> orderExists(String invoiceNumber) async {
    final db = await instance.database;
    final result = await db.query(
      'orders',
      columns: ['id'],
      where: 'invoice_number = ?',
      whereArgs: [invoiceNumber],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  ({String where, List<Object?> args}) _orderFilter({
    int? shiftId,
    DateTime? start,
    DateTime? end,
    bool debtOnly = false,
    String alias = '',
  }) {
    final clauses = <String>[];
    final args = <Object?>[];
    if (shiftId != null) {
      clauses.add('${alias}shift_id = ?');
      args.add(shiftId);
    }
    if (start != null) {
      clauses.add('${alias}created_at >= ?');
      args.add(start.toIso8601String());
    }
    if (end != null) {
      clauses.add('${alias}created_at < ?');
      args.add(end.toIso8601String());
    }
    if (debtOnly) {
      clauses.add('${alias}payment_status = ?');
      args.add(OrderModel.paymentUnpaid);
    }
    return (
      where: clauses.isEmpty ? '' : 'WHERE ${clauses.join(' AND ')}',
      args: args,
    );
  }

  /// [end] is exclusive.
  Future<List<OrderModel>> getOrders({
    int? shiftId,
    DateTime? start,
    DateTime? end,
    bool debtOnly = false,
    bool oldestFirst = false,
    int? limit,
  }) async {
    final db = await instance.database;
    final filter = _orderFilter(
      shiftId: shiftId,
      start: start,
      end: end,
      debtOnly: debtOnly,
    );
    final direction = oldestFirst ? 'ASC' : 'DESC';

    final orderRows = await db.rawQuery(
      'SELECT * FROM orders ${filter.where} '
      'ORDER BY created_at $direction, id $direction'
      '${limit != null ? ' LIMIT $limit' : ''}',
      filter.args,
    );

    if (orderRows.isEmpty) return [];

    final orderIds = orderRows.map((r) => r['id'] as int).toList();
    final itemsByOrderId = <int, List<OrderItem>>{};
    // Stay well below SQLite's bound-parameter limit.
    for (var i = 0; i < orderIds.length; i += 500) {
      final chunk = orderIds.sublist(i, min(i + 500, orderIds.length));
      final placeholders = List.filled(chunk.length, '?').join(',');
      final itemRows = await db.query(
        'order_items',
        where: 'order_id IN ($placeholders)',
        whereArgs: chunk,
      );
      for (final itemRow in itemRows) {
        final item = OrderItem.fromMap(itemRow);
        final oid = item.orderId;
        if (oid != null) {
          (itemsByOrderId[oid] ??= []).add(item);
        }
      }
    }

    return orderRows.map((row) {
      final orderId = row['id'] as int;
      return OrderModel.fromMap(
        row,
        items: itemsByOrderId[orderId] ?? const [],
      );
    }).toList();
  }

  Future<SalesSummary> getSalesSummary({
    int? shiftId,
    DateTime? start,
    DateTime? end,
  }) async {
    final db = await instance.database;
    final filter = _orderFilter(
      shiftId: shiftId,
      start: start,
      end: end,
      alias: 'o.',
    );
    final totals = (await db.rawQuery('''
      SELECT COUNT(*) AS trx,
             COALESCE(SUM(o.final_amount), 0) AS revenue,
             COALESCE(SUM(CASE WHEN o.cost_known = 1 THEN o.final_amount ELSE 0 END), 0) AS known_revenue,
             COALESCE(SUM(CASE WHEN o.cost_known = 0 THEN 1 ELSE 0 END), 0) AS unknown_cost
      FROM orders o ${filter.where}
    ''', filter.args)).first;
    final costWhere = filter.where.isEmpty
        ? 'WHERE o.cost_known = 1'
        : '${filter.where} AND o.cost_known = 1';
    final cost = (await db.rawQuery('''
      SELECT COALESCE(SUM(oi.buy_price * oi.quantity), 0) AS cost
      FROM order_items oi JOIN orders o ON o.id = oi.order_id
      $costWhere
    ''', filter.args)).first;

    return SalesSummary(
      transactionCount: _asInt(totals['trx']),
      revenue: _asDouble(totals['revenue']),
      profit: _asDouble(totals['known_revenue']) - _asDouble(cost['cost']),
      unknownCostCount: _asInt(totals['unknown_cost']),
    );
  }

  Future<double> getOutstandingDebtTotal() async {
    final db = await instance.database;
    final row = (await db.rawQuery(
      'SELECT COALESCE(SUM(final_amount - paid_amount), 0) AS total '
      'FROM orders WHERE payment_status = ?',
      [OrderModel.paymentUnpaid],
    ))
        .first;
    return _asDouble(row['total']);
  }

  /// Records a debt repayment and returns the remaining balance.
  Future<double> addPayment({
    required int orderId,
    required double amount,
    required String method,
    required int? shiftId,
    String? note,
  }) async {
    final db = await instance.database;
    return db.transaction((txn) async {
      final rows = await txn.query(
        'orders',
        columns: ['final_amount', 'paid_amount'],
        where: 'id = ?',
        whereArgs: [orderId],
        limit: 1,
      );
      if (rows.isEmpty) throw StateError('Transaksi tidak ditemukan.');
      final finalAmount = _asDouble(rows.first['final_amount']);
      final paidAmount = _asDouble(rows.first['paid_amount']);
      final outstanding = finalAmount - paidAmount;
      if (outstanding <= 0) throw StateError('Transaksi ini sudah lunas.');
      if (amount <= 0)
        throw StateError('Nominal pembayaran harus lebih dari 0.');
      if (amount > outstanding) {
        throw StateError('Nominal melebihi sisa tagihan.');
      }

      await txn.insert('payments', {
        ...PaymentModel(
          uuid: generateUuid(),
          amount: amount,
          method: method,
          paidAt: DateTime.now(),
          shiftId: shiftId,
          note: note,
        ).toMap(),
        'order_id': orderId,
      });
      final newPaid = paidAmount + amount;
      final remaining = finalAmount - newPaid;
      await txn.update(
        'orders',
        {
          'paid_amount': newPaid,
          'payment_status': remaining <= 0
              ? OrderModel.paymentPaid
              : OrderModel.paymentUnpaid,
        },
        where: 'id = ?',
        whereArgs: [orderId],
      );
      return remaining > 0 ? remaining : 0;
    });
  }

  // --- Key-value settings ---
  Future<Map<String, String>> getAllSettings() async {
    final db = await instance.database;
    final rows = await db.query('app_settings');
    return {
      for (final row in rows) row['key'] as String: row['value'] as String,
    };
  }

  /// A null [value] deletes the key.
  Future<void> setSetting(String key, String? value) async {
    final db = await instance.database;
    if (value == null) {
      await db.delete('app_settings', where: 'key = ?', whereArgs: [key]);
      return;
    }
    await db.insert(
      'app_settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // --- Shifts ---
  Future<ShiftModel?> getOpenShift() async {
    final db = await instance.database;
    final rows = await db.query(
      'shifts',
      where: 'status = ?',
      whereArgs: [ShiftModel.statusOpen],
      orderBy: 'id DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : ShiftModel.fromMap(rows.first);
  }

  Future<ShiftModel?> getLatestShift() async {
    final db = await instance.database;
    final rows = await db.query('shifts', orderBy: 'id DESC', limit: 1);
    return rows.isEmpty ? null : ShiftModel.fromMap(rows.first);
  }

  Future<ShiftModel> openShift({double openingCash = 0}) async {
    final db = await instance.database;
    final shift = ShiftModel(
      uuid: generateUuid(),
      openedAt: DateTime.now(),
      openingCash: openingCash,
    );
    final id = await db.insert('shifts', shift.toMap());
    return ShiftModel.fromMap({...shift.toMap(), 'id': id});
  }

  Future<ShiftModel> updateShiftOpeningCash(int shiftId, double amount) async {
    final db = await instance.database;
    await db.update(
      'shifts',
      {'opening_cash': amount},
      where: 'id = ? AND status = ?',
      whereArgs: [shiftId, ShiftModel.statusOpen],
    );
    final rows =
        await db.query('shifts', where: 'id = ?', whereArgs: [shiftId]);
    return ShiftModel.fromMap(rows.first);
  }

  Future<ShiftModel> closeShift(
    int shiftId, {
    required double countedCash,
    required double expectedCash,
    String? note,
  }) async {
    final db = await instance.database;
    final updated = await db.update(
      'shifts',
      {
        'status': ShiftModel.statusClosed,
        'closed_at': DateTime.now().toIso8601String(),
        'counted_cash': countedCash,
        'expected_cash': expectedCash,
        'note': note,
      },
      where: 'id = ? AND status = ?',
      whereArgs: [shiftId, ShiftModel.statusOpen],
    );
    if (updated == 0) throw StateError('Shift sudah ditutup sebelumnya.');
    final rows =
        await db.query('shifts', where: 'id = ?', whereArgs: [shiftId]);
    return ShiftModel.fromMap(rows.first);
  }

  Future<ShiftSummary> getShiftSummary(ShiftModel shift) async {
    final db = await instance.database;
    final shiftId = shift.id;
    final sales = await getSalesSummary(shiftId: shiftId);

    final newDebt = (await db.rawQuery(
      'SELECT COALESCE(SUM(final_amount), 0) AS total FROM orders '
      'WHERE shift_id = ? AND payment_method = ?',
      [shiftId, AppConstants.paymentDebt],
    ))
        .first;

    final paymentRows = await db.rawQuery(
      'SELECT method, COALESCE(SUM(amount), 0) AS total FROM payments '
      'WHERE shift_id = ? GROUP BY method',
      [shiftId],
    );
    final byMethod = <String, double>{};
    var cashIn = 0.0;
    for (final row in paymentRows) {
      final method = row['method'] as String;
      final total = _asDouble(row['total']);
      final isCash = AppConstants.isCashMethod(method);
      final key = isCash ? AppConstants.paymentCash : method;
      byMethod[key] = (byMethod[key] ?? 0) + total;
      if (isCash) cashIn += total;
    }

    final collected = (await db.rawQuery(
      'SELECT COALESCE(SUM(p.amount), 0) AS total FROM payments p '
      'JOIN orders o ON o.id = p.order_id '
      'WHERE p.shift_id = ? AND o.payment_method = ?',
      [shiftId, AppConstants.paymentDebt],
    ))
        .first;

    return ShiftSummary(
      shift: shift,
      sales: sales,
      newDebt: _asDouble(newDebt['total']),
      debtCollected: _asDouble(collected['total']),
      paymentsByMethod: byMethod,
      cashIn: cashIn,
      outstandingDebt: await getOutstandingDebtTotal(),
    );
  }

  // --- Open bills (held table orders) ---
  Future<Map<String, List<CartItem>>> getHeldOrders() async {
    final db = await instance.database;
    final rows = await db.query('held_orders', orderBy: 'id ASC');
    if (rows.isEmpty) return {};

    final productIds = rows.map((r) => r['product_id'] as int).toSet().toList();
    final placeholders = List.filled(productIds.length, '?').join(',');
    // Includes inactive products so a held bill survives a menu deletion.
    final productRows = await db.query(
      'products',
      where: 'id IN ($placeholders)',
      whereArgs: productIds,
    );
    final products = {
      for (final row in productRows) row['id'] as int: Product.fromMap(row),
    };

    final result = <String, List<CartItem>>{};
    for (final row in rows) {
      final product = products[row['product_id'] as int];
      if (product == null) continue;
      (result[row['table_name'] as String] ??= []).add(
        CartItem(
          product: product,
          quantity: row['quantity'] as int,
          selectedOption: row['selected_option'] as String?,
          note: row['note'] as String?,
        ),
      );
    }
    return result;
  }

  /// Replaces the stored bill for [table]; [removeTable] is deleted in the
  /// same transaction when a bill moves to another table.
  Future<void> replaceHeldOrder(
    String table,
    List<CartItem> items, {
    String? removeTable,
  }) async {
    final db = await instance.database;
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      await txn
          .delete('held_orders', where: 'table_name = ?', whereArgs: [table]);
      if (removeTable != null && removeTable != table) {
        await txn.delete(
          'held_orders',
          where: 'table_name = ?',
          whereArgs: [removeTable],
        );
      }
      for (final item in items) {
        await txn.insert('held_orders', {
          'table_name': table,
          'product_id': item.product.id,
          'selected_option': item.selectedOption,
          'note': item.note,
          'quantity': item.quantity,
          'held_at': now,
        });
      }
    });
  }

  Future<void> deleteHeldOrder(String table) async {
    final db = await instance.database;
    await db.delete('held_orders', where: 'table_name = ?', whereArgs: [table]);
  }

  // --- Backup & restore ---
  Future<Map<String, Object?>> exportBackup() async {
    final db = await instance.database;
    final tables = <String, Object?>{};
    for (final table in backupTables) {
      tables[table] = await db.query(table);
    }
    return {
      'app': 'kedai_abs',
      'schema_version': AppConstants.dbVersion,
      'exported_at': DateTime.now().toIso8601String(),
      'tables': tables,
    };
  }

  /// Replaces all local data with [backup]. Throws [FormatException] when the
  /// file is not a valid Kedai POS backup.
  Future<void> restoreBackup(Map<String, dynamic> backup) async {
    if (backup['app'] != 'kedai_abs') {
      throw const FormatException('File ini bukan cadangan Kedai POS.');
    }
    final version = backup['schema_version'];
    if (version is! int || version > AppConstants.dbVersion) {
      throw const FormatException(
        'Cadangan dibuat oleh versi aplikasi yang lebih baru.',
      );
    }
    final tables = backup['tables'];
    if (tables is! Map<String, dynamic>) {
      throw const FormatException('Isi cadangan tidak lengkap.');
    }
    for (final required in [
      'products',
      'orders',
      'order_items',
      'store_settings'
    ]) {
      if (tables[required] is! List) {
        throw FormatException('Tabel $required tidak ada di cadangan.');
      }
    }

    final db = await instance.database;
    await db.transaction((txn) async {
      for (final table in backupTables.reversed) {
        await txn.delete(table);
      }
      for (final table in backupTables) {
        final rows = tables[table];
        if (rows is! List) continue;
        final columns = (await txn.rawQuery('PRAGMA table_info($table)'))
            .map((c) => c['name'] as String)
            .toSet();
        for (final row in rows) {
          if (row is! Map<String, dynamic>) {
            throw FormatException('Baris tidak valid di tabel $table.');
          }
          await txn.insert(table, {
            for (final entry in row.entries)
              if (columns.contains(entry.key)) entry.key: entry.value,
          });
        }
      }
      if ((await txn.query('store_settings', limit: 1)).isEmpty) {
        await txn
            .insert('store_settings', {'id': 1, ...StoreProfile().toMap()});
      }
      await _backfillV5(txn);
    });
  }

  static double _asDouble(Object? value) => (value as num?)?.toDouble() ?? 0;

  static int _asInt(Object? value) => (value as num?)?.toInt() ?? 0;

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
    return await db.update('store_settings', profile.toMap(), where: 'id = 1');
  }
}
