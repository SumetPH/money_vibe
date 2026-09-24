import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:text_sight/text_sight.dart';

class DimeTradeDraft {
  final String? ticker;
  final double? shares;
  final double? priceUsd;
  final double? grossUsd;
  final double? netUsd;
  final double? brokerFeeUsd;
  final double? vatUsd;
  final double? exchangeFeeUsd;
  final TimeOfDay? completedTime;

  const DimeTradeDraft({
    this.ticker,
    this.shares,
    this.priceUsd,
    this.grossUsd,
    this.netUsd,
    this.brokerFeeUsd,
    this.vatUsd,
    this.exchangeFeeUsd,
    this.completedTime,
  });

  DimeTradeDraft withTicker(String value) => DimeTradeDraft(
    ticker: value,
    shares: shares,
    priceUsd: priceUsd,
    grossUsd: grossUsd,
    netUsd: netUsd,
    brokerFeeUsd: brokerFeeUsd,
    vatUsd: vatUsd,
    exchangeFeeUsd: exchangeFeeUsd,
    completedTime: completedTime,
  );
}

class DimeTradeOcr {
  static Future<DimeTradeDraft?> read(XFile file, {required bool isBuy}) async {
    _log('recognize start side=${isBuy ? 'buy' : 'sell'}');
    final result = await TextSight.recognizePath(
      file.path,
      options: const TextSightOptions(
        darwin: DarwinOptions(
          recognitionLevel: RecognitionLevel.accurate,
          usesLanguageCorrection: false,
          preferredLanguages: [
            Locale.fromSubtags(languageCode: 'th', countryCode: 'TH'),
            Locale.fromSubtags(languageCode: 'en', countryCode: 'US'),
          ],
        ),
      ),
    );
    final lines = [
      for (final line in result.lines) _Line(line.text, line.boundingBox),
    ]..sort((a, b) => a.y.compareTo(b.y));
    _log('recognized ${lines.length} lines');
    if (kDebugMode) {
      for (final line in lines) {
        final text = line.text.replaceAll(
          RegExp(r'\b[A-Z0-9]{9,}\b', caseSensitive: false),
          '[id]',
        );
        _log(
          'line x=${line.x.toStringAsFixed(3)} '
          'y=${line.y.toStringAsFixed(3)} text="$text"',
        );
      }
    }
    return _parse(lines, isBuy: isBuy);
  }

