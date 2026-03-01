enum TransactionType {
  expense('รายจ่าย'),
  income('รายรับ'),
  transfer('โอน'),
  debtRepay('ชำระหนี้สิน');

  final String label;
  const TransactionType(this.label);
}

class AppTransaction {
  final String id;
  TransactionType type;
  double amount;
  String accountId;
  String? categoryId;
  String? toAccountId;
  String? payee;
  String? location;
  DateTime dateTime;
  String? note;
  List<String> tags;
  bool isCleared;
  DateTime? recordDate;

  AppTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.accountId,
    this.categoryId,
    this.toAccountId,
    this.payee,
    this.location,
    DateTime? dateTime,
    this.note,
    List<String>? tags,
    this.isCleared = false,
    this.recordDate,
  })  : dateTime = dateTime ?? DateTime.now(),
        tags = tags ?? [];

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.name,
        'amount': amount,
        'account_id': accountId,
        'category_id': categoryId,
        'to_account_id': toAccountId,
        'payee': payee,
        'location': location,
        'date_time': dateTime.millisecondsSinceEpoch,
        'note': note,
        'tags': tags.join(','),
        'is_cleared': isCleared ? 1 : 0,
        'record_date': recordDate?.millisecondsSinceEpoch,
      };

  static AppTransaction fromMap(Map<String, dynamic> m) {
    final tagsRaw = m['tags'] as String? ?? '';
    return AppTransaction(
      id: m['id'] as String,
      type: TransactionType.values
          .firstWhere((e) => e.name == m['type'] as String),
      amount: (m['amount'] as num).toDouble(),
      accountId: m['account_id'] as String,
      categoryId: m['category_id'] as String?,
      toAccountId: m['to_account_id'] as String?,
      payee: m['payee'] as String?,
      location: m['location'] as String?,
      dateTime:
          DateTime.fromMillisecondsSinceEpoch(m['date_time'] as int),
      note: m['note'] as String?,
      tags: tagsRaw.isEmpty ? [] : tagsRaw.split(','),
      isCleared: m['is_cleared'] == 1,
      recordDate: m['record_date'] != null
          ? DateTime.fromMillisecondsSinceEpoch(m['record_date'] as int)
          : null,
    );
  }
}
