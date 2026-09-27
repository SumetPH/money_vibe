enum CashFlowDirection {
  incoming('เงินเข้า'),
  outgoing('เงินออก');

  final String label;
  const CashFlowDirection(this.label);
}

/// คีย์เดือนปฏิทินรูปแบบ YYYY-MM สำหรับ paid mark
String cashFlowMonthKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}';

/// รายการเงินเข้าออกประจำเดือนที่ผู้ใช้กำหนดเอง (ไม่ผูกกับบัญชีและ recurring)
class FixedCashFlowItem {
  final String id;
  final String name;
  final double amount;
  final int dayOfMonth; // 1-31, ถ้าเดือนนั้นไม่มีวันนี้จะใช้วันสิ้นเดือน
  final CashFlowDirection direction;
  final bool isPayday;
  final int sortOrder;

  const FixedCashFlowItem({
    required this.id,
    required this.name,
    required this.amount,
    required this.dayOfMonth,
    required this.direction,
    this.isPayday = false,
    this.sortOrder = 0,
  });

  bool get isIncoming => direction == CashFlowDirection.incoming;

  /// บวกเมื่อเป็นเงินเข้า ลบเมื่อเป็นเงินออก
  double get signedAmount => isIncoming ? amount : -amount;

  /// วันที่ของรายการนี้ในเดือน [year]/[month]
  DateTime occurrenceIn(int year, int month) {
    final lastDay = DateTime(year, month + 1, 0).day;
    final normalized = DateTime(year, month);
    return DateTime(
      normalized.year,
      normalized.month,
      dayOfMonth.clamp(1, lastDay),
    );
  }

  FixedCashFlowItem copyWith({
    String? name,
    double? amount,
    int? dayOfMonth,
    CashFlowDirection? direction,
    bool? isPayday,
    int? sortOrder,
  }) => FixedCashFlowItem(
    id: id,
    name: name ?? this.name,
    amount: amount ?? this.amount,
    dayOfMonth: dayOfMonth ?? this.dayOfMonth,
    direction: direction ?? this.direction,
    isPayday: isPayday ?? this.isPayday,
    sortOrder: sortOrder ?? this.sortOrder,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'amount': amount,
    'day_of_month': dayOfMonth,
    'direction': direction.name,
    'is_payday': isPayday,
    'sort_order': sortOrder,
  };

  static FixedCashFlowItem fromMap(Map<String, dynamic> m) => FixedCashFlowItem(
    id: m['id'] as String,
    name: m['name'] as String,
    amount: (m['amount'] as num).toDouble(),
    dayOfMonth: m['day_of_month'] as int,
    direction: CashFlowDirection.values.firstWhere(
      (d) => d.name == m['direction'],
      orElse: () => CashFlowDirection.outgoing,
    ),
    isPayday: m['is_payday'] as bool? ?? false,
    sortOrder: m['sort_order'] as int? ?? 0,
  );
}

/// การยืนยันว่ารายการประจำเกิดขึ้นแล้วสำหรับเดือนปฏิทินหนึ่ง
class FixedCashFlowPaidMark {
  final String id;
  final String itemId;
  final String month; // YYYY-MM

  const FixedCashFlowPaidMark({
    required this.id,
    required this.itemId,
    required this.month,
  });

  Map<String, dynamic> toMap() => {'id': id, 'item_id': itemId, 'month': month};

  static FixedCashFlowPaidMark fromMap(Map<String, dynamic> m) =>
      FixedCashFlowPaidMark(
        id: m['id'] as String,
        itemId: m['item_id'] as String,
        month: m['month'] as String,
      );
}
