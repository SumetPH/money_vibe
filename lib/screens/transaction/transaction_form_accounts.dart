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
