import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../providers/account_provider.dart';
import '../../providers/budget_provider.dart';
import '../../providers/cash_flow_forecast_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../models/fixed_cash_flow_item.dart';
import '../../services/cash_flow_forecast_service.dart';

const _thaiShortMonths = [
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

/// เช่น "29 ต.ค."
String formatCashFlowDate(DateTime date) =>
    '${date.day} ${_thaiShortMonths[date.month - 1]}';

/// เช่น "ทุกวันที่ 25" หรือ "ครั้งเดียว 15 ต.ค. 2026"
String cashFlowScheduleLabel(FixedCashFlowItem item) {
  final once = item.oneTimeDate;
  return once == null
      ? 'ทุกวันที่ ${item.dayOfMonth}'
      : 'ครั้งเดียว ${formatCashFlowDate(once)} ${once.year}';
}

/// เรียงรายการเงินเข้าออกทั้งหมด: รายการทุกเดือนตามวันที่ในเดือน แล้วรายการครั้งเดียวตามวันที่
/// (วันเดียวกันเรียงตามชื่อ)
List<FixedCashFlowItem> sortCashFlowItems(List<FixedCashFlowItem> items) {
  int compare(FixedCashFlowItem a, FixedCashFlowItem b) {
    if (a.isOneTime != b.isOneTime) return a.isOneTime ? 1 : -1;
    final byDate = a.isOneTime
        ? a.oneTimeDate!.compareTo(b.oneTimeDate!)
        : a.dayOfMonth!.compareTo(b.dayOfMonth!);
    return byDate != 0 ? byDate : a.name.compareTo(b.name);
  }

  return [...items]..sort(compare);
}

/// คำนวณ forecast จาก provider ที่เกี่ยวข้อง และ rebuild เมื่อ provider เปลี่ยน
CashFlowForecast watchCashFlowForecast(BuildContext context) {
  final cashFlow = context.watch<CashFlowForecastProvider>();
  final accountProvider = context.watch<AccountProvider>();
  final transactions = context.watch<TransactionProvider>().transactions;
  final startDay = context.select<SettingsProvider, int>(
    (s) => s.monthlyCycleStartDay,
  );
  return cashFlow.buildForecast(
    accounts: accountProvider.accounts,
    transactions: transactions,
    balanceInThb: (account) =>
        accountProvider.getBalanceInThb(account.id, transactions),
    monthlyCycleStartDay: startDay,
  );
}

/// คาดการณ์งวดถัดไปต่อจาก [current] และ rebuild เมื่อ provider เปลี่ยน
NextPeriodForecast watchNextPeriodForecast(
  BuildContext context,
  CashFlowForecast current,
) {
  final cashFlow = context.watch<CashFlowForecastProvider>();
  final accounts = context.watch<AccountProvider>().accounts;
  final transactions = context.watch<TransactionProvider>().transactions;
  final budgets = context.watch<BudgetProvider>().budgets;
  final startDay = context.select<SettingsProvider, int>(
    (s) => s.monthlyCycleStartDay,
  );
  return cashFlow.buildNextPeriod(
    current: current,
    accounts: accounts,
    transactions: transactions,
    budgets: budgets,
    monthlyCycleStartDay: startDay,
  );
}
