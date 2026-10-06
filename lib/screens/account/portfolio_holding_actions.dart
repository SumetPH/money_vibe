import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/account.dart';
import 'holding_sell_form_screen.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/stock_holding.dart';
import '../../models/stock_purchase.dart';
import '../../providers/account_provider.dart';
import '../../services/stock_logo_storage_service.dart';

StockHolding syncSellPlanProgress(StockHolding holding) {
  if (!holding.sellPlanEnabled ||
      !holding.canCalculateSellPlan ||
      holding.trailingStopPct <= 0) {
    return holding;
  }

  final currentPnlPct = holding.unrealizedPnlPct;
  final peakProfitPct = holding.peakProfitPct;
  if (peakProfitPct == null) {
    if (_shouldTrackPeakProfit(
      currentPnlPct: currentPnlPct,
      takeProfitPct: holding.takeProfitPct,
    )) {
      return holding.copyWith(peakProfitPct: _roundPct(currentPnlPct));
    }
    return holding;
  }

  if (currentPnlPct > peakProfitPct) {
    return holding.copyWith(peakProfitPct: _roundPct(currentPnlPct));
  }

  return holding;
}

double _roundPct(double value) => double.parse(value.toStringAsFixed(2));

bool _shouldTrackPeakProfit({
  required double currentPnlPct,
  required double takeProfitPct,
}) {
  if (takeProfitPct <= 0) {
    return currentPnlPct > 0;
  }
  return currentPnlPct >= takeProfitPct;
}

Future<void> applyBackfilledHoldingLogo(
  AccountProvider provider,
  StockPurchase purchase,
  String logoUrl,
) async {
  // อ่านค่าล่าสุดอีกครั้ง เผื่อผู้ใช้แก้ไขระหว่างรอ
  final latestHolding = provider
      .getHoldings(purchase.portfolioId)
      .where((h) => h.id == purchase.holdingId)
      .firstOrNull;
  if (latestHolding != null && latestHolding.logoUrl.isEmpty) {
    await provider.updateHolding(latestHolding.copyWith(logoUrl: logoUrl));
  }

  final latestPurchase = provider.stockPurchases
      .where((p) => p.id == purchase.id)
      .firstOrNull;
  if (latestPurchase != null && latestPurchase.logoUrl.isEmpty) {
    await provider.updateStockPurchase(
      latestPurchase.copyWith(logoUrl: logoUrl),
    );
  }
}

Future<String> resolveStockLogoUrl(
  StockLogoStorageService logoStorageService, {
  required String ticker,
  required String sourceUrl,
  required String currentLogoUrl,
}) async {
  if (sourceUrl.isEmpty) return currentLogoUrl;
  if (logoStorageService.isStoredLogoUrl(currentLogoUrl)) {
    return currentLogoUrl;
  }

  final mirroredLogoUrl = await logoStorageService.mirrorLogo(
    ticker: ticker,
    sourceUrl: sourceUrl,
  );
  if (mirroredLogoUrl != null && mirroredLogoUrl.isNotEmpty) {
    return mirroredLogoUrl;
  }

  return currentLogoUrl.isNotEmpty ? currentLogoUrl : sourceUrl;
}

Future<void> pickAndUploadHoldingLogo(
  BuildContext context,
  AccountProvider provider,
  StockLogoStorageService logoStorageService,
  StockHolding holding,
) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
    withData: true,
  );
  if (result == null || result.files.isEmpty) return;

  final file = result.files.single;
  if (file.bytes == null || file.bytes!.isEmpty) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('ไม่สามารถอ่านไฟล์รูปได้')));
    return;
  }

  final extension = file.extension?.toLowerCase() ?? 'png';
  final uploadedUrl = await logoStorageService.uploadLogoBytes(
    ticker: holding.ticker,
    bytes: file.bytes!,
    extension: extension,
    contentType: logoContentTypeForExtension(extension),
  );

  if (!context.mounted) return;
  if (uploadedUrl == null || uploadedUrl.isEmpty) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('อัปโหลดโลโก้ไม่สำเร็จ')));
    return;
  }

  await provider.updateHolding(holding.copyWith(logoUrl: uploadedUrl));
  if (!context.mounted) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('อัปเดตโลโก้แล้ว')));
}

String logoContentTypeForExtension(String extension) {
  switch (extension.toLowerCase()) {
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'webp':
      return 'image/webp';
    default:
      return 'image/png';
  }
}

Future<void> openHoldingSellForm(
  BuildContext context,
  AccountProvider provider,
  Account account,
  String portfolioId,
  StockHolding holding,
) async {
  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => HoldingSellFormScreen(
        holding: holding,
        currencyCode: account.currencyCodeLabel,
        onSell:
            ({
              required sharesSold,
              required sellPriceUsd,
              required cashReceivedUsd,
              required remainingShares,
              required resetPeakProfit,
              remainingCostBasisUsd,
              grossProceedsUsd,
              brokerFeeUsd,
              exchangeFeeUsd,
              taxFeeUsd,
              executedAt,
            }) async {
              await provider.sellHolding(
                portfolioId: portfolioId,
                holdingId: holding.id,
                sharesSold: sharesSold,
                sellPriceUsd: sellPriceUsd,
                cashReceivedUsd: cashReceivedUsd,
                remainingShares: remainingShares,
                resetPeakProfit: resetPeakProfit,
                remainingCostBasisUsd: remainingCostBasisUsd,
                grossProceedsUsd: grossProceedsUsd,
                brokerFeeUsd: brokerFeeUsd,
                exchangeFeeUsd: exchangeFeeUsd,
                taxFeeUsd: taxFeeUsd,
                soldAt: executedAt,
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('บันทึกการขาย ${holding.ticker} แล้ว'),
                  ),
                );
              }
            },
      ),
    ),
  );
}
