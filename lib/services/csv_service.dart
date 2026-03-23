import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../models/account.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../models/budget.dart';
import '../models/recurring_transaction.dart';
import '../models/stock_holding.dart';
import '../services/database_manager.dart';

// Helper functions for IconData and Color
IconData _parseIcon(dynamic value) {
  if (value is int) {
    return IconData(value, fontFamily: 'MaterialIcons');
  }
  return const IconData(0xe8a6, fontFamily: 'MaterialIcons');
}

Color _parseColor(dynamic value) {
  if (value is int) {
    return Color(value);
  }
  return const Color(0xFF607D8B);
}

class CsvService {
  static final CsvService instance = CsvService._();
  CsvService._();

  final _uuid = const Uuid();
  final _dbManager = DatabaseManager();

  /// Export all data to CSV files and share them
  Future<void> exportToCsv({Rect? sharePositionOrigin}) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final tempDir = await getTemporaryDirectory();

    // Export accounts
    final accountsFile = File('${tempDir.path}/accounts_$timestamp.csv');
    final accountsCsv = await _exportAccounts();
    await accountsFile.writeAsString(accountsCsv, encoding: utf8);

    // Export categories
    final categoriesFile = File('${tempDir.path}/categories_$timestamp.csv');
    final categoriesCsv = await _exportCategories();
    await categoriesFile.writeAsString(categoriesCsv, encoding: utf8);

    // Export transactions
    final transactionsFile = File(
      '${tempDir.path}/transactions_$timestamp.csv',
    );
    final transactionsCsv = await _exportTransactions();
    await transactionsFile.writeAsString(transactionsCsv, encoding: utf8);

    // Export portfolio holdings
    final holdingsFile = File('${tempDir.path}/holdings_$timestamp.csv');
    final holdingsCsv = await _exportHoldings();
    await holdingsFile.writeAsString(holdingsCsv, encoding: utf8);

    // Export budgets
    final budgetsFile = File('${tempDir.path}/budgets_$timestamp.csv');
    final budgetsCsv = await _exportBudgets();
    await budgetsFile.writeAsString(budgetsCsv, encoding: utf8);

    // Export recurring transactions
    final recurringFile = File('${tempDir.path}/recurring_$timestamp.csv');
    final recurringCsv = await _exportRecurringTransactions();
    await recurringFile.writeAsString(recurringCsv, encoding: utf8);

    // Export recurring occurrences
    final occurrencesFile = File('${tempDir.path}/occurrences_$timestamp.csv');
    final occurrencesCsv = await _exportRecurringOccurrences();
    await occurrencesFile.writeAsString(occurrencesCsv, encoding: utf8);

    // Share all files
    final files = [
      XFile(accountsFile.path),
      XFile(categoriesFile.path),
      XFile(transactionsFile.path),
      XFile(holdingsFile.path),
      XFile(budgetsFile.path),
      XFile(recurringFile.path),
      XFile(occurrencesFile.path),
    ];

    await Share.shareXFiles(
      files,
      subject: 'Money App Backup ${DateTime.now().toString().split('.')[0]}',
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  /// Import data from CSV files
  /// Import order: accounts → categories → budgets → holdings → recurring → transactions → occurrences
  Future<ImportResult> importFromCsv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      allowMultiple: true,
    );

    if (result == null || result.files.isEmpty) {
      return ImportResult.canceled();
    }

    // เก็บไฟล์ตามประเภท
    String? accountsContent;
    String? categoriesContent;
    String? budgetsContent;
    String? holdingsContent;
    String? recurringContent;
    String? transactionsContent;
    String? occurrencesContent;
    List<String> errors = [];

    // อ่านไฟล์ทั้งหมดก่อน
    for (final file in result.files) {
      if (file.path == null) continue;

      final content = await File(file.path!).readAsString(encoding: utf8);
      final filename = file.name.toLowerCase();

      debugPrint('CSV Service: Reading file: ${file.name}');

      if (filename.contains('account')) {
        accountsContent = content;
      } else if (filename.contains('categor')) {
        categoriesContent = content;
      } else if (filename.contains('budget')) {
        budgetsContent = content;
      } else if (filename.contains('holding')) {
        holdingsContent = content;
      } else if (filename.contains('recurring')) {
        recurringContent = content;
      } else if (filename.contains('transaction')) {
        transactionsContent = content;
      } else if (filename.contains('occurrence')) {
        occurrencesContent = content;
      }
    }

