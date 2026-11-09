class PaymentModel {
  final int? id;
  final String uuid;
  final int? orderId;
  final double amount;
  final String method;
  final DateTime paidAt;
  final int? shiftId;
  final String? note;

  PaymentModel({
    this.id,
    required this.uuid,
    this.orderId,
    required this.amount,
    required this.method,
    required this.paidAt,
    this.shiftId,
    this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'uuid': uuid,
      if (orderId != null) 'order_id': orderId,
      'amount': amount,
      'method': method,
      'paid_at': paidAt.toIso8601String(),
      'shift_id': shiftId,
      'note': note,
    };
  }

  factory PaymentModel.fromMap(Map<String, dynamic> map) {
    return PaymentModel(
      id: map['id'] as int?,
      uuid: map['uuid'] as String,
      orderId: map['order_id'] as int?,
      amount: (map['amount'] as num).toDouble(),
      method: map['method'] as String,
      paidAt: DateTime.parse(map['paid_at'] as String),
      shiftId: map['shift_id'] as int?,
      note: map['note'] as String?,
    );
  }
}
