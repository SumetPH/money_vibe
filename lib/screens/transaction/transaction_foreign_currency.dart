import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/account.dart';
import '../../models/transaction.dart';
import '../../providers/transaction_provider.dart';
import '../../services/exchange_rate_service.dart';
import '../../utils/currency_utils.dart';
import '../../utils/exchange_rate_utils.dart';
import '../../widgets/currency_picker_sheet.dart';
import 'transaction_conversion_controller.dart';

const String _fallbackForeignCurrency = 'USD';

/// สกุลต่างประเทศเริ่มต้น: สกุลล่าสุดที่เคยใช้ (ตามวันที่รายการ)
/// ที่ไม่ใช่สกุลของบัญชี ไม่มีให้ใช้สกุลแรกในรายการที่ไม่ใช่สกุลของบัญชี
String defaultForeignCurrency(
  List<AppTransaction> transactions,
  String accountCurrency,
) {
  AppTransaction? latest;
  for (final tx in transactions) {
    final currency = tx.foreignCurrency;
    if (!tx.hasForeignAmount || currency == accountCurrency) continue;
    if (latest == null || tx.dateTime.isAfter(latest.dateTime)) latest = tx;
  }
  final remembered = latest?.foreignCurrency;
  if (remembered != null) return remembered;
  if (accountCurrency != _fallbackForeignCurrency) {
    return _fallbackForeignCurrency;
  }
  return CurrencyUtils.currencies
      .firstWhere((c) => c.code != accountCurrency)
      .code;
}

/// rate ตลาดตามทิศทางของ [quote]; null ถ้าดึงไม่สำเร็จ (ผู้ใช้กรอกเองได้)
Future<double?> fetchMarketRate(ExchangeQuote quote) async {
  try {
    return await const ExchangeRateService().fetchRate(
      base: quote.baseCurrency,
      quote: quote.quoteCurrency,
    );
  } catch (e) {
    debugPrint('TransactionForm: Failed to fetch market rate: $e');
    return null;
  }
}

/// สถานะและ action ของ "ชำระเป็นสกุลต่างประเทศ" ในฟอร์มรายรับ/รายจ่าย
mixin TransactionForeignCurrencyHost<T extends StatefulWidget> on State<T> {
  /// บัญชีที่เลือก (สกุลของยอดที่ตัดบัญชี)
  Account? get foreignSourceAccount;
  TransactionConversionController get foreignConversion;

  /// เรียกหลังสกุลต่างประเทศเปลี่ยน ให้ฟอร์มตั้งคู่สกุลของ conversion ใหม่
  void onForeignCurrencyChanged();
  void closeTransactionKeyboard();

  String? _foreignCurrency;

  /// สกุลต่างประเทศที่เลือก; null = ปิด
  String? get foreignCurrency => _foreignCurrency;

  void initForeignCurrency(String? currency) => _foreignCurrency = currency;

  void setForeignCurrency(String? currency) {
    setState(() => _foreignCurrency = currency);
    if (currency == null) foreignConversion.clear();
    onForeignCurrencyChanged();
    if (currency != null) _suggestMarketRate();
  }

  void toggleForeignCurrency(bool isOn) {
    final account = foreignSourceAccount;
    if (!isOn || account == null) return setForeignCurrency(null);
    setForeignCurrency(
      defaultForeignCurrency(
        context.read<TransactionProvider>().transactions,
        account.currency,
      ),
    );
  }

  void pickForeignCurrency() {
    final account = foreignSourceAccount;
    final current = _foreignCurrency;
    if (account == null || current == null) return;
    closeTransactionKeyboard();
    showCurrencyPickerSheet(
      context,
      selectedCurrency: current,
      excludedCurrencies: {account.currency},
      onSelected: setForeignCurrency,
    );
  }

  /// เติม rate ตลาดเพื่อประมาณยอดที่ตัดบัญชี ผู้ใช้แก้เป็นยอดจริงทีหลังได้
  Future<void> _suggestMarketRate() async {
    final quote = foreignConversion.quote;
    if (quote == null) return;
    final rate = await fetchMarketRate(quote);
    if (!mounted || rate == null || foreignConversion.quote != quote) return;
    foreignConversion.suggestRate(rate);
    onForeignCurrencyChanged();
  }
}
