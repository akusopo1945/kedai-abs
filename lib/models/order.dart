class OrderItem {
  final int? id;
  final int? orderId;
  final int productId;
  final String productName;
  final double unitPrice;
  final double buyPrice;
  final int quantity;
  final double subtotal;
  final String? note;
  final String? selectedOption;

  OrderItem({
    this.id,
    this.orderId,
    required this.productId,
    required this.productName,
    required this.unitPrice,
    required this.buyPrice,
    required this.quantity,
    required this.subtotal,
    this.note,
    this.selectedOption,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'order_id': orderId,
      'product_id': productId,
      'product_name': productName,
      'unit_price': unitPrice,
      'buy_price': buyPrice,
      'quantity': quantity,
      'subtotal': subtotal,
      'note': note,
      'selected_option': selectedOption,
    };
  }

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      id: map['id'] as int?,
      orderId: map['order_id'] as int?,
      productId: map['product_id'] as int,
      productName: map['product_name'] as String,
      unitPrice: (map['unit_price'] as num).toDouble(),
      buyPrice: (map['buy_price'] as num).toDouble(),
      quantity: map['quantity'] as int,
      subtotal: (map['subtotal'] as num).toDouble(),
      note: map['note'] as String?,
      selectedOption: map['selected_option'] as String?,
    );
  }
}

class OrderModel {
  static const String paymentPaid = 'lunas';
  static const String paymentUnpaid = 'belum_lunas';
  static const String sourcePos = 'pos';
  static const String sourceQr = 'qr';

  final int? id;
  final String? uuid;
  final String invoiceNumber;
  final DateTime createdAt;
  final double totalAmount;
  final double discountAmount;
  final double finalAmount;

  /// Cash handed over at checkout (can exceed [finalAmount] for change).
  final double paymentAmount;
  final double changeAmount;
  final String paymentMethod; // 'Tunai', 'QRIS', 'Transfer', 'Kasbon'
  final String? customerName;
  final String? customerPhone;
  final String? tableNumber;
  final String status; // 'pending', 'selesai', 'dibatalkan'
  final bool costKnown;
  final int? shiftId;
  final String source;
  final String paymentStatus;

  /// Sum of recorded payments applied to this order.
  final double paidAmount;
  final List<OrderItem> items;

  OrderModel({
    this.id,
    this.uuid,
    required this.invoiceNumber,
    required this.createdAt,
    required this.totalAmount,
    this.discountAmount = 0.0,
    required this.finalAmount,
    required this.paymentAmount,
    required this.changeAmount,
    required this.paymentMethod,
    this.customerName,
    this.customerPhone,
    this.tableNumber,
    this.status = 'selesai',
    this.costKnown = true,
    this.shiftId,
    this.source = sourcePos,
    this.paymentStatus = paymentPaid,
    double? paidAmount,
    this.items = const [],
  }) : paidAmount =
            paidAmount ?? (paymentStatus == paymentPaid ? finalAmount : 0);

  bool get isDebt => paymentStatus == paymentUnpaid;

  double get outstandingAmount {
    final remaining = finalAmount - paidAmount;
    return remaining > 0 ? remaining : 0;
  }

  OrderModel withId(int newId) {
    return OrderModel(
      id: newId,
      uuid: uuid,
      invoiceNumber: invoiceNumber,
      createdAt: createdAt,
      totalAmount: totalAmount,
      discountAmount: discountAmount,
      finalAmount: finalAmount,
      paymentAmount: paymentAmount,
      changeAmount: changeAmount,
      paymentMethod: paymentMethod,
      customerName: customerName,
      customerPhone: customerPhone,
      tableNumber: tableNumber,
      status: status,
      costKnown: costKnown,
      shiftId: shiftId,
      source: source,
      paymentStatus: paymentStatus,
      paidAmount: paidAmount,
      items: items,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'uuid': uuid,
      'invoice_number': invoiceNumber,
      'created_at': createdAt.toIso8601String(),
      'total_amount': totalAmount,
      'discount_amount': discountAmount,
      'final_amount': finalAmount,
      'payment_amount': paymentAmount,
      'change_amount': changeAmount,
      'payment_method': paymentMethod,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'table_number': tableNumber,
      'status': status,
      'cost_known': costKnown ? 1 : 0,
      'shift_id': shiftId,
      'source': source,
      'payment_status': paymentStatus,
      'paid_amount': paidAmount,
    };
  }

  factory OrderModel.fromMap(
    Map<String, dynamic> map, {
    List<OrderItem> items = const [],
  }) {
    return OrderModel(
      id: map['id'] as int?,
      uuid: map['uuid'] as String?,
      invoiceNumber: map['invoice_number'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      totalAmount: (map['total_amount'] as num).toDouble(),
      discountAmount: (map['discount_amount'] as num?)?.toDouble() ?? 0,
      finalAmount: (map['final_amount'] as num).toDouble(),
      paymentAmount: (map['payment_amount'] as num).toDouble(),
      changeAmount: (map['change_amount'] as num).toDouble(),
      paymentMethod: map['payment_method'] as String,
      customerName: map['customer_name'] as String?,
      customerPhone: map['customer_phone'] as String?,
      tableNumber: map['table_number'] as String?,
      status: map['status'] as String? ?? 'selesai',
      costKnown: map['cost_known'] == null || map['cost_known'] == 1,
      shiftId: map['shift_id'] as int?,
      source: map['source'] as String? ?? sourcePos,
      paymentStatus: map['payment_status'] as String? ?? paymentPaid,
      paidAmount: (map['paid_amount'] as num?)?.toDouble(),
      items: items,
    );
  }
}
