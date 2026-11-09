import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' hide Category;

import '../core/constants/app_constants.dart';
import '../core/database/database_helper.dart';
import '../core/services/menu_jajan_api_service.dart';
import '../core/services/printer_service.dart';
import '../core/utils/id_generator.dart';
import '../models/cart_item.dart';
import '../models/category.dart';
import '../models/order.dart';
import '../models/payment.dart';
import '../models/payment_settings.dart';
import '../models/product.dart';
import '../models/shift.dart';
import '../models/store_profile.dart';

class PosProvider extends ChangeNotifier {
  static const int historyLimit = 200;
  static const Map<String, String> reportRanges = {
    'shift': 'Shift Ini',
    'today': 'Hari Ini',
    '7d': '7 Hari',
    'month': 'Bulan Ini',
    'all': 'Semua',
  };

  final DatabaseHelper _db = DatabaseHelper.instance;
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

  /// Open bill currently loaded into the cart. Its stored rows stay in the
  /// database until the bill is paid, so a crash cannot lose it.
  String? _resumedTable;

  // Cart: key is unique item signature `${productId}_${selectedOption ?? ''}`
  final Map<String, CartItem> _cart = {};
  double _discountAmount = 0.0;

  // Store & Settings
  StoreProfile _storeProfile = StoreProfile();

  // Shift, reports & debts
  ShiftModel? _currentShift;
  String _reportRange = 'shift';
  SalesSummary _reportSummary = const SalesSummary.empty();
  List<OrderModel> _reportOrders = [];
  bool _reportHasMore = false;
  double _outstandingDebt = 0;
  List<OrderModel> _debtOrders = [];

  // Payment & printer settings
  static const String _paymentSettingsKey = 'payment_settings';
  static const String _printerSettingsKey = 'printer_settings';
  static const String _qrisImageKey = 'qris_image';

  /// Keeps the settings row below Android's 2 MB cursor window.
  static const int maxQrisImageBytes = 1024 * 1024;
  PaymentSettings _paymentSettings = const PaymentSettings();
  PrinterSettings _printerSettings = const PrinterSettings();
  Uint8List? _qrisImage;

  // Online Sync / menu-jajan integration
  bool _isOnlineSyncAvailable = false;
  List<BillSummary> _liveBills = [];
  List<dynamic> _liveOnlineOrders = [];
  String? _liveDataSignature;
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
  String? get resumedTable => _resumedTable;
  Map<String, CartItem> get cart => _cart;
  List<CartItem> get cartItems => _cart.values.toList();
  StoreProfile get storeProfile => _storeProfile;
  ShiftModel? get currentShift => _currentShift;
  String get reportRange => _reportRange;
  SalesSummary get reportSummary => _reportSummary;
  List<OrderModel> get reportOrders => _reportOrders;
  bool get reportHasMore => _reportHasMore;
  double get outstandingDebt => _outstandingDebt;
  List<OrderModel> get debtOrders => _debtOrders;
  double get discountAmount => _discountAmount;
  bool get isOnlineSyncAvailable => _isOnlineSyncAvailable;
  PaymentSettings get paymentSettings => _paymentSettings;
  PrinterSettings get printerSettings => _printerSettings;
  Uint8List? get qrisImage => _qrisImage;

  List<String> get enabledPaymentMethods => [
        AppConstants.paymentCash,
        if (_paymentSettings.qrisEnabled) AppConstants.paymentQris,
        if (_paymentSettings.transferEnabled) AppConstants.paymentTransfer,
        if (_paymentSettings.debtEnabled) AppConstants.paymentDebt,
      ];

  /// Methods for settling debts; always includes cash.
  List<String> get enabledSettlementMethods => enabledPaymentMethods
      .where((method) => method != AppConstants.paymentDebt)
      .toList();
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

    await loadLocalData();

    _isLoading = false;
    _isInitialized = true;
    notifyListeners();

