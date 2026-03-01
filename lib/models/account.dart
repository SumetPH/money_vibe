import 'package:flutter/material.dart';

enum AccountType {
  cash('กระเป๋าสตางค์/เงินสด'),
  bankAccount('บัญชีธนาคาร'),
  creditCard('บัตรเครดิต'),
  debt('หนี้สิน'),
  investment('ลงทุน');

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
      return 'ลงทุน';
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
      return 4;
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
  bool autoClearTransaction;
  bool showOnMain;
  bool isDefault;
  bool excludeFromNetWorth;
  bool isHidden;
  String? group;
  String? note;

  Account({
    required this.id,
    required this.name,
    required this.type,
    this.initialBalance = 0,
    this.currency = 'THB',
    DateTime? startDate,
    this.icon = Icons.account_balance_wallet,
    this.color = const Color(0xFF607D8B),
    this.autoClearTransaction = true,
    this.showOnMain = false,
    this.isDefault = false,
    this.excludeFromNetWorth = false,
    this.isHidden = false,
    this.group,
    this.note,
  }) : startDate = startDate ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'type': type.name,
        'initial_balance': initialBalance,
        'currency': currency,
        'start_date': startDate.millisecondsSinceEpoch,
        'icon': icon.codePoint,
        'color': color.toARGB32(),
        'auto_clear': autoClearTransaction ? 1 : 0,
        'show_on_main': showOnMain ? 1 : 0,
        'is_default': isDefault ? 1 : 0,
        'exclude_from_net_worth': excludeFromNetWorth ? 1 : 0,
        'is_hidden': isHidden ? 1 : 0,
        'group_name': group,
        'note': note,
      };

  static Account fromMap(Map<String, dynamic> m) => Account(
        id: m['id'] as String,
        name: m['name'] as String,
        type: AccountType.values
            .firstWhere((e) => e.name == m['type'] as String),
        initialBalance: (m['initial_balance'] as num).toDouble(),
        currency: m['currency'] as String,
        startDate:
            DateTime.fromMillisecondsSinceEpoch(m['start_date'] as int),
        icon: IconData(m['icon'] as int, fontFamily: 'MaterialIcons'),
        color: Color(m['color'] as int),
        autoClearTransaction: m['auto_clear'] == 1,
        showOnMain: m['show_on_main'] == 1,
        isDefault: m['is_default'] == 1,
        excludeFromNetWorth: m['exclude_from_net_worth'] == 1,
        isHidden: m['is_hidden'] == 1,
        group: m['group_name'] as String?,
        note: m['note'] as String?,
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
    bool? isDefault,
    bool? excludeFromNetWorth,
    bool? isHidden,
    String? group,
    String? note,
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
      autoClearTransaction: autoClearTransaction ?? this.autoClearTransaction,
      showOnMain: showOnMain ?? this.showOnMain,
      isDefault: isDefault ?? this.isDefault,
      excludeFromNetWorth: excludeFromNetWorth ?? this.excludeFromNetWorth,
      isHidden: isHidden ?? this.isHidden,
      group: group ?? this.group,
      note: note ?? this.note,
    );
  }
}
