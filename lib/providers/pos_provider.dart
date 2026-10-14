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
  MenuJajanApiService get _apiService => MenuJajanApiService(baseUrl: _storeProfile.serverUrl);

  // Products & Categories
  List<Product> _products = [];
  List<Category> _categories = [];
  String _selectedCategory = 'Semua';
  String _searchQuery = '';
  bool _isLoading = false;

  // Table Management
  String _selectedTable = 'Meja 01';

  // Cart: key is unique item signature `${productId}_${selectedOption ?? ''}`
  final Map<String, CartItem> _cart = {};
  double _discountAmount = 0.0;

  // Store & Settings
  StoreProfile _storeProfile = StoreProfile();

  // Reports & History
  List<OrderModel> _orderHistory = [];
  Map<String, double> _todaySummary = {'revenue': 0, 'profit': 0, 'transactions': 0};

  // Online Sync / menu-jajan integration
  bool _isOnlineSyncAvailable = false;
  List<BillSummary> _liveBills = [];
  List<dynamic> _liveOnlineOrders = [];

  // Getters
  List<Product> get products => _products;
  List<Category> get categories => _categories;
  String get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;
  String get selectedTable => _selectedTable;
  Map<String, CartItem> get cart => _cart;
  List<CartItem> get cartItems => _cart.values.toList();
  StoreProfile get storeProfile => _storeProfile;
  List<OrderModel> get orderHistory => _orderHistory;
  Map<String, double> get todaySummary => _todaySummary;
  double get discountAmount => _discountAmount;
  bool get isOnlineSyncAvailable => _isOnlineSyncAvailable;
  List<BillSummary> get liveBills => _liveBills;
  List<dynamic> get liveOnlineOrders => _liveOnlineOrders;

  int get cartCount => _cart.values.fold(0, (sum, item) => sum + item.quantity);

  double get cartSubtotal =>
      _cart.values.fold(0.0, (sum, item) => sum + item.subtotal);

  double get cartTotal => (cartSubtotal - _discountAmount).clamp(0.0, double.infinity);

  // Initialize
  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    await loadStoreProfile();
    await loadCategories();
    await loadProducts();
    await loadTodaySummary();
    await loadOrderHistory();
    await checkOnlineSync();

    _isLoading = false;
    notifyListeners();
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
        if (item['opsiConfig'] != null && item['opsiConfig']['daftarPilihan'] is List) {
          opsiList = (item['opsiConfig']['daftarPilihan'] as List)
              .map((e) => e.toString())
              .toList();
        }

        // Match existing product by name
        final existingList = await _db.getProducts(query: nama);
        final match = existingList.where((p) => p.name.toLowerCase() == nama.toLowerCase()).firstOrNull;

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
    final success = await _apiService.settleBill(meja);
    if (success) {
      await fetchLiveOnlineData();
    }
    return success;
  }

  // --- Category Actions ---
  Future<void> loadCategories() async {
    _categories = await _db.getCategories();
    notifyListeners();
  }

  void selectCategory(String category) {
    _selectedCategory = category;
    loadProducts();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    loadProducts();
  }

  // --- Products Actions ---
  Future<void> loadProducts() async {
    _products = await _db.getProducts(
      category: _selectedCategory,
      query: _searchQuery,
    );
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

    if (_cart.containsKey(cartKey)) {
      final currentQty = _cart[cartKey]!.quantity;
      if (currentQty < product.stock) {
        _cart[cartKey]!.quantity++;
      }
    } else {
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

  // --- Checkout Action ---
  Future<OrderModel?> checkout({
    required double paymentAmount,
    required String paymentMethod,
    String? customerName,
    String? tableNumber,
  }) async {
    if (_cart.isEmpty) return null;

    final now = DateTime.now();
    final invoiceNumber = 'INV-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.millisecondsSinceEpoch.toString().substring(8)}';
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

    final changeAmount = (paymentAmount - cartTotal).clamp(0.0, double.infinity);

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

    clearCart();
    await loadProducts();
    await loadTodaySummary();
    await loadOrderHistory();

    // If online sync active and meja settled, notify API
    if (_isOnlineSyncAvailable && targetTable.isNotEmpty) {
      settleTableBill(targetTable);
    }

    return createdOrder;
  }

  // --- Reports & Summary ---
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
