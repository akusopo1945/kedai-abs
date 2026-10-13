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
    );
  }
}

class OrderModel {
  final int? id;
  final String invoiceNumber;
  final DateTime createdAt;
  final double totalAmount;
  final double discountAmount;
  final double finalAmount;
  final double paymentAmount;
  final double changeAmount;
  final String paymentMethod; // 'cash', 'qris', 'transfer'
  final String? customerName;
  final List<OrderItem> items;

  OrderModel({
    this.id,
    required this.invoiceNumber,
    required this.createdAt,
    required this.totalAmount,
    this.discountAmount = 0.0,
    required this.finalAmount,
    required this.paymentAmount,
    required this.changeAmount,
    required this.paymentMethod,
    this.customerName,
    this.items = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'invoice_number': invoiceNumber,
      'created_at': createdAt.toIso8601String(),
      'total_amount': totalAmount,
      'discount_amount': discountAmount,
      'final_amount': finalAmount,
      'payment_amount': paymentAmount,
      'change_amount': changeAmount,
      'payment_method': paymentMethod,
      'customer_name': customerName,
    };
  }

  factory OrderModel.fromMap(Map<String, dynamic> map, {List<OrderItem> items = const []}) {
    return OrderModel(
      id: map['id'] as int?,
      invoiceNumber: map['invoice_number'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      totalAmount: (map['total_amount'] as num).toDouble(),
      discountAmount: (map['discount_amount'] as num).toDouble(),
      finalAmount: (map['final_amount'] as num).toDouble(),
      paymentAmount: (map['payment_amount'] as num).toDouble(),
      changeAmount: (map['change_amount'] as num).toDouble(),
      paymentMethod: map['payment_method'] as String,
      customerName: map['customer_name'] as String?,
      items: items,
    );
  }
}
