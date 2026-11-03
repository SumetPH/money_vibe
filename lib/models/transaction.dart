enum TransactionType {
  expense('รายจ่าย'),
  income('รายรับ'),
  transfer('โอน'),
  exchange('แลกเงิน'),
  debtRepay('ชำระหนี้สิน'),
  debtTransfer('โอนหนี้'),
  decreaseBalance('ปรับลดยอดบัญชี'),
  increaseBalance('ปรับเพิ่มยอดบัญชี');

  final String label;
  const TransactionType(this.label);

  bool get isExpenseLike =>
      this == TransactionType.expense ||
      this == TransactionType.debtRepay ||
      this == TransactionType.debtTransfer;

  bool get isTransferLike =>
      this == TransactionType.transfer || this == TransactionType.debtTransfer;

  /// ย้ายเงินระหว่างบัญชีของตัวเอง (ไม่ใช่รายรับ/รายจ่าย)
  bool get movesBetweenAccounts =>
      this == TransactionType.transfer || this == TransactionType.exchange;

  /// ปลายทางต้องเป็นสกุลเดียวกับต้นทาง (ข้ามสกุลต้องใช้ exchange)
  bool get requiresSameCurrency =>
      this == TransactionType.transfer ||
      this == TransactionType.debtRepay ||
      this == TransactionType.debtTransfer;

  bool get usesDestinationAccount =>
      this == TransactionType.transfer ||
      this == TransactionType.exchange ||
      this == TransactionType.debtRepay ||
      this == TransactionType.debtTransfer;

  bool get requiresDebtAccount =>
      this == TransactionType.debtRepay || this == TransactionType.debtTransfer;

  bool get supportsCategory =>
      this == TransactionType.income ||
      this == TransactionType.expense ||
      this == TransactionType.debtRepay ||
      this == TransactionType.debtTransfer;

  bool get isDecreaseBalance => this == TransactionType.decreaseBalance;
  bool get isIncreaseBalance => this == TransactionType.increaseBalance;
}

TransactionType parseTransactionType(
  String? raw, {
  TransactionType fallback = TransactionType.expense,
}) {
  if (raw == null || raw.isEmpty) return fallback;
  for (final type in TransactionType.values) {
    if (type.name == raw) return type;
  }
  return fallback;
}

class AppTransaction {
  final String id;
  TransactionType type;
  double amount;
  String accountId;
  String? categoryId;
  String? toAccountId;
  DateTime dateTime;
  String? note;
  // toAmount: จำนวนเงินในสกุลของบัญชีปลายทาง สำหรับรายการแลกเงิน
  // null = same currency (ใช้ amount เดิม)
  double? toAmount;
  // ยอดเดิมในสกุลต่างประเทศของรายรับ/รายจ่าย (ข้อมูลประกอบ)
  // amount ยังเป็นสกุลของบัญชีเสมอ; ทั้งสองค่าเป็น null หรือมีค่าพร้อมกัน
  double? foreignAmount;
  String? foreignCurrency;

  AppTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.accountId,
    this.categoryId,
    this.toAccountId,
    DateTime? dateTime,
    this.note,
    this.toAmount,
    this.foreignAmount,
    this.foreignCurrency,
  }) : dateTime = dateTime ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'id': id,
    'type': type.name,
    'amount': amount,
    'account_id': accountId,
    'category_id': categoryId,
    'to_account_id': toAccountId,
    'date_time': dateTime.toIso8601String(),
    'note': note,
    'to_amount': toAmount,
    'foreign_amount': foreignAmount,
    'foreign_currency': foreignCurrency,
  };

  bool get hasForeignAmount => foreignAmount != null && foreignCurrency != null;

  static AppTransaction fromMap(Map<String, dynamic> m) {
    return AppTransaction(
      id: m['id'] as String,
      type: parseTransactionType(m['type'] as String?),
      amount: (m['amount'] as num).toDouble(),
      accountId: m['account_id'] as String,
      categoryId: m['category_id'] as String?,
      toAccountId: m['to_account_id'] as String?,
      dateTime: DateTime.parse(m['date_time'] as String),
      note: m['note'] as String?,
      toAmount: (m['to_amount'] as num?)?.toDouble(),
      foreignAmount: (m['foreign_amount'] as num?)?.toDouble(),
      foreignCurrency: m['foreign_currency'] as String?,
    );
  }

  AppTransaction copyWith({
    String? id,
    TransactionType? type,
    double? amount,
    String? accountId,
    String? categoryId,
    bool clearCategoryId = false,
    String? toAccountId,
    bool clearToAccountId = false,
    DateTime? dateTime,
    String? note,
    double? toAmount,
    bool clearToAmount = false,
    double? foreignAmount,
    String? foreignCurrency,
    bool clearForeignAmount = false,
  }) {
    return AppTransaction(
      id: id ?? this.id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      accountId: accountId ?? this.accountId,
      categoryId: clearCategoryId ? null : (categoryId ?? this.categoryId),
      toAccountId: clearToAccountId ? null : (toAccountId ?? this.toAccountId),
      dateTime: dateTime ?? this.dateTime,
      note: note ?? this.note,
      toAmount: clearToAmount ? null : (toAmount ?? this.toAmount),
      foreignAmount: clearForeignAmount
          ? null
          : (foreignAmount ?? this.foreignAmount),
      foreignCurrency: clearForeignAmount
          ? null
          : (foreignCurrency ?? this.foreignCurrency),
    );
  }
}
