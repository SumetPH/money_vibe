import '../../models/account.dart';
import '../../models/transaction.dart';

/// บัญชีต้นทางที่เลือกได้ตามประเภทรายการ
List<Account> transactionSourceAccounts(
  TransactionType type,
  List<Account> visibleAccounts,
) {
  return switch (type) {
    TransactionType.debtTransfer =>
      visibleAccounts
          .where(
            (a) =>
                (a.type == AccountType.debt ||
                    a.type == AccountType.creditCard) &&
                !a.isPortfolio,
          )
          .toList(),
    TransactionType.income ||
    TransactionType.expense ||
    TransactionType.debtRepay =>
      visibleAccounts
          .where((a) => a.type != AccountType.debt && !a.isPortfolio)
          .toList(),
    TransactionType.increaseBalance || TransactionType.decreaseBalance =>
      visibleAccounts
          .where(
            (a) =>
                a.type == AccountType.cash ||
                a.type == AccountType.bankAccount ||
                a.type == AccountType.asset ||
                a.type == AccountType.debt,
          )
          .toList(),
    TransactionType.transfer || TransactionType.exchange => visibleAccounts,
  };
}

/// บัญชีปลายทางที่เลือกได้: แลกเงินต้องเป็นคนละสกุลกับต้นทาง
/// ส่วนโอน ชำระหนี้ และโอนหนี้ต้องเป็นสกุลเดียวกัน
List<Account> transactionTargetAccounts(
  TransactionType type,
  List<Account> candidates,
  Account? selectedSource,
) {
  if (selectedSource == null) return candidates;
  final currency = selectedSource.currency;
  return switch (type) {
    TransactionType.exchange =>
      candidates.where((a) => a.currency != currency).toList(),
    TransactionType.transfer ||
    TransactionType.debtRepay ||
    TransactionType.debtTransfer =>
      candidates.where((a) => a.currency == currency).toList(),
    _ => candidates,
  };
}

/// ตรวจข้อมูลการแปลงสกุลก่อนบันทึก; คืนข้อความ error หรือ null
/// [convertedAmount] คือยอดปลายทางของแลกเงิน หรือยอดสกุลต่างประเทศของรายรับ/รายจ่าย
String? validateTransactionConversion({
  required TransactionType type,
  required Account? source,
  required Account? target,
  required String? foreignCurrency,
  required double? convertedAmount,
}) {
  final hasAmount = convertedAmount != null && convertedAmount > 0;
  final isCrossCurrency =
      source != null && target != null && source.currency != target.currency;
  if (type == TransactionType.exchange) {
    if (target == null) return 'กรุณาเลือกบัญชีปลายทาง';
    if (!isCrossCurrency) return 'แลกเงินต้องเป็นบัญชีคนละสกุลเงิน';
    if (!hasAmount) return 'กรุณากรอกจำนวนที่ได้รับ';
  }
  if (type == TransactionType.transfer && isCrossCurrency) {
    return 'โอนได้เฉพาะบัญชีสกุลเดียวกัน ใช้ "แลกเงิน" แทน';
  }
  if (foreignCurrency != null) {
    if (foreignCurrency == source?.currency) {
      return 'สกุลต่างประเทศต้องไม่ตรงกับสกุลของบัญชี';
    }
    if (!hasAmount) return 'กรุณากรอกยอดสกุลต่างประเทศ';
  }
  return null;
}
