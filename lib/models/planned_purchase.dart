/// รายการอยากซื้อชุดเดียวกัน เลือกนับแยกงวดนี้และงวดถัดไป
class PlannedPurchase {
  final String id;
  final String name;
  final double amount;
  final bool isIncluded; // งวดถัดไป (คงสถานะเดิม)
  final bool isIncludedCurrent;
  final int sortOrder;

  const PlannedPurchase({
    required this.id,
    required this.name,
    required this.amount,
    this.isIncluded = true,
    this.isIncludedCurrent = false,
    this.sortOrder = 0,
  });

  PlannedPurchase copyWith({
    String? name,
    double? amount,
    bool? isIncluded,
    bool? isIncludedCurrent,
    int? sortOrder,
  }) => PlannedPurchase(
    id: id,
    name: name ?? this.name,
    amount: amount ?? this.amount,
    isIncluded: isIncluded ?? this.isIncluded,
    isIncludedCurrent: isIncludedCurrent ?? this.isIncludedCurrent,
    sortOrder: sortOrder ?? this.sortOrder,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'amount': amount,
    'is_included': isIncluded,
    'is_included_current': isIncludedCurrent,
    'sort_order': sortOrder,
  };

  static PlannedPurchase fromMap(Map<String, dynamic> m) => PlannedPurchase(
    id: m['id'] as String,
    name: m['name'] as String,
    amount: (m['amount'] as num).toDouble(),
    isIncluded: m['is_included'] as bool? ?? true,
    isIncludedCurrent: m['is_included_current'] as bool? ?? false,
    sortOrder: m['sort_order'] as int? ?? 0,
  );
}
