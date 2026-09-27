import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';

import '../models/fixed_cash_flow_item.dart';
import '../models/investment_plan.dart';
import '../models/planned_purchase.dart';
import '../models/portfolio_annual_report.dart';
import '../models/stock_purchase.dart';
import '../repositories/database_repository.dart';

/// ชนิดของค่าในคอลัมน์ ใช้แปลงข้อความจาก CSV กลับเป็นชนิดที่ `fromMap` ต้องการ
enum CsvCell { text, integer, number, boolean }

/// ผลการนำเข้าของโมดูลหนึ่ง
class CsvModuleImport {
  final int imported;
  final int failed;

  const CsvModuleImport({required this.imported, required this.failed});
}

/// ตารางที่ backup เป็นไฟล์ CSV แยก โดยใช้ key จาก `toMap`/`fromMap` ของ model เป็นหัวคอลัมน์
/// นำเข้าแบบข้ามรายการที่มี id อยู่แล้ว เหมือนตารางอื่นใน [CsvService]
class CsvBackupModule<T> {
  /// ชื่อไฟล์ตอน export (`<fileKey>_<timestamp>.csv`) และใช้จับคู่ไฟล์ตอน import
  final String fileKey;

  /// ชื่อที่แสดงในสรุปผลการนำเข้า
  final String label;

  /// คอลัมน์ทั้งหมดตามลำดับในไฟล์
  final Map<String, CsvCell> columns;

  final Future<List<T>> Function(DatabaseRepository repo) load;
  final Map<String, dynamic> Function(T item) toMap;
  final T Function(Map<String, dynamic> map) fromMap;
  final String Function(T item) idOf;
  final Future<void> Function(DatabaseRepository repo, T item) insert;

  const CsvBackupModule({
    required this.fileKey,
    required this.label,
    required this.columns,
    required this.load,
    required this.toMap,
    required this.fromMap,
    required this.idOf,
    required this.insert,
  });

  bool matchesFile(String lowerCaseFileName) =>
      lowerCaseFileName.startsWith('${fileKey}_');

  Future<String> exportCsv(DatabaseRepository repo) async {
    final items = await load(repo);
    final rows = <List<dynamic>>[
      columns.keys.toList(),
      for (final map in items.map(toMap))
        [for (final key in columns.keys) map[key] ?? ''],
    ];
    return const ListToCsvConverter().convert(rows);
  }

  Future<CsvModuleImport> importCsv(
    DatabaseRepository repo,
    String content,
  ) async {
    // ไม่ parse ตัวเลขอัตโนมัติ เพื่อให้ข้อความอย่างชื่อ "123" ยังเป็น String
    final rows = const CsvToListConverter(
      shouldParseNumbers: false,
      eol: '\n',
    ).convert(content.replaceAll('\r\n', '\n'));
    if (rows.length <= 1) {
      return const CsvModuleImport(imported: 0, failed: 0);
    }

    final header = rows.first.map((h) => h.toString().trim()).toList();
    final existingIds = (await load(repo)).map(idOf).toSet();
    var imported = 0;
    var failed = 0;

    for (final row in rows.skip(1)) {
      if (row.every((cell) => cell.toString().isEmpty)) continue;
      try {
        final item = fromMap(_rowToMap(header, row));
        if (existingIds.contains(idOf(item))) continue;
        await insert(repo, item);
        imported++;
      } catch (e) {
        debugPrint('CSV Import: Failed $fileKey row $row: $e');
        failed++;
      }
    }
    return CsvModuleImport(imported: imported, failed: failed);
  }

  /// จับคู่ตามชื่อหัวคอลัมน์ คอลัมน์ที่ไม่มีในไฟล์ (backup เก่า) ได้ค่า null
  Map<String, dynamic> _rowToMap(List<String> header, List<dynamic> row) {
    final map = <String, dynamic>{};
    for (final entry in columns.entries) {
      final index = header.indexOf(entry.key);
      final raw = index >= 0 && index < row.length ? row[index].toString() : '';
      map[entry.key] = _parseCell(raw, entry.value);
    }
    return map;
  }

  static Object? _parseCell(String raw, CsvCell type) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    return switch (type) {
      CsvCell.text => raw,
      CsvCell.integer => int.tryParse(value),
      CsvCell.number => double.tryParse(value),
      CsvCell.boolean => value.toLowerCase() == 'true' || value == '1',
    };
  }
}