  static DimeTradeDraft? _parse(List<_Line> lines, {required bool isBuy}) {
    if (lines.isEmpty) return _reject('empty lines');

    // 1. Ticker extraction
    String? ticker;
    _Line? tickerLine;
    const nonTickers = {
      'USD',
      'THB',
      'NYSE',
      'ARCA',
      'NASDAQ',
      'DIME',
      'MARKET',
      'LIMIT',
      'SELL',
      'BUY',
      'SEC',
      'TAF',
      'VAT',
      'KKP',
      'SET',
      'สำเร็จ',
      'ซื้อ',
      'ขาย',
      'ยกเลิก',
    };

    final tickerCandidates = lines.where(
      (line) => line.y > 0.05 && line.y < 0.4 && line.x > 0.15 && line.x < 0.6,
    );
    for (final line in tickerCandidates) {
      for (final match in RegExp(
        r'\b[A-Z][A-Z0-9]{0,4}\b',
        caseSensitive: false,
      ).allMatches(line.text)) {
        final candidate = match.group(0)!.toUpperCase();
        if (!nonTickers.contains(candidate)) {
          ticker = candidate;
          tickerLine = line;
          break;
        }
      }
      if (ticker != null) break;
    }

    // 2. Headline net amount
    final headlineNetLine = _firstAmount(
      lines.where(
        (line) =>
            line.x < 0.6 &&
            (tickerLine == null ||
                (line.y > tickerLine.y + 0.01 && line.y < tickerLine.y + 0.18)),
      ),
    );
    final displayedNet = headlineNetLine?.$2;

    // 3. Label-based search helpers
    //
    // findValueByLabels: finds the FIRST value associated with ANY matching label.
    // For "next line below", we check x-column alignment (within ±0.25) to avoid
    // grabbing values from an adjacent column (e.g. left-column price label
    // accidentally picking up a right-column shares value).
    double? findValueByLabels(List<String> keywords) {
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];
        final lower = line.text.toLowerCase();
        if (!keywords.any((kw) => lower.contains(kw.toLowerCase()))) continue;

        // Try number within same line — only accept if followed by a currency unit.
        // This skips numbers embedded in label names like "7%" in "ภาษีมูลค่าเพิ่ม 7% (VAT)".
        final inlineMatch = RegExp(
          r'(-?\d{1,3}(?:,\d{3})*(?:\.\d+)?|-?\d+(?:\.\d+)?)\s*(?:USD|THB|บาท|\$)',
          caseSensitive: false,
        ).firstMatch(line.text);
        if (inlineMatch != null) {
          final v = double.tryParse(inlineMatch.group(1)!.replaceAll(',', ''));
          if (v != null) return v;
        }

        // Try same horizontal band to the right
        final sameRow = lines.where(
          (other) =>
              other != line &&
              (other.y - line.y).abs() < 0.025 &&
              other.x > line.x,
        );
        for (final rowLine in sameRow) {
          final amt = _amount(rowLine.text);
          if (amt != null) return amt;
        }

        // Try lines below within 0.06 band, same x-column (±0.25)
        for (int j = i + 1; j < lines.length; j++) {
          final below = lines[j];
          final dy = below.y - line.y;
          if (dy > 0.06) break;
          if (dy <= 0) continue;
          if ((below.x - line.x).abs() > 0.25) continue;
          final amt = _amount(below.text);
          if (amt != null) return amt;
        }
      }
      return null;
    }

    // findSumByLabels: finds ALL labels and sums their values.
    // Used for exchange fees (SEC + TAF are separate lines).
    double? findSumByLabels(List<String> keywords) {
      double total = 0;
      bool found = false;
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];
        final lower = line.text.toLowerCase();
        if (!keywords.any((kw) => lower.contains(kw.toLowerCase()))) continue;

        final inlineAmount = _amount(line.text);
        if (inlineAmount != null) {
          total += inlineAmount.abs();
          found = true;
          continue;
        }
        final sameRow = lines.where(
          (other) =>
              other != line &&
              (other.y - line.y).abs() < 0.025 &&
              other.x > line.x,
        );
        for (final rowLine in sameRow) {
          final amt = _amount(rowLine.text);
          if (amt != null) {
            total += amt.abs();
            found = true;
            break;
          }
        }
        if (!found) {
          for (int j = i + 1; j < lines.length; j++) {
            final below = lines[j];
            final dy = below.y - line.y;
            if (dy > 0.06) break;
            if (dy <= 0) continue;
            if ((below.x - line.x).abs() > 0.25) continue;
            final amt = _amount(below.text);
            if (amt != null) {
              total += amt.abs();
              found = true;
              break;
            }
          }
        }
      }
      return found ? total : null;
    }

    // 4. Shares extraction
    double? shares = findValueByLabels([
      'จำนวนหุ้น',
      'จำนวนหน่วย',
      'จำนวน',
      'shares',
      'quantity',
      'qty',
    ]);
    _Line? shareLine;
    if (shares == null) {
      // Fallback: look for share pattern with high precision decimals
      final shareLines = lines.where(
        (line) =>
            (headlineNetLine == null || line.y > headlineNetLine.$1.y + 0.01) &&
            line.y < 0.7 &&
            line.x > 0.35 &&
            !line.text.toUpperCase().contains('USD') &&
            !line.text.toUpperCase().contains('THB'),
      );
      for (final line in shareLines) {
        final match = RegExp(r'\b\d+\.\d{3,9}\b').firstMatch(line.text);
        if (match == null) continue;
        final value = double.tryParse(match.group(0)!);
        if (value != null && value > 0) {
          shares = value;
          shareLine = line;
          break;
        }
      }
    }

    // 5. Price extraction
    // Note: 'ราคา' is intentionally omitted — it would match "ราคาที่คุณตั้ง"
    // (the limit price set by the user) which appears above "ราคาที่ได้จริง"
    // (actual execution price) in the y-sorted line list.
    double? price = findValueByLabels([
      'ราคาที่ได้จริง',
      'ราคาต่อหุ้น',
      'ราคาเฉลี่ย',
      'ราคาที่ได้',
      'executed price',
      'avg price',
      'fill price',
    ]);
    final anchorShare = shareLine;
    if (price == null && anchorShare != null) {
      // Fallback: amount on same horizontal line as shares
      price = _firstAmount(
        lines.where(
          (line) => line.x < 0.55 && (line.y - anchorShare.y).abs() < 0.025,
        ),
      )?.$2;
    }

    // 6. Gross amount extraction
    double? gross = findValueByLabels([
      'มูลค่าหุ้น',
      'มูลค่ารวม',
      'มูลค่า',
      'ยอดเงินรวม',
      'gross',
      'principal',
    ]);
    _Line? grossLine;
    if (gross == null && (shareLine != null || headlineNetLine != null)) {
      final anchorY = shareLine?.y ?? headlineNetLine!.$1.y;
      final found = _firstAmount(
        lines.where(
          (line) =>
              line.x > 0.45 &&
              line.y > anchorY + 0.015 &&
              line.y < anchorY + 0.2,
        ),
      );
      if (found != null) {
        gross = found.$2;
        grossLine = found.$1;
      }
    }

    // 7. Smart inference for shares, price, gross
    if (gross == null &&
        shares != null &&
        price != null &&
        shares > 0 &&
        price > 0) {
      gross = double.parse((shares * price).toStringAsFixed(2));
      _log('inferred gross=$gross from shares * price');
    } else if (price == null && gross != null && shares != null && shares > 0) {
      price = double.parse((gross / shares).toStringAsFixed(4));
      _log('inferred price=$price from gross / shares');
    } else if (shares == null && gross != null && price != null && price > 0) {
      shares = double.parse((gross / price).toStringAsFixed(7));
      _log('inferred shares=$shares from gross / price');
    }

    // 8. Fee extraction — all stored as positive (abs) values
    double? brokerFee = findValueByLabels([
      'ค่าคอมมิชชัน',
      'ค่าคอมมิชชั่น',
      'ค่าคอม',
      'commission',
      'broker fee',
    ])?.abs();
    double? vat = findValueByLabels(['ภาษีมูลค่าเพิ่ม', 'ภาษี', 'vat'])?.abs();
    // Exchange fees: SEC and TAF are separate lines for sell — sum them all
    double? exchangeFee = findSumByLabels([
      'ค่าธรรมเนียมตลาด',
      'ค่าธรรมเนียมการขาย',
      'taf fee',
      'taf',
      'sec / taf',
      'sec/taf',
      'sec fee',
      'exchange fee',
    ]);

    // Fallback: fees by line sequence if not found by label
    final anchorGross = grossLine;
    if (brokerFee == null && vat == null && anchorGross != null) {
      final feeLines = lines.where(
        (line) =>
            line.x > 0.45 &&
            line.y > anchorGross.y + 0.015 &&
            line.y < anchorGross.y + 0.35,
      );
      final amounts = <double>[];
      for (final line in feeLines) {
        final val = _amount(line.text);
        if (val != null) amounts.add(val.abs());
      }
      final expectedFeeCount = isBuy ? 2 : 4;
      if (amounts.length == expectedFeeCount) {
        brokerFee = amounts[0];
        vat = amounts[1];
        exchangeFee = isBuy ? 0 : amounts[2] + amounts[3];
      }
    }

    // 9. Net amount
    double? net = displayedNet;
    if (net == null && gross != null) {
      final totalFees = (brokerFee ?? 0) + (vat ?? 0) + (exchangeFee ?? 0);
      if (totalFees > 0) {
        net = isBuy ? gross + totalFees : gross - totalFees;
      }
    }

    // 10. Completed time extraction
    TimeOfDay? completedTime;
    final timeLabelLine = lines.firstWhere(
      (line) => [
        'เวลาทำรายการ',
        'เวลาสำเร็จ',
        'เวลา',
        'time',
      ].any((kw) => line.text.toLowerCase().contains(kw)),
      orElse: () => _Line('', const Rect.fromLTWH(0, 0, 0, 0)),
    );
    if (timeLabelLine.text.isNotEmpty) {
      final match = RegExp(
        r'\b([01]?\d|2[0-3]):([0-5]\d)\b',
      ).firstMatch(timeLabelLine.text);
      if (match != null) {
        completedTime = TimeOfDay(
          hour: int.parse(match.group(1)!),
          minute: int.parse(match.group(2)!),
        );
      }
    }

    if (completedTime == null) {
      final times = <TimeOfDay>[];
      for (final line in lines.where((line) => line.y > 0.5 && line.y < 0.98)) {
        final match = RegExp(
          r'\b([01]?\d|2[0-3]):([0-5]\d)\b',
        ).firstMatch(line.text);
        if (match != null) {
          times.add(
            TimeOfDay(
              hour: int.parse(match.group(1)!),
              minute: int.parse(match.group(2)!),
            ),
          );
        }
      }
      if (times.isNotEmpty) {
        completedTime = times.last;
      }
    }

    // 11. Reject ONLY if nothing usable was found
    if (ticker == null &&
        shares == null &&
        price == null &&
        gross == null &&
        net == null) {
      return _reject('no trade data recognized from image');
    }

    _log(
      'parsed best-effort: ticker=$ticker shares=$shares price=$price '
      'gross=$gross net=$net time=$completedTime',
    );

    return DimeTradeDraft(
      ticker: ticker,
      shares: shares,
      priceUsd: price,
      grossUsd: gross,
      netUsd: net,
      brokerFeeUsd: brokerFee,
      vatUsd: vat,
      exchangeFeeUsd: exchangeFee,
      completedTime: completedTime,
    );
  }

  static (_Line, double)? _firstAmount(Iterable<_Line> lines) {
    for (final line in lines) {
      final value = _amount(line.text);
      if (value != null) return (line, value);
    }
    return null;
  }

  static double? _amount(String text) {
    final match = RegExp(
      r'(-?\d{1,3}(?:,\d{3})*(?:\.\d+)?|-?\d+(?:\.\d+)?)(?:\s*(?:USD|THB|บาท|\$))?',
      caseSensitive: false,
    ).firstMatch(text);
    if (match == null) return null;
    final cleaned = match.group(1)!.replaceAll(',', '');
    return double.tryParse(cleaned);
  }

  static DimeTradeDraft? _reject(String reason) {
    _log('rejected: $reason');
    return null;
  }

  static void _log(String message) {
    if (kDebugMode) debugPrint('[DimeOCR] $message');
  }
}

class _Line {
  final String text;
  final double x;
  final double y;

  _Line(this.text, Rect box) : x = box.center.dx, y = box.center.dy;
}
