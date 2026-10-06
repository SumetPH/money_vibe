import 'package:flutter/material.dart';
import '../../models/category.dart';

class StatisticsMonthlyData {
  final int month;
  final String monthName;
  final String monthShort;
  double income = 0;
  double expense = 0;
  final List<String> transactionIds = [];

  StatisticsMonthlyData({
    required this.month,
    required this.monthName,
    required this.monthShort,
  });
}

class StatisticsCategoryData {
  final Category category;
  final double amount;
  final Color color;
  final IconData icon;
  final List<String> transactionIds;

  StatisticsCategoryData({
    required this.category,
    required this.amount,
    required this.color,
    required this.icon,
    required this.transactionIds,
  });
}

class StatisticsNetWorthData {
  final DateTime date;
  final double netWorth;

  StatisticsNetWorthData({required this.date, required this.netWorth});
}

enum StatisticsNetWorthPeriodFilter {
  all('ทั้งหมด'),
  threeMonths('3 เดือน'),
  sixMonths('6 เดือน'),
  oneYear('1 ปี'),
  thisYear('ปีนี้');

  final String label;
  const StatisticsNetWorthPeriodFilter(this.label);
}
