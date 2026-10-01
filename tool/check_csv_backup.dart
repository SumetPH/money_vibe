import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';

import 'package:money_vibe/utils/csv_backup_archive.dart';

// Run: dart --enable-asserts run tool/check_csv_backup.dart
void main() {
  final files = {
    for (var i = 0; i < 12; i++)
      'module_${i}_123.csv': 'id,name\n$i,"ทดสอบ, CSV"',
    'cash_flow_items_123.csv': 'id,name\n1,เงินเดือน',
    'cash_flow_paid_marks_123.csv': 'item_id,month\n1,2026-10',
    'planned_purchases_123.csv': 'id,name\n1,อยากซื้อ',
  };
  final decoded = ZipDecoder().decodeBytes(
    encodeCsvBackup(files),
    verify: true,
  );
  assert(decoded.length == 15);
  for (final entry in files.entries) {
    final file = decoded.findFile(entry.key);
    assert(file != null, 'Missing ${entry.key}');
    assert(utf8.decode(file!.content) == entry.value, 'Changed ${entry.key}');
  }
  stdout.writeln(
    'CSV backup check passed: all 15 files preserved, including Thai text.',
  );
}
