import 'package:flutter/material.dart';
import '../../models/transaction.dart';

class TransactionListData {
  final List<AppTransaction> transactions;
  final List<TransactionDateGroup> groups;
  final double totalIncome;
  final double totalExpense;

  const TransactionListData({
    required this.transactions,
    required this.groups,
    required this.totalIncome,
    required this.totalExpense,
  });
}

class TransactionDateGroup {
  final DateTime date;
  final List<AppTransaction> transactions;
  final double income;
  final double expense;

  const TransactionDateGroup({
    required this.date,
    required this.transactions,
    required this.income,
    required this.expense,
  });
}

class TransactionMutableTransactionDateGroup {
  final DateTime date;
  final List<AppTransaction> transactions = [];
  double income = 0;
  double expense = 0;

  TransactionMutableTransactionDateGroup(this.date);
}

enum TransactionPeriodFilter {
  all('ทั้งหมด'),
  last30Days('30 วันล่าสุด'),
  last90Days('90 วันล่าสุด'),
  last180Days('180 วันล่าสุด'),
  thisMonth('เดือนนี้'),
  lastMonth('เดือนที่แล้ว'),
  thisYear('ปีนี้'),
  oneYear('1 ปี'),
  custom('กำหนดช่วงวันที่');

  final String label;
  const TransactionPeriodFilter(this.label);

  String get shortLabel => switch (this) {
    TransactionPeriodFilter.all => 'ทั้งหมด',
    TransactionPeriodFilter.last30Days => '30 วัน',
    TransactionPeriodFilter.last90Days => '90 วัน',
    TransactionPeriodFilter.last180Days => '180 วัน',
    TransactionPeriodFilter.thisMonth => 'เดือนนี้',
    TransactionPeriodFilter.lastMonth => 'เดือนก่อน',
    TransactionPeriodFilter.thisYear => 'ปีนี้',
    TransactionPeriodFilter.oneYear => '1 ปี',
    TransactionPeriodFilter.custom => 'กำหนดเอง',
  };
}

enum TransactionTypeFilter {
  all('ทั้งหมด'),
  income('รายรับ'),
  expense('รายจ่าย');

  final String label;
  const TransactionTypeFilter(this.label);
}

String formatTransactionMonthYear(DateTime date) {
  const thaiMonths = [
    'มกราคม',
    'กุมภาพันธ์',
    'มีนาคม',
    'เมษายน',
    'พฤษภาคม',
    'มิถุนายน',
    'กรกฎาคม',
    'สิงหาคม',
    'กันยายน',
    'ตุลาคม',
    'พฤศจิกายน',
    'ธันวาคม',
  ];
  return '${thaiMonths[date.month - 1]} ${date.year}';
}

String formatTransactionRange(DateTimeRange range, {required bool withYear}) {
  String format(DateTime date) {
    final base = '${date.day} ${formatTransactionMonthShort(date)}';
    return withYear ? '$base ${date.year}' : base;
  }

  final start = range.start;
  final end = range.end;
  if (DateUtils.isSameDay(start, end)) return format(start);
  return '${format(start)} - ${format(end)}';
}

String formatTransactionMonthShort(DateTime date) {
  const thaiMonths = [
    'ม.ค.',
    'ก.พ.',
    'มี.ค.',
    'เม.ย.',
    'พ.ค.',
    'มิ.ย.',
    'ก.ค.',
    'ส.ค.',
    'ก.ย.',
    'ต.ค.',
    'พ.ย.',
    'ธ.ค.',
  ];
  return thaiMonths[date.month - 1];
}

String formatTransactionDate(DateTime date) {
  const thaiDays = [
    'จันทร์',
    'อังคาร',
    'พุธ',
    'พฤหัสบดี',
    'ศุกร์',
    'เสาร์',
    'อาทิตย์',
  ];
  const thaiMonths = [
    'ม.ค.',
    'ก.พ.',
    'มี.ค.',
    'เม.ย.',
    'พ.ค.',
    'มิ.ย.',
    'ก.ค.',
    'ส.ค.',
    'ก.ย.',
    'ต.ค.',
    'พ.ย.',
    'ธ.ค.',
  ];
  final dayOfWeek = thaiDays[date.weekday - 1];
  return '${date.day} ${thaiMonths[date.month - 1]} ${date.year} · $dayOfWeek';
}
