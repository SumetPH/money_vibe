import 'package:flutter/material.dart';

enum AccountGroup {
  investment(
    'เงินลงทุน / เงินออม',
    accountListOrder: 0,
    pickerOrder: 4,
    summaryOrder: 0,
    isAsset: true,
  ),
  cash(
    'เงินสด / เงินฝาก',
    accountListOrder: 1,
    pickerOrder: 0,
    summaryOrder: 1,
    isAsset: true,
  ),
  creditCard(
    'บัตรเครดิต',
    accountListOrder: 2,
    pickerOrder: 1,
    summaryOrder: 3,
    isAsset: false,
  ),
  debt(
    'หนี้สิน',
    accountListOrder: 3,
    pickerOrder: 2,
    summaryOrder: 4,
    isAsset: false,
  ),
  asset(
    'ทรัพย์สิน',
    accountListOrder: 4,
    pickerOrder: 3,
    summaryOrder: 2,
    isAsset: true,
  );

  final String label;
  final int accountListOrder;
  final int pickerOrder;
  final int summaryOrder;
  final bool isAsset;

  const AccountGroup(
    this.label, {
    required this.accountListOrder,
    required this.pickerOrder,
    required this.summaryOrder,
    required this.isAsset,
  });
}

enum AccountType {
  cash('เงินสด / เงินฝาก', AccountGroup.cash, 0),
  bankAccount('บัญชีธนาคาร', AccountGroup.cash, 1),
  creditCard('บัตรเครดิต', AccountGroup.creditCard, 2),
  debt('หนี้สิน', AccountGroup.debt, 3),
  asset('ทรัพย์สิน', AccountGroup.asset, 5),
  investment('เงินลงทุน / เงินออม', AccountGroup.investment, 4),
  portfolio('พอร์ตหุ้น US', AccountGroup.investment, 4),
  thaiPortfolio('พอร์ตหุ้นไทย', AccountGroup.investment, 4);

  final String label;
  final AccountGroup group;
  final int order;

  const AccountType(this.label, this.group, this.order);

  bool get isPortfolio => this == portfolio || this == thaiPortfolio;
  bool get isThaiPortfolio => this == thaiPortfolio;
  bool get isUsPortfolio => this == portfolio;
  String get defaultCurrency => isUsPortfolio ? 'USD' : 'THB';
}

List<AccountGroup> _sortedAccountGroupsBy(int Function(AccountGroup) order) {
  final groups = AccountGroup.values.toList()
    ..sort((a, b) => order(a).compareTo(order(b)));
  return groups;
}

List<AccountGroup> get accountGroupsForAccountList =>
    _sortedAccountGroupsBy((group) => group.accountListOrder);

List<AccountGroup> get accountGroupsForPicker =>
    _sortedAccountGroupsBy((group) => group.pickerOrder);

List<AccountGroup> get accountGroupsForDebtPicker => accountGroupsForPicker
    .where(
      (group) => group == AccountGroup.creditCard || group == AccountGroup.debt,
    )
    .toList();

List<AccountGroup> get accountGroupsForSummary =>
    _sortedAccountGroupsBy((group) => group.summaryOrder);

String accountTypeDisplayGroup(AccountType type) => type.group.label;

int accountTypeOrder(AccountType type) => type.order;

class Account {
  final String id;
  String name;
  AccountType type;
  double initialBalance;
  String currency;
  DateTime startDate;
  IconData icon;
  String iconUrl;
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
    this.iconUrl = '',
    this.color = const Color(0xFF607D8B),
    this.excludeFromNetWorth = false,
    this.isHidden = false,
    this.sortOrder = 0,
    this.cashBalance = 0,
    this.exchangeRate = 1.0,
    this.autoUpdateRate = true,
    this.statementDay,
  }) : startDate = startDate ?? DateTime.now();

  bool get isPortfolio => type.isPortfolio;
  bool get isThaiPortfolio => type.isThaiPortfolio;
  bool get isUsPortfolio => type.isUsPortfolio;
  String get currencyCodeLabel => currency == 'USD' ? 'USD' : 'THB';
  String get currencyAmountSuffix => currency == 'USD' ? 'USD' : 'บาท';

  String yahooSymbolFor(String ticker) {
    final normalized = ticker.trim().toUpperCase();
    if (!isThaiPortfolio || normalized.isEmpty || normalized.contains('.')) {
      return normalized;
    }
    return '$normalized.BK';
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'type': type.name,
    'initial_balance': initialBalance,
    'currency': currency,
    'start_date': startDate.toIso8601String(),
    'icon': icon.codePoint,
    'icon_url': iconUrl,
    'color': color.toARGB32(),
    'exclude_from_net_worth': excludeFromNetWorth ? 1 : 0,
    'is_hidden': isHidden ? 1 : 0,
    'sort_order': sortOrder,
    'cash_balance': cashBalance,
    'exchange_rate': exchangeRate,
    'auto_update_rate': autoUpdateRate ? 1 : 0,
    'statement_day': statementDay,
  };

  static Account fromMap(Map<String, dynamic> m) {
    final rawRate = (m['exchange_rate'] as num? ?? 1.0).toDouble();
    return Account(
      id: m['id'] as String,
      name: m['name'] as String,
      type: AccountType.values.firstWhere((e) => e.name == m['type'] as String),
      initialBalance: (m['initial_balance'] as num).toDouble(),
      currency: m['currency'] as String,
      startDate: DateTime.parse(m['start_date'] as String),
      icon: IconData(m['icon'] as int, fontFamily: 'MaterialIcons'),
      iconUrl: m['icon_url'] as String? ?? '',
      color: Color(m['color'] as int),
      excludeFromNetWorth: m['exclude_from_net_worth'] == 1,
      isHidden: m['is_hidden'] == 1,
      sortOrder: m['sort_order'] as int? ?? 0,
      cashBalance: (m['cash_balance'] as num? ?? 0).toDouble(),
      exchangeRate: rawRate <= 0 ? 1.0 : rawRate,
      autoUpdateRate: (m['auto_update_rate'] as int? ?? 1) == 1,
      statementDay: m['statement_day'] as int?,
    );
  }

  Account copyWith({
    String? name,
    AccountType? type,
    double? initialBalance,
    String? currency,
    DateTime? startDate,
    String? iconUrl,
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
      iconUrl: iconUrl ?? this.iconUrl,
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
