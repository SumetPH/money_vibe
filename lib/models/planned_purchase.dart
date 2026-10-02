import 'fixed_cash_flow_item.dart';

/// รายการอยากซื้อในลิสต์จำลองของ [period]; ไม่ติ๊กคือจดไว้เฉย ๆ
/// ติ๊ก ([isIncluded]) แล้วจึงนำมาคำนวณ
class PlannedPurchase {
  final String id;
  final String name;
  final double amount;
  final CashFlowPeriod period;
  final bool isIncluded;
  final int sortOrder;

  const PlannedPurchase({
    required this.id,
    required this.name,
    required this.amount,
    required this.period,
    this.isIncluded = false,
    this.sortOrder = 0,
  });

  PlannedPurchase copyWith({
    String? name,
    double? amount,
    CashFlowPeriod? period,
    bool? isIncluded,
    int? sortOrder,
  }) => PlannedPurchase(
    id: id,
    name: name ?? this.name,
    amount: amount ?? this.amount,
    period: period ?? this.period,
    isIncluded: isIncluded ?? this.isIncluded,
    sortOrder: sortOrder ?? this.sortOrder,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'amount': amount,
    'period': period.name,
    'is_included': isIncluded,
    'sort_order': sortOrder,
  };

  static PlannedPurchase fromMap(Map<String, dynamic> m) => PlannedPurchase(
    id: m['id'] as String,
    name: m['name'] as String,
    amount: (m['amount'] as num).toDouble(),
    period: CashFlowPeriod.fromName(m['period']),
    isIncluded: m['is_included'] as bool? ?? false,
    sortOrder: m['sort_order'] as int? ?? 0,
  );
}
