import 'dart:convert';

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
  DateTime dateTime;
  String? note;
  List<String> tags;

  AppTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.accountId,
    this.categoryId,
    this.toAccountId,
    DateTime? dateTime,
    this.note,
    List<String>? tags,
  }) : dateTime = dateTime ?? DateTime.now(),
       tags = tags ?? [];

  Map<String, dynamic> toMap() => {
    'id': id,
    'type': type.name,
    'amount': amount,
    'account_id': accountId,
    'category_id': categoryId,
    'to_account_id': toAccountId,
    'date_time': dateTime.toIso8601String(),
    'note': note,
    'tags': jsonEncode(tags),
  };

  static AppTransaction fromMap(Map<String, dynamic> m) {
    final tagsRaw = m['tags'] as String? ?? '[]';
    List<String> parsedTags;
    try {
      final decoded = jsonDecode(tagsRaw);
      if (decoded is List) {
        parsedTags = decoded.cast<String>();
      } else {
        // Fallback สำหรับข้อมูลเก่าที่ใช้ comma-separated
        parsedTags = tagsRaw.isEmpty ? [] : tagsRaw.split(',');
      }
    } catch (_) {
      // Fallback สำหรับข้อมูลเก่าที่ใช้ comma-separated
      parsedTags = tagsRaw.isEmpty || tagsRaw == '[]' ? [] : tagsRaw.split(',');
    }
    return AppTransaction(
      id: m['id'] as String,
      type: TransactionType.values.firstWhere(
        (e) => e.name == m['type'] as String,
      ),
      amount: (m['amount'] as num).toDouble(),
      accountId: m['account_id'] as String,
      categoryId: m['category_id'] as String?,
      toAccountId: m['to_account_id'] as String?,
      dateTime: DateTime.parse(m['date_time'] as String),
      note: m['note'] as String?,
      tags: parsedTags,
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
    List<String>? tags,
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
      tags: tags ?? this.tags,
    );
  }
}
