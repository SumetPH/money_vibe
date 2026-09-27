enum CashFlowDirection {
  incoming('เงินเข้า'),
  outgoing('เงินออก');

  final String label;
  const CashFlowDirection(this.label);
}

/// คีย์เดือนปฏิทินรูปแบบ YYYY-MM สำหรับ paid mark
String cashFlowMonthKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}';

/// วันที่ [day] ของเดือน [year]/[month]; ถ้าเดือนนั้นไม่มีวันนี้จะใช้วันสิ้นเดือน
DateTime clampedDayOfMonth(int year, int month, int day) {
  final normalized = DateTime(year, month);
  final lastDay = DateTime(normalized.year, normalized.month + 1, 0).day;
  return DateTime(normalized.year, normalized.month, day.clamp(1, lastDay));
}

/// รายการเงินเข้าออกที่ผู้ใช้กำหนดเอง (ไม่ผูกกับบัญชีและ recurring)
/// เป็นรายการทุกเดือน ([dayOfMonth]) หรือครั้งเดียว ([oneTimeDate]) อย่างใดอย่างหนึ่ง
class FixedCashFlowItem {
  final String id;
  final String name;
  final double amount;
  final int? dayOfMonth; // 1-31 สำหรับรายการทุกเดือน
  final DateTime? oneTimeDate; // วันที่ของรายการครั้งเดียว
  final CashFlowDirection direction;
  final int sortOrder;

  const FixedCashFlowItem({
    required this.id,
    required this.name,
    required this.amount,
    required this.direction,
    this.dayOfMonth,
    this.oneTimeDate,
    this.sortOrder = 0,
  }) : assert(
         (dayOfMonth == null) != (oneTimeDate == null),
         'Set exactly one of dayOfMonth or oneTimeDate',
       );

  bool get isIncoming => direction == CashFlowDirection.incoming;
  bool get isOneTime => oneTimeDate != null;

  /// บวกเมื่อเป็นเงินเข้า ลบเมื่อเป็นเงินออก
  double get signedAmount => isIncoming ? amount : -amount;

  /// วันที่ที่รายการนี้เกิดในช่วง [start, end] (inclusive, ระดับวัน)
  List<DateTime> occurrencesBetween(DateTime start, DateTime end) {
    final once = oneTimeDate;
    if (once != null) {
      final day = DateTime(once.year, once.month, once.day);
      return day.isBefore(start) || day.isAfter(end) ? const [] : [day];
    }
    final dates = <DateTime>[];
    var month = DateTime(start.year, start.month);
    while (!month.isAfter(end)) {
      final date = clampedDayOfMonth(month.year, month.month, dayOfMonth!);
      if (!date.isBefore(start) && !date.isAfter(end)) dates.add(date);
      month = DateTime(month.year, month.month + 1);
    }
    return dates;
  }

  FixedCashFlowItem copyWith({
    String? name,
    double? amount,
    int? dayOfMonth,
    DateTime? oneTimeDate,
    CashFlowDirection? direction,
    int? sortOrder,
  }) => FixedCashFlowItem(
    id: id,
    name: name ?? this.name,
    amount: amount ?? this.amount,
    dayOfMonth: dayOfMonth ?? this.dayOfMonth,
    oneTimeDate: oneTimeDate ?? this.oneTimeDate,
    direction: direction ?? this.direction,
    sortOrder: sortOrder ?? this.sortOrder,
  );

  static String _dateOnly(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  // ชื่อ column ห้ามมีคำว่า "_date" เพราะ normalizeRow จะแทน null ด้วยเวลาปัจจุบัน
  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'amount': amount,
    'day_of_month': dayOfMonth,
    'one_time_on': oneTimeDate == null ? null : _dateOnly(oneTimeDate!),
    'direction': direction.name,
    'sort_order': sortOrder,
  };

  static FixedCashFlowItem fromMap(Map<String, dynamic> m) {
    final oneTimeRaw = m['one_time_on'] as String?;
    return FixedCashFlowItem(
      id: m['id'] as String,
      name: m['name'] as String,
      amount: (m['amount'] as num).toDouble(),
      dayOfMonth: oneTimeRaw == null ? m['day_of_month'] as int? : null,
      oneTimeDate: oneTimeRaw == null ? null : DateTime.parse(oneTimeRaw),
      direction: CashFlowDirection.values.firstWhere(
        (d) => d.name == m['direction'],
        orElse: () => CashFlowDirection.outgoing,
      ),
      sortOrder: m['sort_order'] as int? ?? 0,
    );
  }
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