    unawaited(checkOnlineSync());
    _startAutoSyncTimer();
  }

  /// Loads everything stored on the device; no network access.
  Future<void> loadLocalData() async {
    await loadStoreProfile();
    await loadAppSettings();
    await loadCategories();
    await loadProducts();
    await _reloadHeldOrders();
    _currentShift = await _db.getOpenShift();
    await loadReports();
    await loadDebts();
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
      _liveDataSignature = null;
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
      // Polling runs every 15 s; skip rebuilds when nothing changed.
      final signature = jsonEncode([
        for (final bill in bills)
          [
            bill.nomorMeja,
            bill.totalTagihan,
            bill.jumlahPesanan,
            bill.items.length
          ],
        orders,
      ]);
      if (signature == _liveDataSignature) return;
      _liveDataSignature = signature;
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

  /// QR orders live on the server; the device keeps one local copy, keyed by
  /// its invoice, so the closing report includes the cash received for it.
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

    final shift = await _ensureOpenShift();
    final now = DateTime.now();
    // Server timestamps are UTC; stored dates must be local for range queries.
    final createdAt = DateTime.tryParse(bill.waktuAwal)?.toLocal() ?? now;
    final order = OrderModel(
      uuid: generateUuid(),
      invoiceNumber: invoice,
      createdAt: createdAt,
      totalAmount: bill.totalTagihan,
      finalAmount: bill.totalTagihan,
      paymentAmount: bill.totalTagihan,
      changeAmount: 0,
      paymentMethod: AppConstants.paymentCash,
      customerName: bill.namaPemesan,
      tableNumber: 'Meja $table',
      costKnown: costKnown,
      shiftId: shift.id,
      source: OrderModel.sourceQr,
      items: items,
    );
    final payment = bill.totalTagihan > 0
        ? PaymentModel(
            uuid: generateUuid(),
            amount: bill.totalTagihan,
            method: AppConstants.paymentCash,
            paidAt: now,
            shiftId: shift.id,
          )
        : null;
    // Unmatched items carry productId 0, so no stock row is touched for them.
    await _db.insertOrder(order, payment: payment);
    await loadProducts();
    await loadReports();
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
    _returnResumedBillIfCartEmpty();
    notifyListeners();
  }

  void removeFromCart(String cartKey) {
    _cart.remove(cartKey);
    _returnResumedBillIfCartEmpty();
    notifyListeners();
  }

  void setDiscount(double amount) {
    _discountAmount = amount;
    notifyListeners();
  }

  /// Empties the cart. A resumed open bill goes back to the table list
  /// unchanged; delete it from the table screen to discard it.
  void clearCart() {
    final hadResumedBill = _resumedTable != null;
    _resetCart();
    _resumedTable = null;
    if (hadResumedBill) unawaited(_reloadHeldOrders());
    notifyListeners();
  }

  void _returnResumedBillIfCartEmpty() {
    if (_cart.isEmpty && _resumedTable != null) {
      _resumedTable = null;
      _discountAmount = 0.0;
      unawaited(_reloadHeldOrders());
    }
  }

  void _resetCart() {
    _cart.clear();
    _discountAmount = 0.0;
  }

  // --- Local Open Bill (Hold / Resume Table Order) ---
  Future<void> _reloadHeldOrders() async {
    final held = await _db.getHeldOrders();
    final resumed = _resumedTable;
    if (resumed != null) held.remove(resumed);
    _heldTableOrders
      ..clear()
      ..addAll(held);
    notifyListeners();
  }

  Future<bool> holdCurrentCartToTable([String? table]) async {
    if (_cart.isEmpty) return false;
    final target = table ?? _selectedTable;
    final resumed = _resumedTable;

    final List<CartItem> items;
    if (resumed == target) {
      // The cart already contains this table's stored bill.
      items = _cart.values.map((item) => item.copyWith()).toList();
    } else {
      items = List<CartItem>.from(
        (_heldTableOrders[target] ?? const []).map((item) => item.copyWith()),
      );
      for (final cartItem in _cart.values) {
        final idx = items.indexWhere(
          (e) =>
              e.product.id == cartItem.product.id &&
              (e.selectedOption ?? '') == (cartItem.selectedOption ?? ''),
        );
        if (idx >= 0) {
          items[idx] = items[idx].copyWith(
            quantity: items[idx].quantity + cartItem.quantity,
          );
        } else {
          items.add(cartItem.copyWith());
        }
      }
    }

    await _db.replaceHeldOrder(target, items, removeTable: resumed);
    _heldTableOrders[target] = items;
    if (resumed != null && resumed != target) {
      _heldTableOrders.remove(resumed);
    }
    _resumedTable = null;
    _resetCart();
    notifyListeners();
    return true;
  }

  /// Loads a stored bill into an empty cart. Returns false when the cart is
  /// not empty, so two bills are never mixed by accident.
  bool resumeHeldTableOrder(String table) {
    if (_cart.isNotEmpty) return false;
    final held = _heldTableOrders.remove(table);
    if (held == null || held.isEmpty) return false;

    _selectedTable = table;
    _resumedTable = table;
    for (final item in held) {
      final key = '${item.product.id}_${item.selectedOption ?? ''}';
      _cart[key] = item.copyWith();
    }
    notifyListeners();
    return true;
  }

  Future<void> deleteHeldTableOrder(String table) async {
    await _db.deleteHeldOrder(table);
    _heldTableOrders.remove(table);
    notifyListeners();
  }

  // --- Checkout Action ---
  Future<OrderModel?> checkout({
    required double paymentAmount,
    required String paymentMethod,
    String? customerName,
    String? customerPhone,
    String? tableNumber,
    String? paymentNote,
  }) async {
    if (_cart.isEmpty) return null;
    final isDebt = paymentMethod == AppConstants.paymentDebt;
    if (isDebt && (customerName == null || customerName.trim().isEmpty)) {
      throw ArgumentError('Nama pelanggan wajib diisi untuk kasbon.');
    }
    final note = isDebt || paymentNote == null || paymentNote.trim().isEmpty
        ? null
        : paymentNote.trim();

    final shift = await _ensureOpenShift();
    final now = DateTime.now();
    final total = cartTotal;
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

    final order = OrderModel(
      uuid: generateUuid(),
      invoiceNumber: _newInvoiceNumber(now),
      createdAt: now,
      totalAmount: cartSubtotal,
      discountAmount: _discountAmount,
      finalAmount: total,
      paymentAmount: isDebt ? 0 : paymentAmount,
      changeAmount:
          isDebt ? 0 : (paymentAmount - total).clamp(0.0, double.infinity),
      paymentMethod: paymentMethod,
      paymentNote: note,
      customerName: customerName,
      customerPhone: customerPhone,
      tableNumber: targetTable,
      status: 'selesai',
      shiftId: shift.id,
      source: OrderModel.sourcePos,
      paymentStatus: isDebt ? OrderModel.paymentUnpaid : OrderModel.paymentPaid,
      paidAmount: isDebt ? 0 : total,
      items: items,
    );
    final payment = !isDebt && total > 0
        ? PaymentModel(
            uuid: generateUuid(),
            amount: total,
            method: paymentMethod,
            paidAt: now,
            shiftId: shift.id,
            note: note,
          )
        : null;

    final orderId = await _db.insertOrder(order, payment: payment);

    final resumed = _resumedTable;
    if (resumed != null) {
      await _db.deleteHeldOrder(resumed);
      _resumedTable = null;
    }
    _resetCart();
    notifyListeners();

    await loadProducts();
    await loadReports();
    if (isDebt) await loadDebts();

    return order.withId(orderId);
  }

  /// Unique per device: timestamp to the second plus a random suffix.
  String _newInvoiceNumber(DateTime now) {
    String two(int v) => v.toString().padLeft(2, '0');
    final suffix = generateUuid().substring(0, 4).toUpperCase();
    return 'INV-${now.year}${two(now.month)}${two(now.day)}-'
        '${two(now.hour)}${two(now.minute)}${two(now.second)}-$suffix';
  }

  // --- Debts (kasbon) ---
  Future<void> loadDebts() async {
    _debtOrders = await _db.getOrders(debtOnly: true, oldestFirst: true);
    _outstandingDebt = await _db.getOutstandingDebtTotal();
    notifyListeners();
  }

  /// Returns an error message, or null on success. The repayment is counted
  /// as money received in the current shift, never as a new sale.
  Future<String?> receiveDebtPayment(
    OrderModel order,
    double amount,
    String method, {
    String? note,
  }) async {
    final orderId = order.id;
    if (orderId == null) return 'Transaksi tidak valid.';
    final shift = await _ensureOpenShift();
    try {
      await _db.addPayment(
        orderId: orderId,
        amount: amount,
        method: method,
        shiftId: shift.id,
        note: note == null || note.trim().isEmpty ? null : note.trim(),
      );
    } on StateError catch (e) {
      return e.message;
    }
    await loadDebts();
    await loadReports();
    return null;
  }

  // --- Shift & closing ---
  Future<ShiftModel> _ensureOpenShift() async {
    final existing = _currentShift ?? await _db.getOpenShift();
    if (existing != null) {
      _currentShift = existing;
      return existing;
    }
    _currentShift = await _db.openShift();
    notifyListeners();
    return _currentShift!;
  }

  Future<void> setOpeningCash(double amount) async {
    final shift = await _ensureOpenShift();
    _currentShift = await _db.updateShiftOpeningCash(shift.id!, amount);
    notifyListeners();
  }

  Future<ShiftSummary?> loadCurrentShiftSummary() async {
    final shift = _currentShift ?? await _db.getOpenShift();
    _currentShift = shift;
    if (shift == null) return null;
    return _db.getShiftSummary(shift);
  }

  String? get closingBlocker {
    if (_heldTableOrders.isNotEmpty || _resumedTable != null) {
      return 'Masih ada open bill meja. Lunasi dulu (bisa sebagai kasbon) '
          'atau hapus dari tab Meja sebelum tutup kasir.';
    }
    if (_cart.isNotEmpty) {
      return 'Keranjang kasir masih berisi pesanan. Selesaikan pembayaran '
          'atau kosongkan keranjang sebelum tutup kasir.';
    }
    return null;
  }

  /// Locks the current shift. Later sales and repayments go to a new shift.
  Future<ShiftSummary> closeCurrentShift({
    required double countedCash,
    String? note,
  }) async {
    final blocker = closingBlocker;
    if (blocker != null) throw StateError(blocker);
    final shift = _currentShift ?? await _db.getOpenShift();
    if (shift == null) {
      throw StateError('Belum ada shift kasir yang berjalan.');
    }
    final summary = await _db.getShiftSummary(shift);
    final closed = await _db.closeShift(
      shift.id!,
      countedCash: countedCash,
      expectedCash: summary.expectedCash,
      note: note,
    );
    _currentShift = null;
    await loadReports();
    return ShiftSummary(
      shift: closed,
      sales: summary.sales,
      newDebt: summary.newDebt,
      debtCollected: summary.debtCollected,
      paymentsByMethod: summary.paymentsByMethod,
      cashIn: summary.cashIn,
      outstandingDebt: summary.outstandingDebt,
    );
  }

  // --- Payment & printer settings ---
  Future<void> loadAppSettings() async {
    final settings = await _db.getAllSettings();
    _paymentSettings = PaymentSettings.decode(settings[_paymentSettingsKey]);
    _printerSettings = PrinterSettings.decode(settings[_printerSettingsKey]);
    final qris = settings[_qrisImageKey];
    try {
      _qrisImage = qris == null ? null : base64Decode(qris);
    } on FormatException {
      _qrisImage = null;
    }
    notifyListeners();
  }

  Future<void> savePaymentSettings(PaymentSettings settings) async {
    await _db.setSetting(_paymentSettingsKey, settings.encode());
    _paymentSettings = settings;
    notifyListeners();
  }

  Future<void> savePrinterSettings(PrinterSettings settings) async {
    await _db.setSetting(_printerSettingsKey, settings.encode());
    if (settings.address != _printerSettings.address) {
      unawaited(PrinterService.instance.disconnect());
    }
    _printerSettings = settings;
    notifyListeners();
  }

  /// Stores the QRIS image shown at checkout; null removes it. Returns an
  /// error message when the image is too large.
  Future<String?> saveQrisImage(Uint8List? bytes) async {
    if (bytes != null && bytes.length > maxQrisImageBytes) {
      return 'Gambar QRIS terlalu besar (maks 1 MB). Pilih gambar yang lebih kecil.';
    }
    await _db.setSetting(
      _qrisImageKey,
      bytes == null ? null : base64Encode(bytes),
    );
    _qrisImage = bytes;
    notifyListeners();
    return null;
  }

  // --- Printing ---
  Future<List<BluetoothPrinterDevice>> pairedPrinters() =>
      PrinterService.instance.pairedPrinters();

  Future<String?> _runPrint(Future<void> Function() job) async {
    try {
      await job();
      return null;
    } on PrinterException catch (e) {
      return e.message;
    }
  }

  /// Prints a receipt (reprints never open the cash drawer).
  Future<String?> printReceipt(OrderModel order, {int? copies}) {
    return _runPrint(
      () => PrinterService.instance.printLines(
        PrinterService.instance
            .buildReceipt(order: order, store: _storeProfile),
        _printerSettings,
        copies: copies,
      ),
    );
  }

  /// Auto-print and cash-drawer handling right after a sale. Returns null
  /// when nothing failed (including when nothing was configured).
  Future<String?> handleCompletedSale(OrderModel order) async {
    final settings = _printerSettings;
    if (!settings.isConfigured) return null;
    final kickDrawer = settings.openCashDrawer &&
        AppConstants.isCashMethod(order.paymentMethod);
    if (settings.autoPrint) {
      return _runPrint(
        () => PrinterService.instance.printLines(
          PrinterService.instance
              .buildReceipt(order: order, store: _storeProfile),
          settings,
          openDrawer: kickDrawer,
        ),
      );
    }
    if (kickDrawer) {
      return _runPrint(
        () => PrinterService.instance.sendBytes(
          settings.address!,
          PrinterService.instance.drawerKickBytes(),
        ),
      );
    }
    return null;
  }

  Future<String?> printDocument(String title, List<String> body) {
    return _runPrint(
      () => PrinterService.instance.printLines(
        PrinterService.instance.buildDocument(
          title: title,
          body: body,
          paperWidth: _storeProfile.paperWidth,
        ),
        _printerSettings,
        copies: 1,
      ),
    );
  }

  Future<String?> printTestPage() {
    return _runPrint(
      () => PrinterService.instance.printLines(
        PrinterService.instance.buildTestPage(_storeProfile),
        _printerSettings,
        copies: 1,
      ),
    );
  }

  // --- Backup & restore ---
  Future<String> exportBackupJson() async {
    return jsonEncode(await _db.exportBackup());
  }

  Future<void> restoreBackupJson(String raw) async {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw const FormatException('File cadangan rusak atau bukan JSON.');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('File ini bukan cadangan Kedai POS.');
    }
    await _db.restoreBackup(decoded);
    _resetCart();
    _resumedTable = null;
    _currentShift = null;
    await loadLocalData();
  }

  // --- Reports & Summary ---
  Future<void> setReportRange(String range) async {
    if (!reportRanges.containsKey(range)) return;
    _reportRange = range;
    notifyListeners();
    await loadReports();
  }

  Future<({int? shiftId, DateTime? start, DateTime? end})>
      _resolveReportRange() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    switch (_reportRange) {
      case 'shift':
        final shift = _currentShift ?? await _db.getLatestShift();
        // -1 matches nothing when no shift exists yet.
        return (shiftId: shift?.id ?? -1, start: null, end: null);
      case 'today':
        return (shiftId: null, start: today, end: tomorrow);
      case '7d':
        return (
          shiftId: null,
          start: DateTime(now.year, now.month, now.day - 6),
          end: tomorrow,
        );
      case 'month':
        return (
          shiftId: null,
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month + 1, 1),
        );
      default:
        return (shiftId: null, start: null, end: null);
    }
  }

  Future<void> loadReports() async {
    final range = await _resolveReportRange();
    _reportSummary = await _db.getSalesSummary(
      shiftId: range.shiftId,
      start: range.start,
      end: range.end,
    );
    final orders = await _db.getOrders(
      shiftId: range.shiftId,
      start: range.start,
      end: range.end,
      limit: historyLimit + 1,
    );
    _reportHasMore = orders.length > historyLimit;
    _reportOrders = _reportHasMore ? orders.sublist(0, historyLimit) : orders;
    _outstandingDebt = await _db.getOutstandingDebtTotal();
    notifyListeners();
  }

  Future<String> generateOrdersCsv() async {
    final range = await _resolveReportRange();
    final orders = await _db.getOrders(
      shiftId: range.shiftId,
      start: range.start,
      end: range.end,
    );
    final buffer = StringBuffer()
      ..writeln(
        'Invoice,Tanggal,Meja,Pelanggan,Sumber,Metode Bayar,Catatan Bayar,'
        'Total,Diskon,Bayar Akhir,Sudah Dibayar,Sisa,Status Bayar,Status HPP',
      );
    for (final o in orders) {
      buffer.writeln([
        o.invoiceNumber,
        o.createdAt.toIso8601String(),
        o.tableNumber ?? '-',
        o.customerName ?? '-',
        o.source,
        o.paymentMethod,
        o.paymentNote ?? '-',
        o.totalAmount.round(),
        o.discountAmount.round(),
        o.finalAmount.round(),
        o.paidAmount.round(),
        o.outstandingAmount.round(),
        o.isDebt ? 'Belum Lunas' : 'Lunas',
        o.costKnown ? 'Tercatat' : 'Belum Tercatat',
      ].map(_csvField).join(','));
    }
    return buffer.toString();
  }

  static String _csvField(Object value) {
    final text = value.toString();
    if (text.contains(RegExp(r'[",\n\r]'))) {
      return '"${text.replaceAll('"', '""')}"';
    }
    return text;
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