    int accountsCount = 0;
    int categoriesCount = 0;
    int transactionsCount = 0;
    int holdingsCount = 0;
    int budgetsCount = 0;
    int recurringTransactionsCount = 0;
    int recurringOccurrencesCount = 0;

    // Import ตามลำดับ dependency (แยก try-catch เพื่อให้ import ต่อได้ถ้าอันใดล้ม)
    // 1. Accounts first (required by holdings, recurring, transactions)
    if (accountsContent != null) {
      try {
        debugPrint('CSV Service: Importing ACCOUNTS');
        accountsCount = await _importAccounts(accountsContent);
      } catch (e) {
        debugPrint('CSV Service: Error importing accounts: $e');
        errors.add('accounts: $e');
      }
    }

    // 2. Categories (required by transactions)
    if (categoriesContent != null) {
      try {
        debugPrint('CSV Service: Importing CATEGORIES');
        categoriesCount = await _importCategories(categoriesContent);
      } catch (e) {
        debugPrint('CSV Service: Error importing categories: $e');
        errors.add('categories: $e');
      }
    }

    // 3. Budgets
    if (budgetsContent != null) {
      try {
        debugPrint('CSV Service: Importing BUDGETS');
        budgetsCount = await _importBudgets(budgetsContent);
      } catch (e) {
        debugPrint('CSV Service: Error importing budgets: $e');
        errors.add('budgets: $e');
      }
    }

    // 4. Holdings (depends on accounts)
    if (holdingsContent != null) {
      try {
        debugPrint('CSV Service: Importing HOLDINGS');
        holdingsCount = await _importHoldings(holdingsContent);
      } catch (e) {
        debugPrint('CSV Service: Error importing holdings: $e');
        errors.add('holdings: $e');
      }
    }

    // 5. Recurring transactions (depends on accounts)
    if (recurringContent != null) {
      try {
        debugPrint('CSV Service: Importing RECURRING');
        recurringTransactionsCount = await _importRecurringTransactions(
          recurringContent,
        );
      } catch (e) {
        debugPrint('CSV Service: Error importing recurring: $e');
        errors.add('recurring: $e');
      }
    }

    // 6. Transactions (depends on accounts, categories)
    if (transactionsContent != null) {
      try {
        debugPrint('CSV Service: Importing TRANSACTIONS');
        transactionsCount = await _importTransactions(transactionsContent);
      } catch (e) {
        debugPrint('CSV Service: Error importing transactions: $e');
        errors.add('transactions: $e');
      }
    }

    // 7. Occurrences (depends on recurring)
    if (occurrencesContent != null) {
      try {
        debugPrint('CSV Service: Importing OCCURRENCES');
        recurringOccurrencesCount = await _importRecurringOccurrences(
          occurrencesContent,
        );
      } catch (e) {
        debugPrint('CSV Service: Error importing occurrences: $e');
        errors.add('occurrences: $e');
      }
    }