/// ตารางที่ backup ผ่าน [CsvBackupModule] เรียงตามลำดับ import
/// (ทั้งหมดขึ้นกับ accounts/holdings จึง import หลังตารางหลักใน [CsvService];
/// paid marks ต้องมาหลังรายการเงินเข้าออก)
final List<CsvBackupModule<Object>> csvBackupModules = [
  CsvBackupModule<StockPurchase>(
    fileKey: 'stock_purchases',
    label: 'ประวัติซื้อหุ้น',
    columns: const {
      'id': CsvCell.text,
      'portfolio_id': CsvCell.text,
      'holding_id': CsvCell.text,
      'ticker': CsvCell.text,
      'name': CsvCell.text,
      'logo_url': CsvCell.text,
      'shares_bought': CsvCell.number,
      'buy_price_usd': CsvCell.number,
      'cash_paid_usd': CsvCell.number,
      'gross_cost_usd': CsvCell.number,
      'broker_fee_usd': CsvCell.number,
      'exchange_fee_usd': CsvCell.number,
      'tax_fee_usd': CsvCell.number,
      'bought_at': CsvCell.text,
      'created_at': CsvCell.text,
    },
    load: (repo) => repo.getStockPurchases(),
    toMap: (p) => p.toMap(),
    fromMap: StockPurchase.fromMap,
    idOf: (p) => p.id,
    insert: (repo, p) => repo.insertStockPurchase(p),
  ),
  CsvBackupModule<PortfolioAnnualReport>(
    fileKey: 'portfolio_annual_reports',
    label: 'รายงานพอร์ตรายปี',
    columns: const {
      'id': CsvCell.text,
      'portfolio_id': CsvCell.text,
      'year': CsvCell.integer,
      'inflow_usd': CsvCell.number,
      'inflow_thb': CsvCell.number,
      'dividend_gross_usd': CsvCell.number,
      'dividend_tax_withheld_usd': CsvCell.number,
      'dividend_net_usd': CsvCell.number,
      'remitted_usd': CsvCell.number,
      'remitted_thb': CsvCell.number,
      'note': CsvCell.text,
      'created_at': CsvCell.text,
    },
    load: (repo) => repo.getPortfolioAnnualReports(),
    toMap: (r) => r.toMap(),
    fromMap: PortfolioAnnualReport.fromMap,
    idOf: (r) => r.id,
    insert: (repo, r) => repo.insertPortfolioAnnualReport(r),
  ),
  CsvBackupModule<InvestmentPlanMonthStatus>(
    fileKey: 'investment_plan_months',
    label: 'สถานะ DCA รายเดือน',
    columns: const {
      'id': CsvCell.text,
      'portfolio_id': CsvCell.text,
      'dca_month': CsvCell.text,
      'dca_completed': CsvCell.boolean,
    },
    load: (repo) => repo.getInvestmentPlanMonthStatuses(),
    toMap: (s) => s.toMap(),
    fromMap: InvestmentPlanMonthStatus.fromMap,
    idOf: (s) => s.id,
    insert: (repo, s) => repo.upsertInvestmentPlanMonthStatus(s),
  ),
  CsvBackupModule<PortfolioAllocationTarget>(
    fileKey: 'allocation_targets',
    label: 'สัดส่วนเป้าหมายพอร์ต',
    columns: const {
      'id': CsvCell.text,
      'portfolio_id': CsvCell.text,
      'holding_id': CsvCell.text,
      'ticker': CsvCell.text,
      'target_percent': CsvCell.number,
      'is_enabled': CsvCell.boolean,
      'sort_order': CsvCell.integer,
    },
    load: (repo) => repo.getPortfolioAllocationTargets(),
    toMap: (t) => t.toMap(),
    fromMap: PortfolioAllocationTarget.fromMap,
    idOf: (t) => t.id,
    insert: (repo, t) => repo.upsertPortfolioAllocationTarget(t),
  ),
  CsvBackupModule<FixedCashFlowItem>(
    fileKey: 'cash_flow_items',
    label: 'รายการเงินเข้าออก',
    columns: const {
      'id': CsvCell.text,
      'name': CsvCell.text,
      'amount': CsvCell.number,
      'day_of_month': CsvCell.integer,
      'one_time_on': CsvCell.text,
      'direction': CsvCell.text,
      'sort_order': CsvCell.integer,
    },
    load: (repo) => repo.getFixedCashFlowItems(),
    toMap: (i) => i.toMap(),
    fromMap: FixedCashFlowItem.fromMap,
    idOf: (i) => i.id,
    insert: (repo, i) => repo.insertFixedCashFlowItem(i),
  ),
  CsvBackupModule<FixedCashFlowPaidMark>(
    fileKey: 'cash_flow_paid_marks',
    label: 'การติ๊กเงินเข้าออก',
    columns: const {
      'id': CsvCell.text,
      'item_id': CsvCell.text,
      'month': CsvCell.text,
    },
    load: (repo) => repo.getFixedCashFlowPaidMarks(),
    toMap: (m) => m.toMap(),
    fromMap: FixedCashFlowPaidMark.fromMap,
    idOf: (m) => m.id,
    insert: (repo, m) => repo.upsertFixedCashFlowPaidMark(m),
  ),
  CsvBackupModule<PlannedPurchase>(
    fileKey: 'planned_purchases',
    label: 'รายการอยากซื้อ',
    columns: const {
      'id': CsvCell.text,
      'name': CsvCell.text,
      'amount': CsvCell.number,
      'is_included': CsvCell.boolean,
      'sort_order': CsvCell.integer,
    },
    load: (repo) => repo.getPlannedPurchases(),
    toMap: (p) => p.toMap(),
    fromMap: PlannedPurchase.fromMap,
    idOf: (p) => p.id,
    insert: (repo, p) => repo.insertPlannedPurchase(p),
  ),
];
