import 'package:flutter/material.dart';

enum AccountType {
  cash('กระเป๋าสตางค์/เงินสด'),
  bankAccount('บัญชีธนาคาร'),
  creditCard('บัตรเครดิต'),
  debt('หนี้สิน'),
  asset('ทรัพย์สิน'),
  investment('ลงทุน'),
  portfolio('พอร์ตหุ้น US');

  final String label;
  const AccountType(this.label);
}

String accountTypeDisplayGroup(AccountType type) {
  switch (type) {
    case AccountType.cash:
    case AccountType.bankAccount:
      return 'เงินสด / เงินฝาก';
    case AccountType.creditCard:
      return 'บัตรเครดิต';
    case AccountType.debt:
      return 'หนี้สิน';
    case AccountType.investment:
    case AccountType.portfolio:
      return 'ลงทุน';
    case AccountType.asset:
      return 'ทรัพย์สิน';
  }
}

int accountTypeOrder(AccountType type) {
  switch (type) {
    case AccountType.cash:
      return 0;
    case AccountType.bankAccount:
      return 1;
    case AccountType.creditCard:
      return 2;
    case AccountType.debt:
      return 3;
    case AccountType.investment:
    case AccountType.portfolio:
      return 4;
    case AccountType.asset:
      return 5;
  }
}

class Account {
  final String id;
  String name;
  AccountType type;
  double initialBalance;
  String currency;
  DateTime startDate;
  IconData icon;
  Color color;
  bool excludeFromNetWorth;
  bool isHidden;
  int sortOrder;

  // Portfolio-specific fields
  double cashBalance;
  double exchangeRate;
  bool autoUpdateRate;

  // Credit card-specific fields
  int? statementDay; // วันสรุปยอดบัตรเครดิต (1-31)

  Account({
    required this.id,
    required this.name,
    required this.type,
    this.initialBalance = 0,
    this.currency = 'THB',
    DateTime? startDate,
    this.icon = Icons.account_balance_wallet,
    this.color = const Color(0xFF607D8B),
    this.excludeFromNetWorth = false,
    this.isHidden = false,
    this.sortOrder = 0,
    this.cashBalance = 0,
    this.exchangeRate = 35.0,
    this.autoUpdateRate = true,
    this.statementDay,
  }) : startDate = startDate ?? DateTime.now();

  bool get isPortfolio => type == AccountType.portfolio;

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'type': type.name,
    'initial_balance': initialBalance,
    'currency': currency,
    'start_date': startDate.toIso8601String(),
    'icon': icon.codePoint,
    'color': color.toARGB32(),
    'exclude_from_net_worth': excludeFromNetWorth ? 1 : 0,
    'is_hidden': isHidden ? 1 : 0,
    'sort_order': sortOrder,
    'cash_balance': cashBalance,
    'exchange_rate': exchangeRate,
    'auto_update_rate': autoUpdateRate ? 1 : 0,
    'statement_day': statementDay,
  };

  static Account fromMap(Map<String, dynamic> m) => Account(
    id: m['id'] as String,
    name: m['name'] as String,
    type: AccountType.values.firstWhere((e) => e.name == m['type'] as String),
    initialBalance: (m['initial_balance'] as num).toDouble(),
    currency: m['currency'] as String,
    startDate: DateTime.parse(m['start_date'] as String),
    icon: IconData(m['icon'] as int, fontFamily: 'MaterialIcons'),
    color: Color(m['color'] as int),
    excludeFromNetWorth: m['exclude_from_net_worth'] == 1,
    isHidden: m['is_hidden'] == 1,
    sortOrder: m['sort_order'] as int? ?? 0,
    cashBalance: (m['cash_balance'] as num? ?? 0).toDouble(),
    exchangeRate: (m['exchange_rate'] as num? ?? 35.0).toDouble(),
    autoUpdateRate: (m['auto_update_rate'] as int? ?? 1) == 1,
    statementDay: m['statement_day'] as int?,
  );

  Account copyWith({
    String? name,
    AccountType? type,
    double? initialBalance,
    String? currency,
    DateTime? startDate,
    IconData? icon,
    Color? color,
    bool? autoClearTransaction,
    bool? showOnMain,
    bool? excludeFromNetWorth,
    bool? isHidden,
    String? group,
    String? note,
    int? sortOrder,
    double? cashBalance,
    double? exchangeRate,
    bool? autoUpdateRate,
    int? statementDay,
  }) {
    return Account(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      initialBalance: initialBalance ?? this.initialBalance,
      currency: currency ?? this.currency,
      startDate: startDate ?? this.startDate,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      excludeFromNetWorth: excludeFromNetWorth ?? this.excludeFromNetWorth,
      isHidden: isHidden ?? this.isHidden,
      sortOrder: sortOrder ?? this.sortOrder,
      cashBalance: cashBalance ?? this.cashBalance,
      exchangeRate: exchangeRate ?? this.exchangeRate,
      autoUpdateRate: autoUpdateRate ?? this.autoUpdateRate,
      statementDay: statementDay ?? this.statementDay,
    );
  }
}