    debugPrint(
      'CSV Service: Import complete - Accounts: $accountsCount, Categories: $categoriesCount, Transactions: $transactionsCount, Holdings: $holdingsCount, Budgets: $budgetsCount, Recurring Transactions: $recurringTransactionsCount, Recurring Occurrences: $recurringOccurrencesCount',
    );
    return ImportResult(
      accountsCount: accountsCount,
      categoriesCount: categoriesCount,
      transactionsCount: transactionsCount,
      holdingsCount: holdingsCount,
      budgetsCount: budgetsCount,
      recurringTransactionsCount: recurringTransactionsCount,
      recurringOccurrencesCount: recurringOccurrencesCount,
      errors: errors,
    );
  }

  // ========== Export Methods ==========

  Future<String> _exportAccounts() async {
    final accounts = await _dbManager.repository.getAccounts();

    final rows = <List<dynamic>>[
      // Header
      [
        'id',
        'name',
        'type',
        'initial_balance',
        'currency',
        'start_date',
        'icon',
        'color',
        'exclude_from_net_worth',
        'is_hidden',
        'sort_order',
        'cash_balance',
        'exchange_rate',
        'auto_update_rate',
        'statement_day',
      ],
    ];

    for (final account in accounts) {
      rows.add([
        account.id,
        account.name,
        account.type.name,
        account.initialBalance,
        account.currency,
        account.startDate.toIso8601String(),
        account.icon.codePoint,  // Export as int
        account.color.toARGB32(), // Export as int
        account.excludeFromNetWorth ? 1 : 0,
        account.isHidden ? 1 : 0,
        account.sortOrder,
        account.cashBalance,
        account.exchangeRate,
        account.autoUpdateRate ? 1 : 0,
        account.statementDay ?? '',
      ]);
    }

    return const ListToCsvConverter().convert(rows);
  }

  Future<String> _exportCategories() async {
    final categories = await _dbManager.repository.getCategories();

    final rows = <List<dynamic>>[
      // Header
      [
        'id',
        'name',
        'type',
        'icon',
        'color',
        'parent_id',
        'note',
        'sort_order',
      ],
    ];

    for (final category in categories) {
      rows.add([
        category.id,
        category.name,
        category.type.name,
        category.icon.codePoint,
        category.color.toARGB32(),
        category.parentId ?? '',
        category.note ?? '',
        category.sortOrder,
      ]);
    }

    return const ListToCsvConverter().convert(rows);
  }

  Future<String> _exportTransactions() async {
    final transactions = await _dbManager.repository.getTransactions();

    final rows = <List<dynamic>>[
      // Header
      [
        'id',
        'type',
        'amount',
        'account_id',
        'category_id',
        'to_account_id',
        'date_time',
        'note',
      ],
    ];

    for (final tx in transactions) {
      rows.add([
        tx.id,
        tx.type.name,
        tx.amount,
        tx.accountId,
        tx.categoryId ?? '',
        tx.toAccountId ?? '',
        tx.dateTime.toIso8601String(),
        tx.note ?? '',
      ]);
    }

    return const ListToCsvConverter().convert(rows);
  }

  Future<String> _exportHoldings() async {
    final holdings = await _dbManager.repository.getPortfolioHoldings();

    final rows = <List<dynamic>>[
      // Header
      [
        'id',
        'portfolio_id',
        'ticker',
        'name',
        'shares',
        'price_usd',
        'cost_basis_usd',
        'sort_order',
      ],
    ];

    for (final holding in holdings) {
      rows.add([
        holding.id,
        holding.portfolioId,
        holding.ticker,
        holding.name,
        holding.shares,
        holding.priceUsd,
        holding.costBasisUsd,
        holding.sortOrder,
      ]);
    }

    return const ListToCsvConverter().convert(rows);
  }

  Future<String> _exportBudgets() async {
    final budgets = await _dbManager.repository.getBudgets();

    final rows = <List<dynamic>>[
      // Header
      ['id', 'name', 'amount', 'category_ids', 'icon', 'color', 'sort_order'],
    ];

    for (final budget in budgets) {
      rows.add([
        budget.id,
        budget.name,
        budget.amount,
        jsonEncode(budget.categoryIds),
        budget.icon.codePoint,
        budget.color.toARGB32(),
        budget.sortOrder,
      ]);
    }

    return const ListToCsvConverter().convert(rows);
  }

  Future<String> _exportRecurringTransactions() async {
    final recurring = await _dbManager.repository.getRecurringTransactions();

    final rows = <List<dynamic>>[
      // Header
      [
        'id',
        'name',
        'icon',
        'color',
        'start_date',
        'end_date',
        'day_of_month',
        'transaction_type',
        'amount',
        'account_id',
        'to_account_id',
        'category_id',
        'note',
        'sort_order',
      ],
    ];

    for (final r in recurring) {
      rows.add([
        r.id,
        r.name,
        r.icon.codePoint,
        r.color.toARGB32(),
        r.startDate.toIso8601String(),
        r.endDate?.toIso8601String() ?? '',
        r.dayOfMonth,
        r.transactionType.name,
        r.amount,
        r.accountId,
        r.toAccountId ?? '',
        r.categoryId ?? '',
        r.note ?? '',
        r.sortOrder,
      ]);
    }

    return const ListToCsvConverter().convert(rows);
  }

  Future<String> _exportRecurringOccurrences() async {
    final occurrences = await _dbManager.repository.getRecurringOccurrences();

    final rows = <List<dynamic>>[
      // Header
      ['id', 'recurring_id', 'due_date', 'transaction_id', 'status'],
    ];

    for (final occ in occurrences) {
      rows.add([
        occ.id,
        occ.recurringId,
        occ.dueDate.toIso8601String(),
        occ.transactionId ?? '',
        occ.status.name,
      ]);
    }

    return const ListToCsvConverter().convert(rows);
  }

  // ========== Import Methods ==========

  Future<int> _importAccounts(String csvContent) async {
    final lines = csvContent
        .split(RegExp(r'\r?\n'))
        .where((line) => line.trim().isNotEmpty)
        .toList();

    final rows = lines.map((line) {
      return const CsvToListConverter().convert(line)[0];
    }).toList();

    if (rows.length <= 1) return 0;

    // ดึง existing IDs ก่อน
    final existingIds = await _dbManager.repository.getExistingAccountIds();
    debugPrint('CSV Import: Found ${existingIds.length} existing accounts');

    // สร้าง list ของ accounts จาก CSV
    final accounts = <Account>[];
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty || row.length < 5) continue;

      final id = row[0]?.toString() ?? _uuid.v4();
      
      // Skip ถ้า ID ซ้ำ
      if (existingIds.contains(id)) {
        debugPrint('CSV Import: Skipping duplicate account ID: $id');
        continue;
      }

      accounts.add(Account(
        id: id,
        name: row[1]?.toString() ?? 'Unknown',
        type: AccountType.values.byName(row[2]?.toString() ?? 'cash'),
        initialBalance: double.tryParse(row[3]?.toString() ?? '0') ?? 0,
        currency: row[4]?.toString() ?? 'THB',
        startDate: DateTime.tryParse(row[5]?.toString() ?? '') ?? DateTime.now(),
        icon: _parseIcon(int.tryParse(row[6]?.toString() ?? '')),
        color: _parseColor(int.tryParse(row[7]?.toString() ?? '')),
        excludeFromNetWorth: (int.tryParse(row[8]?.toString() ?? '') ?? 0) == 1,
        isHidden: (int.tryParse(row[9]?.toString() ?? '') ?? 0) == 1,
        sortOrder: int.tryParse(row[10]?.toString() ?? '') ?? 0,
        cashBalance: row.length > 11
            ? (double.tryParse(row[11]?.toString() ?? '') ?? 0)
            : 0,
        exchangeRate: row.length > 12
            ? (double.tryParse(row[12]?.toString() ?? '') ?? 35.0)
            : 35.0,
        autoUpdateRate: row.length > 13
            ? (int.tryParse(row[13]?.toString() ?? '') ?? 1) == 1
            : true,
        statementDay: row.length > 14
            ? int.tryParse(row[14]?.toString() ?? '')
            : null,
      ));
    }

    // Bulk insert
    if (accounts.isNotEmpty) {
      debugPrint('CSV Import: Bulk inserting ${accounts.length} accounts');
      await _dbManager.repository.bulkInsertAccounts(accounts);
    }

    return accounts.length;
  }

  Future<int> _importCategories(String csvContent) async {
    final lines = csvContent
        .split(RegExp(r'\r?\n'))
        .where((line) => line.trim().isNotEmpty)
        .toList();

    final rows = lines.map((line) {
      return const CsvToListConverter().convert(line)[0];
    }).toList();

    if (rows.length <= 1) return 0;

    final existingIds = await _dbManager.repository.getExistingCategoryIds();
    debugPrint('CSV Import: Found ${existingIds.length} existing categories');

    final categories = <Category>[];
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty) continue;

      final id = row[0]?.toString() ?? _uuid.v4();
      
      if (existingIds.contains(id)) {
        debugPrint('CSV Import: Skipping duplicate category ID: $id');
        continue;
      }

      categories.add(Category(
        id: id,
        name: row[1]?.toString() ?? 'Unknown',
        type: CategoryType.values.byName(row[2]?.toString() ?? 'expense'),
        icon: _parseIcon(int.tryParse(row[3]?.toString() ?? '')),
        color: _parseColor(int.tryParse(row[4]?.toString() ?? '')),
        parentId: row[5]?.toString().isEmpty == true
            ? null
            : row[5]?.toString(),
        note: row[6]?.toString(),
        sortOrder: int.tryParse(row[7]?.toString() ?? '') ?? 0,
      ));
    }

    if (categories.isNotEmpty) {
      debugPrint('CSV Import: Bulk inserting ${categories.length} categories');
      await _dbManager.repository.bulkInsertCategories(categories);
    }

    return categories.length;
  }

  Future<int> _importTransactions(String csvContent) async {
    final lines = csvContent
        .split(RegExp(r'\r?\n'))
        .where((line) => line.trim().isNotEmpty)
        .toList();

    final rows = lines.map((line) {
      return const CsvToListConverter().convert(line)[0];
    }).toList();

    if (rows.length <= 1) return 0;

    final existingIds = await _dbManager.repository.getExistingTransactionIds();
    // ดึง account IDs เพื่อเช็ค foreign key
    final existingAccountIds = await _dbManager.repository.getExistingAccountIds();
    
    debugPrint('CSV Import: Found ${existingIds.length} existing transactions');
    debugPrint('CSV Import: Found ${existingAccountIds.length} existing accounts');

    final transactions = <AppTransaction>[];
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty) continue;

      final id = row[0]?.toString() ?? _uuid.v4();
      final accountId = row[3]?.toString() ?? '';
      
      // Skip ถ้า ID ซ้ำ
      if (existingIds.contains(id)) {
        debugPrint('CSV Import: Skipping duplicate transaction ID: $id');
        continue;
      }
      
      // Skip ถ้า account_id ไม่มีใน database
      if (!existingAccountIds.contains(accountId)) {
        debugPrint('CSV Import: Skipping transaction $id - account $accountId not found');
        continue;
      }


      transactions.add(AppTransaction(
        id: id,
        type: parseTransactionType(row[1]?.toString()),
        amount: double.tryParse(row[2]?.toString() ?? '0') ?? 0,
        accountId: accountId,
        categoryId: row[4]?.toString().isEmpty == true
            ? null
            : row[4]?.toString(),
        toAccountId: row[5]?.toString().isEmpty == true
            ? null
            : row[5]?.toString(),
        dateTime: DateTime.tryParse(row[6]?.toString() ?? '') ?? DateTime.now(),
        note: row[7]?.toString(),
      ));
    }

    if (transactions.isNotEmpty) {
      debugPrint('CSV Import: Bulk inserting ${transactions.length} transactions');
      await _dbManager.repository.bulkInsertTransactions(transactions);
    }

    return transactions.length;
  }

  Future<int> _importHoldings(String csvContent) async {
    final lines = csvContent
        .split(RegExp(r'\r?\n'))
        .where((line) => line.trim().isNotEmpty)
        .toList();

    final rows = lines.map((line) {
      return const CsvToListConverter().convert(line)[0];
    }).toList();

    if (rows.length <= 1) return 0;

    final existingIds = await _dbManager.repository.getExistingHoldingIds();
    // ดึง account IDs เพื่อเช็ค foreign key (portfolio_id → account.id)
    final existingAccountIds = await _dbManager.repository.getExistingAccountIds();
    
    debugPrint('CSV Import: Found ${existingIds.length} existing holdings');
    debugPrint('CSV Import: Found ${existingAccountIds.length} existing accounts');
    debugPrint('CSV Import: Sample account IDs: ${existingAccountIds.take(5).toList()}');

    final holdings = <StockHolding>[];
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty) continue;

      final id = row[0]?.toString() ?? _uuid.v4();
      final portfolioId = row[1]?.toString() ?? '';
      
      // Skip ถ้า ID ซ้ำ
      if (existingIds.contains(id)) {
        debugPrint('CSV Import: Skipping duplicate holding ID: $id');
        continue;
      }
      
      // Skip ถ้า portfolio_id (account_id) ไม่มีใน database
      if (!existingAccountIds.contains(portfolioId)) {
        debugPrint('CSV Import: Skipping holding $id - portfolio $portfolioId not found');
        continue;
      }

      holdings.add(StockHolding(
        id: id,
        portfolioId: portfolioId,
        ticker: row[2]?.toString() ?? '',
        name: row[3]?.toString() ?? '',
        shares: double.tryParse(row[4]?.toString() ?? '0') ?? 0,
        priceUsd: double.tryParse(row[5]?.toString() ?? '0') ?? 0,
        costBasisUsd: row.length > 6
            ? (double.tryParse(row[6]?.toString() ?? '0') ?? 0)
            : 0,
        sortOrder: row.length > 7
            ? (int.tryParse(row[7]?.toString() ?? '') ?? 0)
            : 0,
      ));
    }

    if (holdings.isNotEmpty) {
      debugPrint('CSV Import: Bulk inserting ${holdings.length} holdings');
      await _dbManager.repository.bulkInsertHoldings(holdings);
    }

    return holdings.length;
  }

  Future<int> _importBudgets(String csvContent) async {
    final lines = csvContent
        .split(RegExp(r'\r?\n'))
        .where((line) => line.trim().isNotEmpty)
        .toList();

    final rows = lines.map((line) {
      return const CsvToListConverter().convert(line)[0];
    }).toList();

    if (rows.length <= 1) return 0;

    final existingIds = await _dbManager.repository.getExistingBudgetIds();
    debugPrint('CSV Import: Found ${existingIds.length} existing budgets');

    final budgets = <Budget>[];
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty) continue;

      final id = row[0]?.toString() ?? _uuid.v4();
      
      if (existingIds.contains(id)) {
        debugPrint('CSV Import: Skipping duplicate budget ID: $id');
        continue;
      }

      final categoryIdsStr = row[3]?.toString() ?? '[]';
      final categoryIds = (jsonDecode(categoryIdsStr) as List<dynamic>)
          .map((e) => e.toString())
          .toList();

      budgets.add(Budget(
        id: id,
        name: row[1]?.toString() ?? 'Unknown',
        amount: double.tryParse(row[2]?.toString() ?? '0') ?? 0,
        categoryIds: categoryIds,
        icon: _parseIcon(int.tryParse(row[4]?.toString() ?? '')),
        color: _parseColor(int.tryParse(row[5]?.toString() ?? '')),
        sortOrder: int.tryParse(row[6]?.toString() ?? '') ?? 0,
      ));
    }

    if (budgets.isNotEmpty) {
      debugPrint('CSV Import: Bulk inserting ${budgets.length} budgets');
      await _dbManager.repository.bulkInsertBudgets(budgets);
    }

    return budgets.length;
  }

  Future<int> _importRecurringTransactions(String csvContent) async {
    final lines = csvContent
        .split(RegExp(r'\r?\n'))
        .where((line) => line.trim().isNotEmpty)
        .toList();

    final rows = lines.map((line) {
      return const CsvToListConverter().convert(line)[0];
    }).toList();

    if (rows.length <= 1) return 0;

    final existingIds = await _dbManager.repository.getExistingRecurringIds();
    // ดึง account IDs เพื่อเช็ค foreign key (account_id → account.id)
    final existingAccountIds = await _dbManager.repository.getExistingAccountIds();
    
    debugPrint('CSV Import: Found ${existingIds.length} existing recurring transactions');
    debugPrint('CSV Import: Found ${existingAccountIds.length} existing accounts');

    final recurring = <RecurringTransaction>[];
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty) continue;

      final id = row[0]?.toString() ?? _uuid.v4();
      final accountId = row[9]?.toString() ?? '';
      
      // Skip ถ้า ID ซ้ำ
      if (existingIds.contains(id)) {
        debugPrint('CSV Import: Skipping duplicate recurring ID: $id');
        continue;
      }
      
      // Skip ถ้า account_id ไม่มีใน database
      if (!existingAccountIds.contains(accountId)) {
        debugPrint('CSV Import: Skipping recurring $id - account $accountId not found');
        continue;
      }

      recurring.add(RecurringTransaction(
        id: id,
        name: row[1]?.toString() ?? 'Unknown',
        icon: _parseIcon(int.tryParse(row[2]?.toString() ?? '')),
        color: _parseColor(int.tryParse(row[3]?.toString() ?? '')),
        startDate: DateTime.tryParse(row[4]?.toString() ?? '') ?? DateTime.now(),
        endDate: row[5]?.toString().isEmpty == true
            ? null
            : DateTime.tryParse(row[5]?.toString() ?? ''),
        dayOfMonth: int.tryParse(row[6]?.toString() ?? '') ?? 1,
        transactionType: parseTransactionType(row[7]?.toString()),
        amount: double.tryParse(row[8]?.toString() ?? '0') ?? 0,
        accountId: accountId,
        toAccountId: row[10]?.toString().isEmpty == true
            ? null
            : row[10]?.toString(),
        categoryId: row[11]?.toString().isEmpty == true
            ? null
            : row[11]?.toString(),
        note: row[12]?.toString(),
        sortOrder: int.tryParse(row[13]?.toString() ?? '') ?? 0,
      ));
    }

    if (recurring.isNotEmpty) {
      debugPrint('CSV Import: Bulk inserting ${recurring.length} recurring transactions');
      await _dbManager.repository.bulkInsertRecurring(recurring);
    }

    return recurring.length;
  }

  Future<int> _importRecurringOccurrences(String csvContent) async {
    final lines = csvContent
        .split(RegExp(r'\r?\n'))
        .where((line) => line.trim().isNotEmpty)
        .toList();

    final rows = lines.map((line) {
      return const CsvToListConverter().convert(line)[0];
    }).toList();

    if (rows.length <= 1) return 0;

    final existingIds = await _dbManager.repository.getExistingOccurrenceIds();
    // ดึง recurring IDs ที่มีอยู่ใน database เพื่อเช็ค foreign key
    final existingRecurringIds = await _dbManager.repository.getExistingRecurringIds();
    
    debugPrint('CSV Import: Found ${existingIds.length} existing occurrences');
    debugPrint('CSV Import: Found ${existingRecurringIds.length} existing recurring transactions');

    final occurrences = <RecurringOccurrence>[];
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty) continue;

      final id = row[0]?.toString() ?? _uuid.v4();
      final recurringId = row[1]?.toString() ?? '';
      
      // Skip ถ้า ID ซ้ำ
      if (existingIds.contains(id)) {
        debugPrint('CSV Import: Skipping duplicate occurrence ID: $id');
        continue;
      }
      
      // Skip ถ้า recurring_id ไม่มีใน database (foreign key constraint)
      if (!existingRecurringIds.contains(recurringId)) {
        debugPrint('CSV Import: Skipping occurrence $id - recurring $recurringId not found');
        continue;
      }

      occurrences.add(RecurringOccurrence(
        id: id,
        recurringId: recurringId,
        dueDate: DateTime.tryParse(row[2]?.toString() ?? '') ?? DateTime.now(),
        transactionId: row[3]?.toString().isEmpty == true
            ? null
            : row[3]?.toString(),
        status: OccurrenceStatus.values.byName(row[4]?.toString() ?? 'done'),
      ));
    }

    if (occurrences.isNotEmpty) {
      debugPrint('CSV Import: Bulk inserting ${occurrences.length} occurrences');
      await _dbManager.repository.bulkInsertOccurrences(occurrences);
    }

    return occurrences.length;
  }
}

