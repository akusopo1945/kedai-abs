import 'package:flutter/foundation.dart' hide Category;
import '../core/database/database_helper.dart';
import '../models/category.dart';
import '../models/product.dart';
import '../models/cart_item.dart';
import '../models/order.dart';
import '../models/store_profile.dart';

class PosProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;

  // Products & Categories
  List<Product> _products = [];
  List<Category> _categories = [];
  String _selectedCategory = 'Semua';
  String _searchQuery = '';
  bool _isLoading = false;

  // Cart
  final Map<int, CartItem> _cart = {};
  double _discountAmount = 0.0;

  // Store & Settings
  StoreProfile _storeProfile = StoreProfile();

  // Reports & History
  List<OrderModel> _orderHistory = [];
  Map<String, double> _todaySummary = {'revenue': 0, 'profit': 0, 'transactions': 0};

  // Getters
  List<Product> get products => _products;
  List<Category> get categories => _categories;
  String get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;
  Map<int, CartItem> get cart => _cart;
  List<CartItem> get cartItems => _cart.values.toList();
  StoreProfile get storeProfile => _storeProfile;
  List<OrderModel> get orderHistory => _orderHistory;
  Map<String, double> get todaySummary => _todaySummary;
  double get discountAmount => _discountAmount;

  int get cartCount => _cart.values.fold(0, (sum, item) => sum + item.quantity);

  double get cartSubtotal =>
      _cart.values.fold(0.0, (sum, item) => sum + item.subtotal);

  double get cartTotal => (cartSubtotal - _discountAmount).clamp(0.0, double.infinity);

  // Initialize
  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    await loadCategories();
    await loadProducts();
    await loadStoreProfile();
    await loadTodaySummary();
    await loadOrderHistory();

    _isLoading = false;
    notifyListeners();
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
    _cart.remove(id);
    await loadProducts();
  }

  // --- Cart Actions ---
  void addToCart(Product product) {
    if (product.stock <= 0) return;

    if (_cart.containsKey(product.id)) {
      final currentQty = _cart[product.id]!.quantity;
      if (currentQty < product.stock) {
        _cart[product.id]!.quantity++;
      }
    } else {
      _cart[product.id!] = CartItem(product: product, quantity: 1);
    }
    notifyListeners();
  }

  void decreaseQuantity(int productId) {
    if (!_cart.containsKey(productId)) return;

    if (_cart[productId]!.quantity > 1) {
      _cart[productId]!.quantity--;
    } else {
      _cart.remove(productId);
    }
    notifyListeners();
  }

  void removeFromCart(int productId) {
    _cart.remove(productId);
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
  }) async {
    if (_cart.isEmpty) return null;

    final now = DateTime.now();
    final invoiceNumber = 'INV-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.millisecondsSinceEpoch.toString().substring(8)}';

    final items = _cart.values.map((item) {
      return OrderItem(
        productId: item.product.id!,
        productName: item.product.name,
        unitPrice: item.product.sellPrice,
        buyPrice: item.product.buyPrice,
        quantity: item.quantity,
        subtotal: item.subtotal,
        note: item.note,
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
      items: items,
    );

    clearCart();
    await loadProducts();
    await loadTodaySummary();
    await loadOrderHistory();

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
    notifyListeners();
  }
}
