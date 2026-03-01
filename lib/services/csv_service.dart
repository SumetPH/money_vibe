import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../database/database_helper.dart';

class CsvService {
  static final CsvService instance = CsvService._();
  CsvService._();

  final _uuid = const Uuid();

  /// Export all data to CSV files and share them
  /// [sharePositionOrigin] ใช้บน iPad เพื่อกำหนดตำแหน่ง popover
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
    final transactionsFile = File('${tempDir.path}/transactions_$timestamp.csv');
    final transactionsCsv = await _exportTransactions();
    await transactionsFile.writeAsString(transactionsCsv, encoding: utf8);

    // Share all files
    final files = [
      XFile(accountsFile.path),
      XFile(categoriesFile.path),
      XFile(transactionsFile.path),
    ];

    await Share.shareXFiles(
      files,
      subject: 'Money App Backup ${DateTime.now().toString().split('.')[0]}',
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  /// Import data from CSV files
  /// Returns summary of import result
  Future<ImportResult> importFromCsv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      allowMultiple: true,
    );

    if (result == null || result.files.isEmpty) {
      return ImportResult.canceled();
    }

    int accountsCount = 0;
    int categoriesCount = 0;
    int transactionsCount = 0;
    List<String> errors = [];

    for (final file in result.files) {
      if (file.path == null) continue;

      final content = await File(file.path!).readAsString(encoding: utf8);
      final filename = file.name.toLowerCase();

      debugPrint('CSV Service: Processing file: ${file.name}');

      try {
        if (filename.contains('account')) {
          debugPrint('CSV Service: Detected as ACCOUNTS file');
          accountsCount = await _importAccounts(content);
        } else if (filename.contains('categor')) {  // รองรับทั้ง category และ categories
          debugPrint('CSV Service: Detected as CATEGORIES file');
          categoriesCount = await _importCategories(content);
        } else if (filename.contains('transaction')) {
          debugPrint('CSV Service: Detected as TRANSACTIONS file');
          transactionsCount = await _importTransactions(content);
        } else {
          debugPrint('CSV Service: Unknown file type, skipping');
        }
      } catch (e) {
        debugPrint('CSV Service: Error processing ${file.name}: $e');
        errors.add('${file.name}: $e');
      }
    }

