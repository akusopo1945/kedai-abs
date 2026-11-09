class ShiftModel {
  static const String statusOpen = 'open';
  static const String statusClosed = 'closed';

  final int? id;
  final String uuid;
  final DateTime openedAt;
  final DateTime? closedAt;
  final double openingCash;
  final double? countedCash;
  final double? expectedCash;
  final String? note;
  final String status;

  ShiftModel({
    this.id,
    required this.uuid,
    required this.openedAt,
    this.closedAt,
    this.openingCash = 0,
    this.countedCash,
    this.expectedCash,
    this.note,
    this.status = statusOpen,
  });

  bool get isOpen => status == statusOpen;

  double? get cashDifference => countedCash != null && expectedCash != null
      ? countedCash! - expectedCash!
      : null;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'uuid': uuid,
      'opened_at': openedAt.toIso8601String(),
      'closed_at': closedAt?.toIso8601String(),
      'opening_cash': openingCash,
      'counted_cash': countedCash,
      'expected_cash': expectedCash,
      'note': note,
      'status': status,
    };
  }

  factory ShiftModel.fromMap(Map<String, dynamic> map) {
    final closedAt = map['closed_at'] as String?;
    return ShiftModel(
      id: map['id'] as int?,
      uuid: map['uuid'] as String,
      openedAt: DateTime.parse(map['opened_at'] as String),
      closedAt: closedAt == null ? null : DateTime.parse(closedAt),
      openingCash: (map['opening_cash'] as num?)?.toDouble() ?? 0,
      countedCash: (map['counted_cash'] as num?)?.toDouble(),
      expectedCash: (map['expected_cash'] as num?)?.toDouble(),
      note: map['note'] as String?,
      status: map['status'] as String? ?? statusOpen,
    );
  }
}

class SalesSummary {
  final int transactionCount;
  final double revenue;

  /// Profit from orders whose product costs are known.
  final double profit;
  final int unknownCostCount;

  const SalesSummary({
    required this.transactionCount,
    required this.revenue,
    required this.profit,
    required this.unknownCostCount,
  });

  const SalesSummary.empty()
      : transactionCount = 0,
        revenue = 0,
        profit = 0,
        unknownCostCount = 0;
}

class ShiftSummary {
  final ShiftModel shift;
  final SalesSummary sales;

  /// Sales in this shift recorded as customer debt (kasbon).
  final double newDebt;

  /// Debt repayments received in this shift, including older debts.
  final double debtCollected;

  /// Money received in this shift, grouped by payment method.
  final Map<String, double> paymentsByMethod;
  final double cashIn;
  final double outstandingDebt;

  const ShiftSummary({
    required this.shift,
    required this.sales,
    required this.newDebt,
    required this.debtCollected,
    required this.paymentsByMethod,
    required this.cashIn,
    required this.outstandingDebt,
  });

  double get expectedCash => shift.openingCash + cashIn;

  double get totalReceived =>
      paymentsByMethod.values.fold(0.0, (sum, value) => sum + value);
}
