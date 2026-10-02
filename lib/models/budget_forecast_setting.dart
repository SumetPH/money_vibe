/// การตั้งค่างบหนึ่งรายการใน Forecast window หนึ่งงวด (ระบุด้วยวันเคลียร์ยอดของงวด)
/// เพื่อให้การเลือกเลื่อนตามงวดจริงเมื่อเปลี่ยนงวด
class BudgetForecastSetting {
  final String id;
  final String budgetId;
  final DateTime periodEnd; // วันเคลียร์ยอดของงวด

  /// null = ตามค่าเริ่มต้นของงบ (งบที่ซ่อนไว้ไม่นับ งบปกตินับ)
  final bool? isExcluded;

  /// ยอดสมมติ (what-if) ใช้เฉพาะในการคาดการณ์ ไม่เปลี่ยนงบจริง; null = ใช้ยอดงบจริง
  final double? amount;

  const BudgetForecastSetting({
    required this.id,
    required this.budgetId,
    required this.periodEnd,
    this.isExcluded,
    this.amount,
  });

  /// ไม่มีผลต่อการคำนวณ จึงไม่ต้องเก็บไว้
  bool get isDefault => isExcluded == null && amount == null;

  /// ไม่นับงบนี้ในงวด โดยงบที่ซ่อนไว้ ([isHidden]) ไม่นับเป็นค่าเริ่มต้น
  bool isExcludedFor({required bool isHidden}) => isExcluded ?? isHidden;

  /// ตั้งให้นับหรือไม่นับ; ถ้าตรงกับค่าเริ่มต้นจะเก็บเป็น null
  BudgetForecastSetting withIncluded(
    bool isIncluded, {
    required bool isHidden,
  }) => BudgetForecastSetting(
    id: id,
    budgetId: budgetId,
    periodEnd: periodEnd,
    isExcluded: isIncluded == !isHidden ? null : !isIncluded,
    amount: amount,
  );

  BudgetForecastSetting copyWith({double? amount, bool clearAmount = false}) =>
      BudgetForecastSetting(
        id: id,
        budgetId: budgetId,
        periodEnd: periodEnd,
        isExcluded: isExcluded,
        amount: clearAmount ? null : (amount ?? this.amount),
      );

  Map<String, dynamic> toMap() => {
    'id': id,
    'budget_id': budgetId,
    'period_end_on': periodKey(periodEnd),
    'is_excluded': isExcluded,
    'amount': amount,
  };

  static BudgetForecastSetting fromMap(Map<String, dynamic> m) =>
      BudgetForecastSetting(
        id: m['id'] as String,
        budgetId: m['budget_id'] as String,
        periodEnd: DateTime.parse(m['period_end_on'] as String),
        isExcluded: m['is_excluded'] as bool?,
        amount: (m['amount'] as num?)?.toDouble(),
      );

  /// key ของงวด เช่น "2026-10-30"
  static String periodKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