/// Result of import operation
class ImportResult {
  final int accountsCount;
  final int categoriesCount;
  final int transactionsCount;
  final int holdingsCount;
  final int budgetsCount;
  final int recurringTransactionsCount;
  final int recurringOccurrencesCount;
  final List<String> errors;
  final bool canceled;

  ImportResult({
    required this.accountsCount,
    required this.categoriesCount,
    required this.transactionsCount,
    required this.errors,
    this.holdingsCount = 0,
    this.budgetsCount = 0,
    this.recurringTransactionsCount = 0,
    this.recurringOccurrencesCount = 0,
    this.canceled = false,
  });

  ImportResult.canceled()
    : accountsCount = 0,
      categoriesCount = 0,
      transactionsCount = 0,
      holdingsCount = 0,
      budgetsCount = 0,
      recurringTransactionsCount = 0,
      recurringOccurrencesCount = 0,
      errors = const [],
      canceled = true;

  bool get hasError => errors.isNotEmpty;
  bool get hasData =>
      accountsCount > 0 ||
      categoriesCount > 0 ||
      transactionsCount > 0 ||
      holdingsCount > 0 ||
      budgetsCount > 0 ||
      recurringTransactionsCount > 0 ||
      recurringOccurrencesCount > 0;

  String get summary {
    if (canceled) return 'ยกเลิก';
    if (hasError && !hasData) return 'นำเข้าไม่สำเร็จ';

    final parts = <String>[];
    if (accountsCount > 0) parts.add('บัญชี $accountsCount รายการ');
    if (categoriesCount > 0) parts.add('หมวดหมู่ $categoriesCount รายการ');
    if (transactionsCount > 0) parts.add('ธุรกรรม $transactionsCount รายการ');
    if (holdingsCount > 0) parts.add('หลักทรัพย์ $holdingsCount รายการ');
    if (budgetsCount > 0) parts.add('งบประมาณ $budgetsCount รายการ');
    if (recurringTransactionsCount > 0) {
      parts.add('รายการประจำ $recurringTransactionsCount รายการ');
    }
    if (recurringOccurrencesCount > 0) {
      parts.add('การเกิดรายการ $recurringOccurrencesCount รายการ');
    }

    var result = parts.join(' | ');
    if (hasError) {
      result += '\n\nข้อผิดพลาด:\n${errors.join('\n')}';
    }
    return result;
  }
}
