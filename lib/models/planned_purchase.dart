/// รายการที่อยากซื้อ ใช้ลองดูผลกระทบต่อ Cash-flow forecast งวดถัดไป
/// ([isIncluded] = นับในการคาดการณ์หรือไม่)
class PlannedPurchase {
  final String id;
  final String name;
  final double amount;
  final bool isIncluded;
  final int sortOrder;

  const PlannedPurchase({
    required this.id,
    required this.name,
    required this.amount,
    this.isIncluded = true,
    this.sortOrder = 0,
  });

  PlannedPurchase copyWith({
    String? name,
    double? amount,
    bool? isIncluded,
    int? sortOrder,
  }) => PlannedPurchase(
    id: id,
    name: name ?? this.name,
    amount: amount ?? this.amount,
    isIncluded: isIncluded ?? this.isIncluded,
    sortOrder: sortOrder ?? this.sortOrder,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'amount': amount,
    'is_included': isIncluded,
    'sort_order': sortOrder,
  };

  static PlannedPurchase fromMap(Map<String, dynamic> m) => PlannedPurchase(
    id: m['id'] as String,
    name: m['name'] as String,
    amount: (m['amount'] as num).toDouble(),
    isIncluded: m['is_included'] as bool? ?? true,
    sortOrder: m['sort_order'] as int? ?? 0,
  );
}
