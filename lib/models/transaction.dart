
enum TransactionType {
  expense('รายจ่าย'),
  income('รายรับ'),
  transfer('โอน'),
  debtRepay('ชำระหนี้สิน'),
  debtTransfer('โอนหนี้');

  final String label;
  const TransactionType(this.label);

  bool get isExpenseLike =>
      this == TransactionType.expense ||
      this == TransactionType.debtRepay ||
      this == TransactionType.debtTransfer;

  bool get isTransferLike =>
      this == TransactionType.transfer || this == TransactionType.debtTransfer;

  bool get usesDestinationAccount =>
      this == TransactionType.transfer ||
      this == TransactionType.debtRepay ||
      this == TransactionType.debtTransfer;

  bool get requiresDebtAccount =>
      this == TransactionType.debtRepay || this == TransactionType.debtTransfer;

  bool get supportsCategory =>
      this == TransactionType.income ||
      this == TransactionType.expense ||
      this == TransactionType.debtRepay ||
      this == TransactionType.debtTransfer;
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

  AppTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.accountId,
    this.categoryId,
    this.toAccountId,
    DateTime? dateTime,
    this.note,
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
  };

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
    );
  }
}
