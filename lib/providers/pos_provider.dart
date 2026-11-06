import 'dart:async';
import 'package:flutter/foundation.dart' hide Category;

import '../core/database/database_helper.dart';
import '../core/services/menu_jajan_api_service.dart';
import '../models/category.dart';
import '../models/product.dart';
import '../models/cart_item.dart';
import '../models/order.dart';
import '../models/store_profile.dart';

class PosProvider extends ChangeNotifier {
  DatabaseHelper _db = DatabaseHelper.instance;
  MenuJajanApiService get _apiService =>
      MenuJajanApiService(baseUrl: _storeProfile.serverUrl);

  // Products & Categories
  List<Product> _allProducts = [];
  List<Product> _products = [];
  List<Category> _categories = [];
  String _selectedCategory = 'Semua';
  String _searchQuery = '';
  bool _isLoading = false;
  bool _isInitialized = false;

  // Table Management
  String _selectedTable = 'Meja 01';
  final Map<String, List<CartItem>> _heldTableOrders = {};

  // Cart: key is unique item signature `${productId}_${selectedOption ?? ''}`
  final Map<String, CartItem> _cart = {};
  double _discountAmount = 0.0;

  // Store & Settings
  StoreProfile _storeProfile = StoreProfile();

  // Reports & History
  List<OrderModel> _orderHistory = [];
  String _reportRange = 'today'; // 'today', '7d', 'month', 'all'
  Map<String, double> _todaySummary = {
    'revenue': 0,
    'profit': 0,
    'transactions': 0,
  };

  // Online Sync / menu-jajan integration
  bool _isOnlineSyncAvailable = false;
  List<BillSummary> _liveBills = [];
  List<dynamic> _liveOnlineOrders = [];
  Timer? _syncTimer;

  // Getters
  List<Product> get allProducts => _allProducts;
  List<Product> get products => _products;
  List<Category> get categories => _categories;
  String get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String get selectedTable => _selectedTable;
  Map<String, List<CartItem>> get heldTableOrders => _heldTableOrders;
  Map<String, CartItem> get cart => _cart;
  List<CartItem> get cartItems => _cart.values.toList();
  StoreProfile get storeProfile => _storeProfile;
  List<OrderModel> get orderHistory => _orderHistory;
  String get reportRange => _reportRange;
  Map<String, double> get todaySummary => _todaySummary;
  double get discountAmount => _discountAmount;
  bool get isOnlineSyncAvailable => _isOnlineSyncAvailable;
  List<BillSummary> get liveBills => _liveBills;
  List<dynamic> get liveOnlineOrders => _liveOnlineOrders;

  int get activeAlertCount {
    final activeOnline = _liveOnlineOrders
        .where((o) =>
            (o['status'] ?? '') != 'selesai' &&
            (o['status'] ?? '') != 'dibatalkan')
        .length;
    return _heldTableOrders.length + _liveBills.length + activeOnline;
  }

  int get cartCount => _cart.values.fold(0, (sum, item) => sum + item.quantity);

  double get cartSubtotal =>
      _cart.values.fold(0.0, (sum, item) => sum + item.subtotal);

  double get cartTotal =>
      (cartSubtotal - _discountAmount).clamp(0.0, double.infinity);

  int getProductCartQuantity(int? productId) {
    if (productId == null) return 0;
    var total = 0;
    for (final item in _cart.values) {
      if (item.product.id == productId) {
        total += item.quantity;
      }
    }
    return total;
  }

  // Initialize
  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    await Future.wait([
      loadStoreProfile(),
      loadCategories(),
      loadProducts(),
      loadTodaySummary(),
      loadOrderHistory(),
    ]);

    _isLoading = false;
    _isInitialized = true;
    notifyListeners();

