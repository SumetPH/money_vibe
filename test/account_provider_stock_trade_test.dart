import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_vibe/models/account.dart';
import 'package:money_vibe/models/budget.dart';
import 'package:money_vibe/models/category.dart';
import 'package:money_vibe/models/recurring_transaction.dart';
import 'package:money_vibe/models/stock_holding.dart';
import 'package:money_vibe/models/stock_trade.dart';
import 'package:money_vibe/models/transaction.dart';
import 'package:money_vibe/providers/account_provider.dart';
import 'package:money_vibe/repositories/database_repository.dart';
import 'package:money_vibe/services/database_manager.dart';

class _FakeTradeRepository implements DatabaseRepository {
  final List<Account> accounts;
  final List<StockHolding> holdings;
  final List<StockTrade> trades;
  bool failInsertTrade = false;

  _FakeTradeRepository({
    required this.accounts,
    required this.holdings,
    required this.trades,
  });

  @override
  String get name => 'FakeTradeRepository';

  @override
  bool get isAuthenticated => true;

  @override
  String? get currentUserId => 'test-user';

  @override
  Stream<String> get onLocalSyncLogUpdate => const Stream<String>.empty();

  @override
  Future<void> init() async {}

  @override
  Future<void> close() async {}

  @override
  Future<void> clearAllData() async {}

  @override
  Future<bool> isConnected() async => true;

  @override
  Future<Map<String, dynamic>> healthCheck() async => {'status': 'ok'};

  @override
  Future<List<Account>> getAccounts() async => List.of(accounts);

  @override
  Future<List<StockHolding>> getPortfolioHoldings() async => List.of(holdings);

  @override
  Future<List<StockTrade>> getStockTrades() async => List.of(trades);

  @override
  Future<void> updateAccount(Account account) async {
    final index = accounts.indexWhere((a) => a.id == account.id);
    if (index != -1) accounts[index] = account;
  }

  @override
  Future<void> updateHolding(StockHolding holding) async {
    final index = holdings.indexWhere((h) => h.id == holding.id);
    if (index != -1) holdings[index] = holding;
  }

  @override
  Future<void> deleteHolding(String id) async {
    holdings.removeWhere((h) => h.id == id);
  }

  @override
  Future<void> insertStockTrade(StockTrade trade) async {
    if (failInsertTrade) throw Exception('insert failed');
    trades.add(trade);
  }

  @override
  Future<void> updateStockTrade(StockTrade trade) async {
    final index = trades.indexWhere((t) => t.id == trade.id);
    if (index != -1) trades[index] = trade;
  }

  @override
  Future<void> deleteStockTrade(String id) async {
    trades.removeWhere((t) => t.id == id);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName.toString();
    if (name.contains('getCategories')) return Future.value(<Category>[]);
    if (name.contains('getTransactions')) {
      return Future.value(<AppTransaction>[]);
    }
    if (name.contains('getBudgets')) return Future.value(<Budget>[]);
    if (name.contains('getRecurringTransactions')) {
      return Future.value(<RecurringTransaction>[]);
    }
    if (name.contains('getRecurringOccurrences')) {
      return Future.value(<RecurringOccurrence>[]);
    }
    if (name.contains('getSyncLogs')) {
      return Future.value(<String, DateTime>{});
    }
    if (name.contains('getExisting')) return Future.value(<String>{});
    return null;
  }
}

