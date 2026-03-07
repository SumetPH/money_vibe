import 'package:flutter/material.dart';
import 'transaction.dart';

enum OccurrenceStatus { pending, done, skipped }

class RecurringTransaction {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final DateTime startDate;
  final DateTime? endDate;
  final int dayOfMonth; // 1–31; 0 = last day of month
  final TransactionType transactionType;
  final double amount;
  final String accountId;
  final String? toAccountId; // for transfer
  final String? categoryId;
  final String? note;
  final int sortOrder;

  const RecurringTransaction({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.startDate,
    this.endDate,
    required this.dayOfMonth,
    required this.transactionType,
    required this.amount,
    required this.accountId,
    this.toAccountId,
    this.categoryId,
    this.note,
    this.sortOrder = 0,
  });

  RecurringTransaction copyWith({
    String? id,
    String? name,
    IconData? icon,
    Color? color,
    DateTime? startDate,
    DateTime? endDate,
    bool clearEndDate = false,
    int? dayOfMonth,
    TransactionType? transactionType,
    double? amount,
    String? accountId,
    String? toAccountId,
    bool clearToAccountId = false,
    String? categoryId,
    bool clearCategoryId = false,
    String? note,
    bool clearNote = false,
    int? sortOrder,
  }) {
    return RecurringTransaction(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      startDate: startDate ?? this.startDate,
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      transactionType: transactionType ?? this.transactionType,
      amount: amount ?? this.amount,
      accountId: accountId ?? this.accountId,
      toAccountId:
          clearToAccountId ? null : (toAccountId ?? this.toAccountId),
      categoryId: clearCategoryId ? null : (categoryId ?? this.categoryId),
      note: clearNote ? null : (note ?? this.note),
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon': icon.codePoint,
      'color': color.toARGB32(),
      'start_date': startDate.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'day_of_month': dayOfMonth,
      'transaction_type': transactionType.name,
      'amount': amount,
      'account_id': accountId,
      'to_account_id': toAccountId,
      'category_id': categoryId,
      'note': note,
      'sort_order': sortOrder,
    };
  }

  factory RecurringTransaction.fromMap(Map<String, dynamic> map) {
    IconData icon;
    final iconRaw = map['icon'];
    if (iconRaw is int) {
      icon = IconData(iconRaw, fontFamily: 'MaterialIcons');
    } else {
      icon = Icons.repeat;
    }

    Color color;
    final colorRaw = map['color'];
    if (colorRaw is int) {
      color = Color(colorRaw);
    } else {
      color = const Color(0xFF607D8B);
    }

    final txType = parseTransactionType(map['transaction_type']?.toString());

    return RecurringTransaction(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      icon: icon,
      color: color,
      startDate:
          DateTime.tryParse(map['start_date']?.toString() ?? '') ??
          DateTime.now(),
      endDate: map['end_date'] != null
          ? DateTime.tryParse(map['end_date'].toString())
          : null,
      dayOfMonth: (map['day_of_month'] as num?)?.toInt() ?? 1,
      transactionType: txType,
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      accountId: map['account_id']?.toString() ?? '',
      toAccountId: map['to_account_id']?.toString(),
      categoryId: map['category_id']?.toString(),
      note: map['note']?.toString(),
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  /// Generate all occurrence dates from startDate up to [upTo].
  /// If [upTo] is null and [endDate] is null, defaults to today + 65 days.
  List<DateTime> generateOccurrenceDates({DateTime? upTo}) {
    final List<DateTime> dates = [];
    final end =
        endDate ?? upTo ?? DateTime.now().add(const Duration(days: 65));

    var year = startDate.year;
    var month = startDate.month;
    var iterations = 0;

    while (iterations < 240) {
      iterations++;
      final daysInMonth = DateUtils.getDaysInMonth(year, month);
      final day = dayOfMonth == 0
          ? daysInMonth
          : dayOfMonth.clamp(1, daysInMonth);
      final date = DateTime(year, month, day);

      if (!date.isBefore(startDate) && !date.isAfter(end)) {
        dates.add(date);
      }

      if (date.isAfter(end)) break;

      if (month == 12) {
        year++;
        month = 1;
      } else {
        month++;
      }
    }

    return dates;
  }

  /// Next occurrence on or after today.
  DateTime? get nextOccurrence {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final upTo = endDate ?? today.add(const Duration(days: 65));
    final dates = generateOccurrenceDates(upTo: upTo);
    for (final d in dates) {
      if (!d.isBefore(today)) return d;
    }
    return null;
  }
}

// ─── Occurrence record ───────────────────────────────────────────────────────

class RecurringOccurrence {
  final String id;
  final String recurringId;
  final DateTime dueDate;
  final String? transactionId; // set when status == done
  final OccurrenceStatus status;

  const RecurringOccurrence({
    required this.id,
    required this.recurringId,
    required this.dueDate,
    this.transactionId,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'recurring_id': recurringId,
      'due_date': dueDate.toIso8601String(),
      'transaction_id': transactionId,
      'status': status.name,
    };
  }

  factory RecurringOccurrence.fromMap(Map<String, dynamic> map) {
    return RecurringOccurrence(
      id: map['id']?.toString() ?? '',
      recurringId: map['recurring_id']?.toString() ?? '',
      dueDate:
          DateTime.tryParse(map['due_date']?.toString() ?? '') ??
          DateTime.now(),
      transactionId: map['transaction_id']?.toString(),
      status: OccurrenceStatus.values.firstWhere(
        (s) => s.name == (map['status']?.toString() ?? 'done'),
        orElse: () => OccurrenceStatus.done,
      ),
    );
  }
}
