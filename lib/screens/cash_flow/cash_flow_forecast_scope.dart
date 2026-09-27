import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../providers/account_provider.dart';
import '../../providers/cash_flow_forecast_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/transaction_provider.dart';
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

/// คำนวณ forecast จาก provider ที่เกี่ยวข้อง และ rebuild เมื่อ provider เปลี่ยน
CashFlowForecast? watchCashFlowForecast(BuildContext context) {
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
