enum CashFlowDirection {
  incoming('เงินเข้า'),
  outgoing('เงินออก');

  final String label;
  const CashFlowDirection(this.label);
}

/// ลิสต์จำลองของงวดนี้หรืองวดถัดไป (คงที่ ไม่เลื่อนเมื่อผ่านวันเคลียร์ยอด)
enum CashFlowPeriod {
  current('งวดนี้'),
  next('งวดถัดไป');

  final String label;
  const CashFlowPeriod(this.label);

  static CashFlowPeriod fromName(Object? name) =>
      name == CashFlowPeriod.next.name ? next : current;
}

/// วันที่ [day] ของเดือน [year]/[month]; ถ้าเดือนนั้นไม่มีวันนี้จะใช้วันสิ้นเดือน
DateTime clampedDayOfMonth(int year, int month, int day) {
  final normalized = DateTime(year, month);
  final lastDay = DateTime(normalized.year, normalized.month + 1, 0).day;
  return DateTime(normalized.year, normalized.month, day.clamp(1, lastDay));
}

/// รายการเงินเข้าออกที่ผู้ใช้กำหนดเอง (ไม่ผูกกับบัญชีและ recurring)
/// อยู่ในลิสต์ของ [period]; ติ๊ก ([isDone]) แล้วจะไม่นับ
class FixedCashFlowItem {
  final String id;
  final String name;
  final double amount;
  final CashFlowDirection direction;
  final CashFlowPeriod period;
  final bool isDone;
  final int sortOrder;

  const FixedCashFlowItem({
    required this.id,
    required this.name,
    required this.amount,
    required this.direction,
    required this.period,
    this.isDone = false,
    this.sortOrder = 0,
  });

  bool get isIncoming => direction == CashFlowDirection.incoming;

  /// บวกเมื่อเป็นเงินเข้า ลบเมื่อเป็นเงินออก
  double get signedAmount => isIncoming ? amount : -amount;

  FixedCashFlowItem copyWith({
    String? name,
    double? amount,
    CashFlowDirection? direction,
    CashFlowPeriod? period,
    bool? isDone,
    int? sortOrder,
  }) => FixedCashFlowItem(
    id: id,
    name: name ?? this.name,
    amount: amount ?? this.amount,
    direction: direction ?? this.direction,
    period: period ?? this.period,
    isDone: isDone ?? this.isDone,
    sortOrder: sortOrder ?? this.sortOrder,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'amount': amount,
    'direction': direction.name,
    'period': period.name,
    'is_done': isDone,
    'sort_order': sortOrder,
  };

  static FixedCashFlowItem fromMap(Map<String, dynamic> m) => FixedCashFlowItem(
    id: m['id'] as String,
    name: m['name'] as String,
    amount: (m['amount'] as num).toDouble(),
    direction: CashFlowDirection.values.firstWhere(
      (d) => d.name == m['direction'],
      orElse: () => CashFlowDirection.outgoing,
    ),
    period: CashFlowPeriod.fromName(m['period']),
    isDone: m['is_done'] as bool? ?? false,
    sortOrder: m['sort_order'] as int? ?? 0,
  );
}