    debugPrint('CSV Service: Import complete - Accounts: $accountsCount, Categories: $categoriesCount, Transactions: $transactionsCount');
    return ImportResult(
      accountsCount: accountsCount,
      categoriesCount: categoriesCount,
      transactionsCount: transactionsCount,
      errors: errors,
    );
  }

  // ========== Export Methods ==========

  Future<String> _exportAccounts() async {
    final accounts = await DatabaseHelper.instance.getAccounts();
    
    final rows = <List<dynamic>>[
      // Header
      ['id', 'name', 'type', 'initial_balance', 'currency', 'start_date', 'icon', 'color', 'exclude_from_net_worth', 'is_hidden', 'sort_order'],
    ];

    for (final map in accounts) {
      rows.add([
        map['id'],
        map['name'],
        map['type'],
        map['initial_balance'],
        map['currency'],
        map['start_date'],
        map['icon'],
        map['color'],
        map['exclude_from_net_worth'],
        map['is_hidden'],
        map['sort_order'],
      ]);
    }

    return const ListToCsvConverter().convert(rows);
  }

  Future<String> _exportCategories() async {
    final categories = await DatabaseHelper.instance.getCategories();
    
    final rows = <List<dynamic>>[
      // Header
      ['id', 'name', 'type', 'icon', 'color', 'parent_id', 'note', 'sort_order'],
    ];

    for (final map in categories) {
      rows.add([
        map['id'],
        map['name'],
        map['type'],
        map['icon'],
        map['color'],
        map['parent_id'] ?? '',
        map['note'] ?? '',
        map['sort_order'],
      ]);
    }

    return const ListToCsvConverter().convert(rows);
  }

  Future<String> _exportTransactions() async {
    final transactions = await DatabaseHelper.instance.getTransactions();
    
    final rows = <List<dynamic>>[
      // Header
      ['id', 'type', 'amount', 'account_id', 'category_id', 'to_account_id', 'date_time', 'note', 'tags'],
    ];

    for (final map in transactions) {
      rows.add([
        map['id'],
        map['type'],
        map['amount'],
        map['account_id'],
        map['category_id'] ?? '',
        map['to_account_id'] ?? '',
        map['date_time'],
        map['note'] ?? '',
        map['tags'] ?? '[]',
      ]);
    }

    return const ListToCsvConverter().convert(rows);
  }

  // ========== Import Methods ==========

  Future<int> _importAccounts(String csvContent) async {
    final rows = const CsvToListConverter().convert(csvContent);
    if (rows.length <= 1) return 0; // Only header or empty

    int count = 0;
    // Skip header row
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty) continue;

      final data = {
        'id': row[0]?.toString() ?? _uuid.v4(),
        'name': row[1]?.toString() ?? 'Unknown',
        'type': row[2]?.toString() ?? 'cash',
        'initial_balance': double.tryParse(row[3]?.toString() ?? '0') ?? 0,
        'currency': row[4]?.toString() ?? 'THB',
        'start_date': int.tryParse(row[5]?.toString() ?? '') ?? DateTime.now().millisecondsSinceEpoch,
        'icon': int.tryParse(row[6]?.toString() ?? '') ?? 0xe8a6, // default icon
        'color': int.tryParse(row[7]?.toString() ?? '') ?? 0xFF607D8B,
        'exclude_from_net_worth': int.tryParse(row[8]?.toString() ?? '') ?? 0,
        'is_hidden': int.tryParse(row[9]?.toString() ?? '') ?? 0,
        'sort_order': int.tryParse(row[10]?.toString() ?? '') ?? 0,
      };

      await DatabaseHelper.instance.insertAccount(data);
      count++;
    }

    return count;
  }

  Future<int> _importCategories(String csvContent) async {
    final rows = const CsvToListConverter().convert(csvContent);
    if (rows.length <= 1) {
      debugPrint('CSV Service: No category data rows found');
      return 0;
    }

    debugPrint('CSV Service: Importing ${rows.length - 1} categories');
    int count = 0;
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty) continue;

      debugPrint('CSV Service: Row $i - $row');

      final data = {
        'id': row[0]?.toString() ?? _uuid.v4(),
        'name': row[1]?.toString() ?? 'Unknown',
        'type': row[2]?.toString() ?? 'expense',
        'icon': int.tryParse(row[3]?.toString() ?? '') ?? 0xe8a6,
        'color': int.tryParse(row[4]?.toString() ?? '') ?? 0xFF607D8B,
        'parent_id': row[5]?.toString().isEmpty == true ? null : row[5]?.toString(),
        'note': row[6]?.toString() ?? '',
        'sort_order': int.tryParse(row[7]?.toString() ?? '') ?? 0,
      };

      debugPrint('CSV Service: Inserting category: ${data['id']} - ${data['name']}');
      await DatabaseHelper.instance.insertCategory(data);
      count++;
    }

    debugPrint('CSV Service: Imported $count categories');
    return count;
  }

  Future<int> _importTransactions(String csvContent) async {
    final rows = const CsvToListConverter().convert(csvContent);
    if (rows.length <= 1) return 0;

    int count = 0;
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty) continue;

      // Validate tags format
      var tags = row[8]?.toString() ?? '[]';
      if (!tags.startsWith('[')) {
        // Convert old comma-separated to JSON array
        final tagList = tags.split(',').where((t) => t.isNotEmpty).toList();
        tags = jsonEncode(tagList);
      }

      final data = {
        'id': row[0]?.toString() ?? _uuid.v4(),
        'type': row[1]?.toString() ?? 'expense',
        'amount': double.tryParse(row[2]?.toString() ?? '0') ?? 0,
        'account_id': row[3]?.toString() ?? '',
        'category_id': row[4]?.toString().isEmpty == true ? null : row[4]?.toString(),
        'to_account_id': row[5]?.toString().isEmpty == true ? null : row[5]?.toString(),
        'date_time': int.tryParse(row[6]?.toString() ?? '') ?? DateTime.now().millisecondsSinceEpoch,
        'note': row[7]?.toString() ?? '',
        'tags': tags,
        // Fields not in CSV but in DB
        'payee': '',
        'location': '',
        'is_cleared': 0,
        'record_date': null,
      };

      await DatabaseHelper.instance.insertTransaction(data);
      count++;
    }

    return count;
  }
}

/// Result of import operation
class ImportResult {
  final int accountsCount;
  final int categoriesCount;
  final int transactionsCount;
  final List<String> errors;
  final bool canceled;

  ImportResult({
    required this.accountsCount,
    required this.categoriesCount,
    required this.transactionsCount,
    required this.errors,
    this.canceled = false,
  });

  ImportResult.canceled()
      : accountsCount = 0,
        categoriesCount = 0,
        transactionsCount = 0,
        errors = const [],
        canceled = true;

  bool get hasError => errors.isNotEmpty;
  bool get hasData => accountsCount > 0 || categoriesCount > 0 || transactionsCount > 0;

  String get summary {
    if (canceled) return 'ยกเลิก';
    if (hasError && !hasData) return 'นำเข้าไม่สำเร็จ';
    
    final parts = <String>[];
    if (accountsCount > 0) parts.add('บัญชี $accountsCount รายการ');
    if (categoriesCount > 0) parts.add('หมวดหมู่ $categoriesCount รายการ');
    if (transactionsCount > 0) parts.add('ธุรกรรม $transactionsCount รายการ');
    
    var result = parts.join(' | ');
    if (hasError) {
      result += '\n\nข้อผิดพลาด:\n${errors.join('\n')}';
    }
    return result;
  }
}