    unawaited(checkOnlineSync());
    _startAutoSyncTimer();
  }

  void _startAutoSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_isOnlineSyncAvailable) {
        fetchLiveOnlineData();
      }
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  // --- Table Selection ---
  void setSelectedTable(String table) {
    _selectedTable = table;
    notifyListeners();
  }

  // --- Online Sync with menu-jajan server ---
  Future<void> checkOnlineSync() async {
    _isOnlineSyncAvailable = await _apiService.checkConnection();
    if (_isOnlineSyncAvailable) {
      await fetchLiveOnlineData();
    } else {
      _liveBills = [];
      _liveOnlineOrders = [];
    }
    notifyListeners();
  }

  Future<ApiTestResult> testApiConnection([String? customUrl]) async {
    final service = customUrl != null && customUrl.isNotEmpty
        ? MenuJajanApiService(baseUrl: customUrl)
        : _apiService;
    final result = await service.testConnection();
    _isOnlineSyncAvailable = result.isSuccess;
    if (_isOnlineSyncAvailable) {
      await fetchLiveOnlineData();
    }
    notifyListeners();
    return result;
  }

  Future<int> syncMenuFromOnline() async {
    try {
      final liveMenu = await _apiService.getLiveMenu();
      if (liveMenu.isEmpty) return 0;

      int updatedCount = 0;
      for (final item in liveMenu) {
        final nama = item['nama']?.toString();
        if (nama == null) continue;

        final harga = (item['harga'] as num?)?.toDouble() ?? 0.0;
        final tersedia = item['tersedia'] != false;
        final deskripsi = item['deskripsi']?.toString();
        final tagKuliner = item['tagKuliner']?.toString();
        final badgeKhusus = item['badgeKhusus']?.toString();

        List<String> opsiList = [];
        if (item['opsiConfig'] != null &&
            item['opsiConfig']['daftarPilihan'] is List) {
          opsiList = (item['opsiConfig']['daftarPilihan'] as List)
              .map((e) => e.toString())
              .toList();
        }

        // Match existing product by name
        final existingList = await _db.getProducts(query: nama);
        final match = existingList
            .where((p) => p.name.toLowerCase() == nama.toLowerCase())
            .firstOrNull;

        if (match != null) {
          final updated = Product(
            id: match.id,
            name: match.name,
            sku: match.sku,
            category: match.category,
            buyPrice: match.buyPrice,
            sellPrice: harga > 0 ? harga : match.sellPrice,
            stock: tersedia ? (match.stock <= 0 ? 50 : match.stock) : 0,
            tagKuliner: tagKuliner ?? match.tagKuliner,
            badgeKhusus: badgeKhusus ?? match.badgeKhusus,
            description: deskripsi ?? match.description,
            opsiList: opsiList.isNotEmpty ? opsiList : match.opsiList,
          );
          await _db.updateProduct(updated);
          updatedCount++;
        }
      }

      if (updatedCount > 0) {
        await loadProducts();
      }
      return updatedCount;
    } catch (_) {
      return 0;
    }
  }

  Future<void> fetchLiveOnlineData() async {
    try {
      final bills = await _apiService.getLiveBills();
      final orders = await _apiService.getLiveOrders();
      _liveBills = bills;
      _liveOnlineOrders = orders;
      notifyListeners();
    } catch (_) {}
  }

  Future<bool> updateOnlineOrderStatus(String orderId, String newStatus) async {
    final success = await _apiService.updateOrderStatus(orderId, newStatus);
    if (success) {
      await fetchLiveOnlineData();
    }
    return success;
  }

  Future<bool> settleTableBill(String meja) async {
    final normalizedTable = MenuJajanApiService.normalizeMeja(meja);
    final bill = _liveBills
        .where(
          (entry) =>
              MenuJajanApiService.normalizeMeja(entry.nomorMeja) ==
              normalizedTable,
        )
        .firstOrNull;
    final success = await _apiService.settleBill(meja);
    if (success) {
      try {
        if (bill != null) {
          await _recordSettledOnlineBill(bill);
        }
      } catch (_) {
        await fetchLiveOnlineData();
        return false;
      }
      await fetchLiveOnlineData();
    }
    return success;
  }

  Future<void> _recordSettledOnlineBill(BillSummary bill) async {
    final table = MenuJajanApiService.normalizeMeja(bill.nomorMeja);
    final identity = bill.waktuAwal.isNotEmpty
        ? bill.waktuAwal
        : '${bill.totalTagihan}-${bill.jumlahPesanan}';
    final invoice =
        'QR-$table-${identity.replaceAll(RegExp(r'[^A-Za-z0-9]'), '')}';
    if (await _db.orderExists(invoice)) return;

    var costKnown = bill.items.isNotEmpty;
    final items = <OrderItem>[];
    for (final item in bill.items) {
      final matches = await _db.getProducts(query: item.nama);
      final product = matches
          .where((entry) => entry.name.toLowerCase() == item.nama.toLowerCase())
          .firstOrNull;
      if (product == null) costKnown = false;
      items.add(
        OrderItem(
          productId: product?.id ?? 0,
          productName: item.nama,
          unitPrice: item.hargaSatuan,
          buyPrice: product?.buyPrice ?? 0,
          quantity: item.jumlah,
          subtotal: item.subtotal,
          selectedOption: item.opsi,
        ),
      );
    }

    final createdAt = DateTime.tryParse(bill.waktuAwal) ?? DateTime.now();
    final order = OrderModel(
      invoiceNumber: invoice,
      createdAt: createdAt,
      totalAmount: bill.totalTagihan,
      finalAmount: bill.totalTagihan,
      paymentAmount: bill.totalTagihan,
      changeAmount: 0,
      paymentMethod: 'tunai',
      customerName: bill.namaPemesan,
      tableNumber: 'Meja $table',
      costKnown: costKnown,
      items: items,
    );
    await _db.insertOrder(order, deductStock: false);
  }

  // --- Category Actions ---
  Future<void> loadCategories() async {
    _categories = await _db.getCategories();
    notifyListeners();
  }

  void selectCategory(String category) {
    _selectedCategory = category;
    _applyProductFilters();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _applyProductFilters();
  }

  // --- Products Actions ---
  Future<void> loadProducts() async {
    _allProducts = await _db.getProducts();
    _applyProductFilters();
  }

  void _applyProductFilters() {
    final q = _searchQuery.trim().toLowerCase();
    _products = _allProducts.where((p) {
      final matchCat =
          _selectedCategory == 'Semua' || p.category == _selectedCategory;
      if (!matchCat) return false;
      if (q.isEmpty) return true;
      return p.name.toLowerCase().contains(q) ||
          (p.sku != null && p.sku!.toLowerCase().contains(q)) ||
          (p.tagKuliner != null && p.tagKuliner!.toLowerCase().contains(q));
    }).toList();
    notifyListeners();
  }

  Future<void> saveProduct(Product product) async {
    if (product.id == null) {
      await _db.insertProduct(product);
    } else {
      await _db.updateProduct(product);
    }
    await loadProducts();
  }

  Future<void> deleteProduct(int id) async {
    await _db.deleteProduct(id);
    _cart.removeWhere((key, item) => item.product.id == id);
    await loadProducts();
  }

  // --- Cart Actions ---
  void addToCart(Product product, {String? selectedOption, String? note}) {
    if (product.stock <= 0) return;

    final optionKey = selectedOption ?? '';
    final cartKey = '${product.id}_$optionKey';
    final productQuantity = _cart.values
        .where((item) => item.product.id == product.id)
        .fold<int>(0, (total, item) => total + item.quantity);

    if (_cart.containsKey(cartKey)) {
      if (productQuantity < product.stock) {
        _cart[cartKey]!.quantity++;
      }
    } else if (productQuantity < product.stock) {
      _cart[cartKey] = CartItem(
        product: product,
        quantity: 1,
        selectedOption: selectedOption,
        note: note,
      );
    }
    notifyListeners();
  }

  void decreaseQuantity(String cartKey) {
    if (!_cart.containsKey(cartKey)) return;

    if (_cart[cartKey]!.quantity > 1) {
      _cart[cartKey]!.quantity--;
    } else {
      _cart.remove(cartKey);
    }
    notifyListeners();
  }

  void removeFromCart(String cartKey) {
    _cart.remove(cartKey);
    notifyListeners();
  }

  void setDiscount(double amount) {
    _discountAmount = amount;
    notifyListeners();
  }

  void clearCart() {
    _cart.clear();
    _discountAmount = 0.0;
    notifyListeners();
  }

  // --- Local Open Bill (Hold / Resume Table Order) ---
  bool holdCurrentCartToTable([String? table]) {
    if (_cart.isEmpty) return false;
    final target = table ?? _selectedTable;
    final existing = List<CartItem>.from(_heldTableOrders[target] ?? const []);

    for (final cartItem in _cart.values) {
      final idx = existing.indexWhere(
        (e) =>
            e.product.id == cartItem.product.id &&
            (e.selectedOption ?? '') == (cartItem.selectedOption ?? ''),
      );
      if (idx >= 0) {
        final mergedQty = (existing[idx].quantity + cartItem.quantity)
            .clamp(1, cartItem.product.stock);
        existing[idx] = existing[idx].copyWith(quantity: mergedQty);
      } else {
        existing.add(cartItem.copyWith());
      }
    }

    _heldTableOrders[target] = existing;
    _cart.clear();
    _discountAmount = 0.0;
    notifyListeners();
    return true;
  }

  void resumeHeldTableOrder(String table) {
    final held = _heldTableOrders.remove(table);
    if (held == null || held.isEmpty) return;

    _selectedTable = table;
    for (final item in held) {
      final key = '${item.product.id}_${item.selectedOption ?? ''}';
      if (_cart.containsKey(key)) {
        final maxQty = item.product.stock;
        _cart[key]!.quantity =
            (_cart[key]!.quantity + item.quantity).clamp(1, maxQty);
      } else {
        _cart[key] = item.copyWith();
      }
    }
    notifyListeners();
  }

  void deleteHeldTableOrder(String table) {
    _heldTableOrders.remove(table);
    notifyListeners();
  }

  // --- Checkout Action ---
  Future<OrderModel?> checkout({
    required double paymentAmount,
    required String paymentMethod,
    String? customerName,
    String? tableNumber,
  }) async {
    if (_cart.isEmpty) return null;

    final now = DateTime.now();
    final invoiceNumber =
        'INV-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.millisecondsSinceEpoch.toString().substring(8)}';
    final targetTable = tableNumber ?? _selectedTable;

    final items = _cart.values.map((item) {
      return OrderItem(
        productId: item.product.id!,
        productName: item.product.name,
        unitPrice: item.product.sellPrice,
        buyPrice: item.product.buyPrice,
        quantity: item.quantity,
        subtotal: item.subtotal,
        note: item.note,
        selectedOption: item.selectedOption,
      );
    }).toList();

    final changeAmount = (paymentAmount - cartTotal).clamp(
      0.0,
      double.infinity,
    );

    final order = OrderModel(
      invoiceNumber: invoiceNumber,
      createdAt: now,
      totalAmount: cartSubtotal,
      discountAmount: _discountAmount,
      finalAmount: cartTotal,
      paymentAmount: paymentAmount,
      changeAmount: changeAmount,
      paymentMethod: paymentMethod,
      customerName: customerName,
      tableNumber: targetTable,
      status: 'selesai',
      items: items,
    );

    final orderId = await _db.insertOrder(order);
    final createdOrder = OrderModel(
      id: orderId,
      invoiceNumber: order.invoiceNumber,
      createdAt: order.createdAt,
      totalAmount: order.totalAmount,
      discountAmount: order.discountAmount,
      finalAmount: order.finalAmount,
      paymentAmount: order.paymentAmount,
      changeAmount: order.changeAmount,
      paymentMethod: order.paymentMethod,
      customerName: order.customerName,
      tableNumber: targetTable,
      status: 'selesai',
      items: items,
    );

    _heldTableOrders.remove(targetTable);
    clearCart();
    await loadProducts();
    await loadTodaySummary();
    await loadOrderHistory();

    return createdOrder;
  }

  // --- Reports & Summary ---
  void setReportRange(String range) {
    _reportRange = range;
    notifyListeners();
  }

  List<OrderModel> get filteredOrders {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    return _orderHistory.where((o) {
      switch (_reportRange) {
        case 'today':
          return !o.createdAt.isBefore(startOfToday);
        case '7d':
          return !o.createdAt.isBefore(
            startOfToday.subtract(const Duration(days: 6)),
          );
        case 'month':
          return o.createdAt.year == now.year && o.createdAt.month == now.month;
        default:
          return true;
      }
    }).toList();
  }

  Map<String, double> get filteredSummary {
    if (_reportRange == 'today') return _todaySummary;
    final list = filteredOrders;
    double revenue = 0;
    double cost = 0;
    int unknownCost = 0;
    for (final o in list) {
      revenue += o.finalAmount;
      if (!o.costKnown) {
        unknownCost++;
        continue;
      }
      for (final it in o.items) {
        cost += it.buyPrice * it.quantity;
      }
    }
    return {
      'revenue': revenue,
      'profit': revenue - cost,
      'transactions': list.length.toDouble(),
      'unknown_cost_transactions': unknownCost.toDouble(),
    };
  }

  String generateOrdersCsv() {
    final buffer = StringBuffer();
    buffer.writeln(
      'Invoice,Tanggal,Meja,Pelanggan,Metode Bayar,Total,Diskon,Bayar Akhir,Status HPP',
    );
    for (final o in filteredOrders) {
      final customer = (o.customerName ?? '-').replaceAll(',', ' ');
      final table = (o.tableNumber ?? '-').replaceAll(',', ' ');
      final hppStatus = o.costKnown ? 'Tercatat' : 'Belum Tercatat';
      buffer.writeln(
        '${o.invoiceNumber},${o.createdAt.toIso8601String()},$table,$customer,${o.paymentMethod},${o.totalAmount.toInt()},${o.discountAmount.toInt()},${o.finalAmount.toInt()},$hppStatus',
      );
    }
    return buffer.toString();
  }

  Future<void> loadTodaySummary() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day, 0, 0, 0);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    _todaySummary = await _db.getSummary(startOfDay, endOfDay);
    notifyListeners();
  }

  Future<void> loadOrderHistory() async {
    _orderHistory = await _db.getOrders();
    notifyListeners();
  }

  // --- Store Profile ---
  Future<void> loadStoreProfile() async {
    _storeProfile = await _db.getStoreProfile();
    notifyListeners();
  }

  Future<void> updateStoreProfile(StoreProfile profile) async {
    await _db.saveStoreProfile(profile);
    _storeProfile = profile;
    await checkOnlineSync();
    notifyListeners();
  }
}
