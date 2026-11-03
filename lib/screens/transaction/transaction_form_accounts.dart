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
    TransactionType.exchange =>
      visibleAccounts.where((a) => !a.isPortfolio).toList(),
    TransactionType.transfer => visibleAccounts,
  };
}

/// บัญชีปลายทางที่เลือกได้: แลกเงินต้องเป็นคนละสกุลกับต้นทาง
List<Account> transactionTargetAccounts(
  TransactionType type,
  List<Account> sourceAccounts,
  Account? selectedSource,
) {
  if (type != TransactionType.exchange || selectedSource == null) {
    return sourceAccounts;
  }
  return sourceAccounts
      .where((a) => a.currency != selectedSource.currency)
      .toList();
}