void main() {
  Account buildPortfolio({double cashBalance = 100}) {
    return Account(
      id: 'portfolio-1',
      name: 'US Portfolio',
      type: AccountType.portfolio,
      currency: 'USD',
      icon: Icons.show_chart,
      cashBalance: cashBalance,
      autoUpdateRate: false,
    );
  }

  StockHolding buildHolding({double shares = 10}) {
    return StockHolding(
      id: 'holding-1',
      portfolioId: 'portfolio-1',
      ticker: 'AAPL',
      name: 'Apple',
      shares: shares,
      priceUsd: 120,
      costBasisUsd: 100,
      logoUrl: 'https://example.com/aapl.png',
    );
  }

  Future<(AccountProvider, _FakeTradeRepository)> initProvider({
    double shares = 10,
    double cashBalance = 100,
    bool failInsertTrade = false,
  }) async {
    final fakeDb = _FakeTradeRepository(
      accounts: [buildPortfolio(cashBalance: cashBalance)],
      holdings: [buildHolding(shares: shares)],
      trades: [],
    )..failInsertTrade = failInsertTrade;
    DatabaseManager().repository = fakeDb;
    final provider = AccountProvider();
    await provider.init();
    return (provider, fakeDb);
  }

  group('AccountProvider.sellHolding', () {
    test(
      'partially sells a holding, adds cash, and records trade with fees',
      () async {
        final (provider, fakeDb) = await initProvider();

        final trade = await provider.sellHolding(
          portfolioId: 'portfolio-1',
          holdingId: 'holding-1',
          sharesSold: 2.5,
          sellPriceUsd: 130,
          cashReceivedUsd: 310, // 325 gross - 15 fees
          grossProceedsUsd: 325,
          brokerFeeUsd: 10,
          taxFeeUsd: 2,
          exchangeFeeUsd: 3,
          soldAt: DateTime(2026, 6, 17),
        );

        expect(provider.getHoldings('portfolio-1').single.shares, 7.5);
        expect(provider.findById('portfolio-1')!.cashBalance, 410);
        expect(provider.stockTrades.single, trade);
        expect(trade.logoUrl, 'https://example.com/aapl.png');
        expect(trade.realizedPnlUsd, 60); // 310 - (100 * 2.5) = 60
        expect(trade.grossProceedsUsd, 325);
        expect(trade.brokerFeeUsd, 10);
        expect(trade.taxFeeUsd, 2);
        expect(trade.exchangeFeeUsd, 3);
        expect(trade.costMethod, CostMethod.average);
        expect(trade.pnlSource, PnlSource.estimated);
        expect(fakeDb.holdings.single.shares, 7.5);
        expect(fakeDb.accounts.single.cashBalance, 410);
        expect(fakeDb.trades.single.realizedPnlUsd, 60);
      },
    );

    test('fully sells a holding and removes it from portfolio', () async {
      final (provider, fakeDb) = await initProvider(shares: 3);

      await provider.sellHolding(
        portfolioId: 'portfolio-1',
        holdingId: 'holding-1',
        sharesSold: 3,
        sellPriceUsd: 90,
        cashReceivedUsd: 265,
      );

      expect(provider.getHoldings('portfolio-1'), isEmpty);
      expect(provider.findById('portfolio-1')!.cashBalance, 365);
      expect(provider.stockTrades.single.realizedPnlUsd, -35);
      expect(fakeDb.holdings, isEmpty);
    });

    test('rejects invalid sale values', () async {
      final (provider, _) = await initProvider();

      expect(
        () => provider.sellHolding(
          portfolioId: 'portfolio-1',
          holdingId: 'holding-1',
          sharesSold: 11,
          sellPriceUsd: 100,
          cashReceivedUsd: 100,
        ),
        throwsArgumentError,
      );

      expect(
        () => provider.sellHolding(
          portfolioId: 'portfolio-1',
          holdingId: 'holding-1',
          sharesSold: 1,
          sellPriceUsd: -1,
          cashReceivedUsd: 100,
        ),
        throwsArgumentError,
      );
    });

    test('rolls back optimistic state when repository write fails', () async {
      final (provider, fakeDb) = await initProvider(failInsertTrade: true);

      await expectLater(
        provider.sellHolding(
          portfolioId: 'portfolio-1',
          holdingId: 'holding-1',
          sharesSold: 2,
          sellPriceUsd: 120,
          cashReceivedUsd: 240,
        ),
        throwsException,
      );

      expect(provider.getHoldings('portfolio-1').single.shares, 10);
      expect(provider.findById('portfolio-1')!.cashBalance, 100);
      expect(provider.stockTrades, isEmpty);
      expect(fakeDb.trades, isEmpty);
    });
  });

  group('AccountProvider stock trade tracker CRUD', () {
    test('adds manual trade without updating portfolio cash', () async {
      final (provider, fakeDb) = await initProvider();

      await provider.addStockTrade(
        StockTrade(
          id: 'manual-1',
          portfolioId: 'portfolio-1',
          holdingId: '',
          ticker: 'aapl',
          sharesSold: 1,
          sellPriceUsd: 150,
          cashReceivedUsd: 148,
          costBasisUsd: 100,
          soldAt: DateTime(2026, 6, 17),
        ),
      );

      final trade = provider.stockTrades.first;
      expect(provider.findById('portfolio-1')!.cashBalance, 100);
      expect(trade.ticker, 'AAPL');
      expect(trade.logoUrl, 'https://example.com/aapl.png');
      expect(fakeDb.trades.single.cashReceivedUsd, 148);
    });

    test(
      'updates and deletes manual trade without updating portfolio cash',
      () async {
        final (provider, fakeDb) = await initProvider();
        await provider.addStockTrade(
          StockTrade(
            id: 'manual-1',
            portfolioId: 'portfolio-1',
            holdingId: '',
            ticker: 'AAPL',
            sharesSold: 1,
            sellPriceUsd: 150,
            cashReceivedUsd: 148,
            costBasisUsd: 100,
          ),
        );

        await provider.updateStockTrade(
          provider.stockTrades.single.copyWith(sellPriceUsd: 90),
        );

        expect(provider.findById('portfolio-1')!.cashBalance, 100);
        expect(provider.stockTrades.single.realizedPnlUsd, 48);
        expect(fakeDb.trades.single.realizedPnlUsd, 48);

        await provider.deleteStockTrade('manual-1');

        expect(provider.findById('portfolio-1')!.cashBalance, 100);
        expect(provider.stockTrades, isEmpty);
        expect(fakeDb.trades, isEmpty);
      },
    );

    test('preserves broker reported P/L when normalizing trades', () async {
      final (provider, fakeDb) = await initProvider();

      await provider.addStockTrade(
        StockTrade(
          id: 'broker-1',
          portfolioId: 'portfolio-1',
          holdingId: '',
          ticker: 'aapl',
          sharesSold: 1,
          sellPriceUsd: 150,
          cashReceivedUsd: 148,
          costBasisUsd: 100,
          realizedPnlUsd: -12.34,
          pnlSource: PnlSource.broker,
        ),
      );

      expect(provider.stockTrades.single.realizedPnlUsd, -12.34);
      expect(provider.stockTrades.single.pnlSource, PnlSource.broker);
      expect(fakeDb.trades.single.realizedPnlUsd, -12.34);
    });
  });
}
