import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../repositories/database_repository.dart';
import 'settings_provider.dart';
import '../services/database_manager.dart';
import '../services/stock_price_service.dart';
import '../models/account.dart';
import '../models/stock_holding.dart';
import '../models/stock_trade.dart';
import '../models/transaction.dart';
import '../models/portfolio_annual_report.dart';

class AccountProvider extends ChangeNotifier {
  final _uuid = const Uuid();
  final DatabaseManager _dbManager = DatabaseManager();
  final SettingsProvider? _settingsProvider;

  AccountProvider({SettingsProvider? settingsProvider})
    : _settingsProvider = settingsProvider;

  final List<Account> _accounts = [];
  final Map<String, List<StockHolding>> _holdings =
      {}; // portfolioId → holdings
  final List<StockTrade> _stockTrades = [];
  final List<PortfolioAnnualReport> _portfolioAnnualReports = [];

  bool _showHiddenAccounts = false;
  bool _isLoading = false;

  bool get showHiddenAccounts => _showHiddenAccounts;
  bool get isLoading => _isLoading;

  void toggleShowHiddenAccounts() {
    _showHiddenAccounts = !_showHiddenAccounts;
    notifyListeners();
  }

  // ── Helper ────────────────────────────────────────────────────────────────

  DatabaseRepository get _db => _dbManager.repository;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> init() async {
    debugPrint('AccountProvider: Initializing...');
    _setLoading(true);

    try {
      final accounts = await _db.getAccounts();
      // Sort by sortOrder to ensure correct order
      accounts.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      _accounts.clear();
      _accounts.addAll(accounts);

      final holdings = await _db.getPortfolioHoldings();
      final stockTrades = await _db.getStockTrades();
      final annualReports = await _db.getPortfolioAnnualReports();
      _holdings.clear();
      for (final holding in holdings) {
        _holdings.putIfAbsent(holding.portfolioId, () => []).add(holding);
      }
      // Sort holdings in each portfolio by sortOrder
      for (final portfolioId in _holdings.keys) {
        _holdings[portfolioId]!.sort(
          (a, b) => a.sortOrder.compareTo(b.sortOrder),
        );
      }
      _stockTrades
        ..clear()
        ..addAll(stockTrades)
        ..sort((a, b) => b.soldAt.compareTo(a.soldAt));
      _portfolioAnnualReports
        ..clear()
        ..addAll(annualReports)
        ..sort((a, b) => b.year.compareTo(a.year));

      debugPrint(
        'AccountProvider: Loaded ${_accounts.length} accounts, ${holdings.length} holdings, ${stockTrades.length} stock trades, ${annualReports.length} annual reports',
      );

      // Auto-update exchangeRate เฉพาะ account ที่ currency == 'USD' และ autoUpdateRate == true
      await _refreshUsdExchangeRate();
    } catch (e) {
      debugPrint('AccountProvider: Init error: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Reload accounts from database (used after restore/mode switch)
  Future<void> reload() async {
    debugPrint('AccountProvider: Reloading...');
    return init(); // Same logic
  }

  /// Fetch USD/THB rate และ update เฉพาะ USD accounts ที่มี autoUpdateRate == true
  Future<void> _refreshUsdExchangeRate() async {
    final usdAccounts = _accounts
        .where((a) => a.currency == 'USD' && a.autoUpdateRate)
        .toList();
    if (usdAccounts.isEmpty) return;

    try {
      final rate = await StockPriceService(
        exchangeRateSource:
            _settingsProvider?.exchangeRateSource ?? ExchangeRateSource.yahoo,
      ).fetchUsdThbRate();
      debugPrint('AccountProvider: USD/THB rate fetched: $rate');
      // fetch ครั้งเดียว แล้ว apply ให้ทุก USD account
      for (final acc in usdAccounts) {
        final updated = acc.copyWith(exchangeRate: rate);
        final idx = _accounts.indexWhere((a) => a.id == acc.id);
        if (idx != -1) _accounts[idx] = updated;
        await _db.updateAccount(updated);
      }
      notifyListeners();
    } catch (e) {
      // Silently fail — ใช้ rate เก่าต่อไป (offline-safe)
      debugPrint('AccountProvider: Failed to fetch USD/THB rate: $e');
    }
  }

  // ── Getters ───────────────────────────────────────────────────────────────

  List<Account> get accounts => List.unmodifiable(_accounts);

  List<Account> get visibleAccounts {
    if (_showHiddenAccounts) {
      return List.unmodifiable(_accounts);
    }
    return _accounts.where((a) => !a.isHidden).toList();
  }

  List<Account> get debtAccounts => _accounts
      .where(
        (a) =>
            (a.type == AccountType.debt || a.type == AccountType.creditCard) &&
            !a.isHidden,
      )
      .toList();

  Account? findById(String id) {
    try {
      return _accounts.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  List<StockHolding> getHoldings(String portfolioId) =>
      List.unmodifiable(_holdings[portfolioId] ?? []);

  List<StockTrade> get stockTrades => List.unmodifiable(_stockTrades);

  List<StockTrade> getStockTradesForPortfolio(String portfolioId) =>
      List.unmodifiable(
        _stockTrades.where((trade) => trade.portfolioId == portfolioId),
      );

  List<PortfolioAnnualReport> get portfolioAnnualReports =>
      List.unmodifiable(_portfolioAnnualReports);

  List<PortfolioAnnualReport> getPortfolioAnnualReportsForPortfolio(
    String portfolioId,
  ) => List.unmodifiable(
    _portfolioAnnualReports.where((r) => r.portfolioId == portfolioId),
  );

  Future<void> addPortfolioAnnualReport(PortfolioAnnualReport report) async {
    _validatePortfolioAnnualReport(report);

    await _db.insertPortfolioAnnualReport(report);
    _portfolioAnnualReports.add(report);
    _portfolioAnnualReports.sort((a, b) => b.year.compareTo(a.year));
    notifyListeners();
  }

  Future<void> updatePortfolioAnnualReport(PortfolioAnnualReport report) async {
    _validatePortfolioAnnualReport(report);

    await _db.updatePortfolioAnnualReport(report);
    final idx = _portfolioAnnualReports.indexWhere((r) => r.id == report.id);
    if (idx != -1) {
      _portfolioAnnualReports[idx] = report;
      _portfolioAnnualReports.sort((a, b) => b.year.compareTo(a.year));
      notifyListeners();
    }
  }

  Future<void> deletePortfolioAnnualReport(String id) async {
    await _db.deletePortfolioAnnualReport(id);
    _portfolioAnnualReports.removeWhere((r) => r.id == id);
    notifyListeners();
  }

  double getRemainingPrincipalPool(
    String portfolioId,
    List<AppTransaction> transactions, {
    int? targetYear,
  }) {
    final portfolio = findById(portfolioId);
    if (portfolio == null) return 0.0;

    // Hybrid Logic: Calculate Total Inflows (Deposits) to the portfolio
    // 1. Get annual reports for this portfolio
    final annualReports = getPortfolioAnnualReportsForPortfolio(portfolioId)
        .where((report) => targetYear == null || report.year <= targetYear)
        .toList();
    final reportedYears = annualReports.map((r) => r.year).toSet();

    double totalInflows = portfolio.initialBalance;

    // 2. Add inflows from annual reports
    for (final report in annualReports) {
      totalInflows += report.inflowUsd;
    }

    // 3. Add inflows from transactions ONLY for years NOT in reportedYears
    for (final tx in transactions) {
      if (targetYear != null && tx.dateTime.year > targetYear) continue;
      if (reportedYears.contains(tx.dateTime.year)) continue;

      if (tx.toAccountId == portfolioId && tx.type.usesDestinationAccount) {
        if (tx.toAmount != null && tx.toAmount! > 0) {
          totalInflows += tx.toAmount!;
        } else {
          final sourceAcc = findById(tx.accountId);
          if (sourceAcc != null && sourceAcc.currency != portfolio.currency) {
            // Fallback: convert using current exchange rate if missing
            final rate = portfolio.exchangeRate > 0
                ? portfolio.exchangeRate
                : 35.0;
            totalInflows += tx.amount / rate;
          } else {
            totalInflows += tx.amount;
          }
        }
      } else if (tx.accountId == portfolioId &&
          tx.type == TransactionType.increaseBalance) {
        totalInflows += tx.amount;
      }
    }

    // 2. Calculate Total Remitted from annual broker reports.
    final totalRemitted = annualReports.fold(
      0.0,
      (sum, report) => sum + report.remittedUsd,
    );

    final totalPrincipalRepatriated = totalRemitted > totalInflows
        ? totalInflows
        : totalRemitted;
    double remaining = totalInflows - totalPrincipalRepatriated;
    return remaining < 0 ? 0.0 : remaining;
  }

  String resolveStockLogoUrl({
    required String portfolioId,
    required String ticker,
    String fallback = '',
  }) {
    if (fallback.trim().isNotEmpty) return fallback.trim();
    final normalizedTicker = ticker.trim().toUpperCase();
    if (normalizedTicker.isEmpty) return '';

    final portfolioHoldings = _holdings[portfolioId] ?? const <StockHolding>[];
    for (final holding in portfolioHoldings) {
      if (holding.ticker.trim().toUpperCase() == normalizedTicker &&
          holding.logoUrl.trim().isNotEmpty) {
        return holding.logoUrl.trim();
      }
    }

    for (final holdings in _holdings.values) {
      for (final holding in holdings) {
        if (holding.ticker.trim().toUpperCase() == normalizedTicker &&
            holding.logoUrl.trim().isNotEmpty) {
          return holding.logoUrl.trim();
        }
      }
    }

    return '';
  }

  // ── Balance computation ───────────────────────────────────────────────────

  double getBalance(String accountId, List<AppTransaction> transactions) {
    final account = findById(accountId);
    if (account == null) return 0;

    // Portfolio: balance = cash balance + holdings value in the portfolio currency
    if (account.isPortfolio) {
      double total = account.cashBalance;
      for (final h in (_holdings[accountId] ?? [])) {
        total += h.shares * h.priceUsd;
      }
      return total;
    }

    // Regular accounts: computed from transactions (in account's native currency)
    double balance = account.initialBalance;

    for (final tx in transactions) {
      if (tx.accountId == accountId) {
        if (tx.type == TransactionType.income ||
            tx.type == TransactionType.increaseBalance) {
          balance += tx.amount;
        }
        if (tx.type != TransactionType.income &&
            tx.type != TransactionType.increaseBalance) {
          balance -= tx.amount;
        }
      }
      // destination account: ใช้ toAmount ถ้ามี (cross-currency) ไม่งั้นใช้ amount เดิม
      if (tx.toAccountId == accountId && tx.type.usesDestinationAccount) {
        balance += tx.toAmount ?? tx.amount;
      }
    }

    return balance;
  }

  /// คืนค่า balance แปลงเป็น THB เสมอ (สำหรับ net worth และ group totals)
  double getBalanceInThb(String accountId, List<AppTransaction> transactions) {
    final account = findById(accountId);
    if (account == null) return 0;
    final balance = getBalance(accountId, transactions);
    // USD accounts convert with exchangeRate; THB portfolios already stay in THB
    if (account.currency == 'USD') {
      return balance * account.exchangeRate;
    }
    return balance;
  }

  double getTotalNetWorth(
    List<AppTransaction> transactions, {
    Set<String>? filterIds,
  }) {
    return _accounts
        .where(
          (a) =>
              !a.excludeFromNetWorth &&
              (filterIds == null || filterIds.contains(a.id)),
        )
        .fold(0.0, (sum, a) => sum + getBalanceInThb(a.id, transactions));
  }

  Map<String, double> getGroupTotals(List<AppTransaction> transactions) {
    final Map<String, double> totals = {};
    final accountsToShow = _showHiddenAccounts
        ? _accounts
        : _accounts.where((a) => !a.isHidden);
    for (final account in accountsToShow) {
      final group = accountTypeDisplayGroup(account.type);
      totals[group] =
          (totals[group] ?? 0) + getBalanceInThb(account.id, transactions);
    }
    return totals;
  }

  // ── Account CRUD ──────────────────────────────────────────────────────────

  Future<void> addAccount(Account account) async {
    // Calculate new sortOrder (max + 10)
    final sortOrder = _accounts.isEmpty
        ? 0
        : (_accounts.map((a) => a.sortOrder).reduce((a, b) => a > b ? a : b) +
              10);
    final updated = account.copyWith(sortOrder: sortOrder);

    _accounts.add(updated);
    // Keep list sorted in memory
    _accounts.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    notifyListeners();

    try {
      await _db.insertAccount(updated);
    } catch (e) {
      debugPrint('AccountProvider: Error adding account: $e');
      _accounts.removeWhere((a) => a.id == updated.id);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateAccount(Account updated) async {
    final idx = _accounts.indexWhere((a) => a.id == updated.id);
    if (idx == -1) return;

    final oldAccount = _accounts[idx];
    _accounts[idx] = updated;
    // Keep list sorted in memory
    _accounts.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    notifyListeners();

    try {
      await _db.updateAccount(updated);
    } catch (e) {
      debugPrint('AccountProvider: Error updating account: $e');
      _accounts[idx] = oldAccount;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteAccount(String id) async {
    final idx = _accounts.indexWhere((a) => a.id == id);
    if (idx == -1) return;

    final oldAccount = _accounts[idx];
    final oldHoldings = _holdings[id]?.toList() ?? [];

    _accounts.removeAt(idx);
    _holdings.remove(id);
    notifyListeners();

    try {
      await _db.deleteAccount(id);
      await _db.deleteHoldingsByPortfolio(id);
    } catch (e) {
      debugPrint('AccountProvider: Error deleting account: $e');
      _accounts.insert(idx, oldAccount);
      _holdings[id] = oldHoldings;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> reorderAccounts(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final account = _accounts.removeAt(oldIndex);
    _accounts.insert(newIndex, account);

    // Update sort order for all affected accounts
    for (int i = 0; i < _accounts.length; i++) {
      _accounts[i] = _accounts[i].copyWith(sortOrder: i * 10);
    }
    notifyListeners();

    try {
      for (int i = 0; i < _accounts.length; i++) {
        await _db.updateAccountSortOrder(
          _accounts[i].id,
          _accounts[i].sortOrder,
        );
      }
    } catch (e) {
      debugPrint('AccountProvider: Error reordering accounts: $e');
      // Note: Full rollback is complex, just reload on error
      await reload();
      rethrow;
    }
  }

  Future<void> reorderAccountsInGroup(
    String groupName,
    int oldIndex,
    int newIndex,
  ) async {
    // Get visible accounts
    final visible = visibleAccounts;

    // Get accounts in this group
    final groupAccounts = visible
        .where((a) => accountTypeDisplayGroup(a.type) == groupName)
        .toList();

    if (groupAccounts.isEmpty) return;
    if (oldIndex < 0 || oldIndex >= groupAccounts.length) return;

    // Adjust newIndex for ReorderableListView behavior
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    // Clamp to valid range
    if (newIndex < 0) newIndex = 0;
    if (newIndex >= groupAccounts.length) newIndex = groupAccounts.length - 1;

    // If same position, nothing to do
    if (oldIndex == newIndex) return;

    // Find the account being moved
    final movedAccount = groupAccounts[oldIndex];

    // Find target account (where to insert after)
    final targetAccount = groupAccounts[newIndex];

    // Find actual indices in _accounts
    final actualOldIndex = _accounts.indexWhere((a) => a.id == movedAccount.id);
    final actualTargetIndex = _accounts.indexWhere(
      (a) => a.id == targetAccount.id,
    );

    if (actualOldIndex == -1 || actualTargetIndex == -1) return;

    // Calculate new index (after the target)
    var actualNewIndex = actualTargetIndex;
    if (actualOldIndex < actualNewIndex) {
      actualNewIndex += 1;
    }

    // Perform the reorder
    await reorderAccounts(actualOldIndex, actualNewIndex);
  }

  // ── Holdings CRUD ──────────────────────────────────────────────────────────

  Future<void> addHolding(StockHolding holding) async {
    final list = _holdings.putIfAbsent(holding.portfolioId, () => []);

    // Calculate new sortOrder (max + 10) for this portfolio
    final sortOrder = list.isEmpty
        ? 0
        : (list.map((h) => h.sortOrder).reduce((a, b) => a > b ? a : b) + 10);
    final updated = holding.copyWith(sortOrder: sortOrder);

    list.add(updated);
    // Keep list sorted in memory
    list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    notifyListeners();

    try {
      await _db.insertHolding(updated);
    } catch (e) {
      debugPrint('AccountProvider: Error adding holding: $e');
      _holdings[holding.portfolioId]?.removeWhere((h) => h.id == updated.id);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateHolding(StockHolding updated) async {
    final list = _holdings[updated.portfolioId];
    if (list == null) return;

    final idx = list.indexWhere((h) => h.id == updated.id);
    if (idx == -1) return;

    final oldHolding = list[idx];
    list[idx] = updated;
    // Keep list sorted in memory
    list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    notifyListeners();

    try {
      await _db.updateHolding(updated);
    } catch (e) {
      debugPrint('AccountProvider: Error updating holding: $e');
      list[idx] = oldHolding;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateHoldingsBatch(List<StockHolding> holdings) async {
    if (holdings.isEmpty) return;
    final portfolioId = holdings.first.portfolioId;
    final list = _holdings[portfolioId];
    if (list == null) return;

    // Update all in memory at once
    for (final h in holdings) {
      final idx = list.indexWhere((e) => e.id == h.id);
      if (idx != -1) list[idx] = h;
    }
    list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    notifyListeners();

    // Fire all Supabase updates in parallel
    await Future.wait(
      holdings.map(
        (h) => _db.updateHolding(h).catchError((e) {
          debugPrint('AccountProvider: Error updating holding ${h.id}: $e');
        }),
      ),
    );
  }

  Future<void> updateHoldingsMarketDataBatch(
    List<StockHolding> holdings,
  ) async {
    if (holdings.isEmpty) return;
    final portfolioId = holdings.first.portfolioId;
    final list = _holdings[portfolioId];
    if (list == null) return;

    for (final h in holdings) {
      final idx = list.indexWhere((e) => e.id == h.id);
      if (idx != -1) list[idx] = h;
    }
    list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    notifyListeners();

    await Future.wait(
      holdings.map(
        (h) => _db.updateHoldingMarketData(h).catchError((e) {
          debugPrint(
            'AccountProvider: Error updating holding market data ${h.id}: $e',
          );
        }),
      ),
    );
  }

  Future<void> deleteHolding(String id, String portfolioId) async {
    final list = _holdings[portfolioId];
    if (list == null) return;

    final idx = list.indexWhere((h) => h.id == id);
    if (idx == -1) return;

    final oldHolding = list[idx];
    list.removeAt(idx);
    notifyListeners();

    try {
      await _db.deleteHolding(id);
    } catch (e) {
      debugPrint('AccountProvider: Error deleting holding: $e');
      list.insert(idx, oldHolding);
      notifyListeners();
      rethrow;
    }
  }

  Future<StockTrade> sellHolding({
    required String portfolioId,
    required String holdingId,
    required double sharesSold,
    required double sellPriceUsd,
    required double cashReceivedUsd,
    double? grossProceedsUsd,
    double? brokerFeeUsd,
    double? exchangeFeeUsd,
    double? taxFeeUsd,
    DateTime? soldAt,
  }) async {
    if (sharesSold <= 0) {
      throw ArgumentError.value(sharesSold, 'sharesSold', 'ต้องมากกว่า 0');
    }
    if (sellPriceUsd < 0) {
      throw ArgumentError.value(sellPriceUsd, 'sellPriceUsd', 'ต้องไม่ติดลบ');
    }
    if (cashReceivedUsd < 0) {
      throw ArgumentError.value(
        cashReceivedUsd,
        'cashReceivedUsd',
        'ต้องไม่ติดลบ',
      );
    }

    final accountIndex = _accounts.indexWhere((a) => a.id == portfolioId);
    if (accountIndex == -1) {
      throw StateError('ไม่พบพอร์ตที่ต้องการขายหุ้น');
    }

    final holdings = _holdings[portfolioId];
    if (holdings == null) {
      throw StateError('ไม่พบหุ้นในพอร์ตนี้');
    }

    final holdingIndex = holdings.indexWhere((h) => h.id == holdingId);
    if (holdingIndex == -1) {
      throw StateError('ไม่พบหุ้นที่ต้องการขาย');
    }

    final holding = holdings[holdingIndex];
    if (sharesSold > holding.shares + 0.0000001) {
      throw ArgumentError.value(
        sharesSold,
        'sharesSold',
        'จำนวนขายมากกว่าจำนวนที่ถือ',
      );
    }

    final trade = StockTrade(
      id: generateId(),
      portfolioId: portfolioId,
      holdingId: holding.id,
      ticker: holding.ticker,
      name: holding.name,
      logoUrl: holding.logoUrl,
      sharesSold: sharesSold,
      sellPriceUsd: sellPriceUsd,
      cashReceivedUsd: cashReceivedUsd,
      costBasisUsd: holding.costBasisUsd,
      grossProceedsUsd: grossProceedsUsd,
      brokerFeeUsd: brokerFeeUsd,
      taxFeeUsd: taxFeeUsd,
      exchangeFeeUsd: exchangeFeeUsd,
      costMethod: CostMethod.average,
      pnlSource: PnlSource.estimated,
      soldAt: soldAt,
    );

    final oldAccount = _accounts[accountIndex];
    final oldHolding = holding;
    final oldTrades = List<StockTrade>.from(_stockTrades);
    final remainingShares = holding.shares - sharesSold;
    final isFullSell = remainingShares <= 0.0000001;
    final updatedAccount = oldAccount.copyWith(
      cashBalance: oldAccount.cashBalance + cashReceivedUsd,
    );

    _accounts[accountIndex] = updatedAccount;
    if (isFullSell) {
      holdings.removeAt(holdingIndex);
    } else {
      holdings[holdingIndex] = holding.copyWith(
        shares: remainingShares,
        peakProfitPct: _resolveResetPeakProfitPct(
          holding: holding,
          shares: remainingShares,
        ),
      );
    }
    _stockTrades.insert(0, trade);
    notifyListeners();

    var insertedTrade = false;
    var updatedAccountRemote = false;
    try {
      await _db.insertStockTrade(trade);
      insertedTrade = true;
      await _db.updateAccount(updatedAccount);
      updatedAccountRemote = true;
      if (isFullSell) {
        await _db.deleteHolding(holding.id);
      } else {
        await _db.updateHolding(holdings[holdingIndex]);
      }
      return trade;
    } catch (e) {
      debugPrint('AccountProvider: Error selling holding: $e');
      if (insertedTrade) {
        try {
          await _db.deleteStockTrade(trade.id);
        } catch (cleanupError) {
          debugPrint(
            'AccountProvider: Error rolling back stock trade: $cleanupError',
          );
        }
      }
      if (updatedAccountRemote) {
        try {
          await _db.updateAccount(oldAccount);
        } catch (cleanupError) {
          debugPrint(
            'AccountProvider: Error rolling back portfolio cash: $cleanupError',
          );
        }
      }
      _accounts[accountIndex] = oldAccount;
      if (isFullSell) {
        holdings.insert(holdingIndex, oldHolding);
      } else {
        holdings[holdingIndex] = oldHolding;
      }
      _stockTrades
        ..clear()
        ..addAll(oldTrades);
      notifyListeners();
      rethrow;
    }
  }

  double? _resolveResetPeakProfitPct({
    required StockHolding holding,
    required double shares,
  }) {
    if (!holding.sellPlanEnabled || holding.costBasisUsd <= 0 || shares <= 0) {
      return null;
    }

    final totalCostUsd = shares * holding.costBasisUsd;
    if (totalCostUsd <= 0) return null;

    final currentValueUsd = shares * holding.priceUsd;
    final currentPnlPct =
        ((currentValueUsd - totalCostUsd) / totalCostUsd) * 100;
    final shouldTrackPeak = holding.takeProfitPct <= 0
        ? currentPnlPct > 0
        : currentPnlPct >= holding.takeProfitPct;

    if (!shouldTrackPeak) return null;
    return double.parse(currentPnlPct.toStringAsFixed(2));
  }

  Future<void> addStockTrade(StockTrade trade) async {
    final normalized = _normalizeStockTrade(trade);
    _validateStockTrade(normalized);

    _stockTrades.add(normalized);
    _sortStockTrades();
    notifyListeners();

    try {
      await _db.insertStockTrade(normalized);
    } catch (e) {
      debugPrint('AccountProvider: Error adding stock trade: $e');
      _stockTrades.removeWhere((t) => t.id == normalized.id);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateStockTrade(StockTrade updated) async {
    final normalized = _normalizeStockTrade(updated);
    _validateStockTrade(normalized);

    final index = _stockTrades.indexWhere((trade) => trade.id == normalized.id);
    if (index == -1) return;

    final oldTrade = _stockTrades[index];
    _stockTrades[index] = normalized;
    _sortStockTrades();
    notifyListeners();

    try {
      await _db.updateStockTrade(normalized);
    } catch (e) {
      debugPrint('AccountProvider: Error updating stock trade: $e');
      final rollbackIndex = _stockTrades.indexWhere(
        (trade) => trade.id == oldTrade.id,
      );
      if (rollbackIndex == -1) {
        _stockTrades.add(oldTrade);
      } else {
        _stockTrades[rollbackIndex] = oldTrade;
      }
      _sortStockTrades();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteStockTrade(String id) async {
    final index = _stockTrades.indexWhere((trade) => trade.id == id);
    if (index == -1) return;

    final oldTrade = _stockTrades[index];
    _stockTrades.removeAt(index);
    notifyListeners();

    try {
      await _db.deleteStockTrade(id);
    } catch (e) {
      debugPrint('AccountProvider: Error deleting stock trade: $e');
      _stockTrades.insert(index, oldTrade);
      notifyListeners();
      rethrow;
    }
  }

  StockTrade _normalizeStockTrade(StockTrade trade) {
    final ticker = trade.ticker.trim().toUpperCase();
    return trade.copyWith(
      ticker: ticker,
      name: trade.name.trim(),
      logoUrl: resolveStockLogoUrl(
        portfolioId: trade.portfolioId,
        ticker: ticker,
        fallback: trade.logoUrl,
      ),
    );
  }

  void _validateStockTrade(StockTrade trade) {
    if (_accounts.every((account) => account.id != trade.portfolioId)) {
      throw StateError('ไม่พบพอร์ตของรายการขาย');
    }
    if (trade.ticker.trim().isEmpty) {
      throw ArgumentError.value(trade.ticker, 'ticker', 'ต้องระบุ ticker');
    }
    if (trade.sharesSold <= 0) {
      throw ArgumentError.value(
        trade.sharesSold,
        'sharesSold',
        'ต้องมากกว่า 0',
      );
    }
    if (trade.sellPriceUsd < 0) {
      throw ArgumentError.value(
        trade.sellPriceUsd,
        'sellPriceUsd',
        'ต้องไม่ติดลบ',
      );
    }
    if (trade.cashReceivedUsd < 0) {
      throw ArgumentError.value(
        trade.cashReceivedUsd,
        'cashReceivedUsd',
        'ต้องไม่ติดลบ',
      );
    }
    if (trade.costBasisUsd < 0) {
      throw ArgumentError.value(
        trade.costBasisUsd,
        'costBasisUsd',
        'ต้องไม่ติดลบ',
      );
    }
  }

  void _validatePortfolioAnnualReport(PortfolioAnnualReport report) {
    if (_accounts.every((account) => account.id != report.portfolioId)) {
      throw StateError('ไม่พบพอร์ตของรายงาน Broker');
    }
    if (report.year < 1900 || report.year > 2100) {
      throw ArgumentError.value(report.year, 'year', 'ปีไม่ถูกต้อง');
    }
    if (report.inflowUsd < 0) {
      throw ArgumentError.value(report.inflowUsd, 'inflowUsd', 'ต้องไม่ติดลบ');
    }
    if (report.inflowThb < 0) {
      throw ArgumentError.value(report.inflowThb, 'inflowThb', 'ต้องไม่ติดลบ');
    }
    if (report.dividendGrossUsd < 0) {
      throw ArgumentError.value(
        report.dividendGrossUsd,
        'dividendGrossUsd',
        'ต้องไม่ติดลบ',
      );
    }
    if (report.dividendTaxWithheldUsd < 0) {
      throw ArgumentError.value(
        report.dividendTaxWithheldUsd,
        'dividendTaxWithheldUsd',
        'ต้องไม่ติดลบ',
      );
    }
    if (report.dividendNetUsd < 0) {
      throw ArgumentError.value(
        report.dividendNetUsd,
        'dividendNetUsd',
        'ต้องไม่ติดลบ',
      );
    }
    if (report.remittedUsd < 0) {
      throw ArgumentError.value(
        report.remittedUsd,
        'remittedUsd',
        'ต้องไม่ติดลบ',
      );
    }
    if (report.remittedThb < 0) {
      throw ArgumentError.value(
        report.remittedThb,
        'remittedThb',
        'ต้องไม่ติดลบ',
      );
    }
  }

  void _sortStockTrades() {
    _stockTrades.sort((a, b) => b.soldAt.compareTo(a.soldAt));
  }

  Future<void> reorderHoldings(
    String portfolioId,
    int oldIndex,
    int newIndex,
  ) async {
    final holdings = _holdings[portfolioId];
    if (holdings == null) return;
    if (oldIndex < 0 || oldIndex >= holdings.length) return;
    if (newIndex < 0 || newIndex > holdings.length) return;

    // Adjust newIndex for the remove-then-insert operation
    if (newIndex > oldIndex) {
      newIndex--;
    }

    // Remove and re-insert
    final movedHolding = holdings.removeAt(oldIndex);
    holdings.insert(newIndex, movedHolding);

    // Update sortOrder for all holdings in this portfolio
    for (var i = 0; i < holdings.length; i++) {
      holdings[i].sortOrder = i * 10; // Use multiples of 10 for flexibility
    }
    notifyListeners();

    try {
      for (var i = 0; i < holdings.length; i++) {
        await _db.updateHoldingSortOrder(holdings[i].id, holdings[i].sortOrder);
      }
    } catch (e) {
      debugPrint('AccountProvider: Error reordering holdings: $e');
      await reload();
      rethrow;
    }
  }

  String generateId() => _uuid.v4();
}
