import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:money_vibe/theme/app_radii.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../services/dime_trade_ocr.dart';
import '../theme/app_colors.dart';
import 'app_modal_bottom_sheet.dart';

class BrokerOrderImportButton extends StatefulWidget {
  final bool isBuy;
  final String? expectedTicker;
  final ValueChanged<DimeTradeDraft> onApply;

  const BrokerOrderImportButton({
    super.key,
    required this.isBuy,
    required this.expectedTicker,
    required this.onApply,
  });

  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  @override
  State<BrokerOrderImportButton> createState() =>
      _BrokerOrderImportButtonState();
}

class _BrokerOrderImportButtonState extends State<BrokerOrderImportButton> {
  bool _reading = false;

  Future<void> _chooseImage() async {
    final broker = await showAppModalBottomSheet<bool>(
      context: context,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppModalBottomSheetHeader(title: 'เลือกโบรกเกอร์'),
          ListTile(
            leading: const Icon(Icons.account_balance_outlined),
            title: const Text('Dime!'),
            subtitle: const Text('หุ้นสหรัฐฯ · USD'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pop(sheetContext, true),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
    if (!mounted || broker != true) return;

    setState(() => _reading = true);
    try {
      final image = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (!mounted || image == null) return;
      if (kDebugMode) debugPrint('[DimeOCR] image selected');
      var draft = await DimeTradeOcr.read(image, isBuy: widget.isBuy);
      if (!mounted) return;
      if (draft == null ||
          (draft.shares == null &&
              draft.priceUsd == null &&
              draft.grossUsd == null)) {
        _message('อ่านรายละเอียดคำสั่ง Dime! ไม่ชัด กรุณากรอกเอง');
        return;
      }
      final expected = widget.expectedTicker?.trim().toUpperCase();
      if (expected != null && expected.isNotEmpty) {
        final actual = draft.ticker?.trim().toUpperCase();
        if (actual != null && actual.isNotEmpty) {
          if (_tickerKey(actual) == _tickerKey(expected)) {
            draft = draft.withTicker(expected);
          } else {
            _message('หุ้นในภาพ ($actual) ไม่ตรงกับ $expected');
            return;
          }
        } else {
          draft = draft.withTicker(expected);
        }
      }
      final apply = await _confirm(draft);
      if (mounted && apply == true) widget.onApply(draft);
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('[DimeOCR] import failed: $error\n$stackTrace');
      }
      if (mounted) _message('อ่านภาพไม่สำเร็จ กรุณาลองใหม่หรือกรอกเอง');
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  Future<bool?> _confirm(DimeTradeDraft draft) {
    final isDark = context.read<SettingsProvider>().isDarkMode;
    final textColor = isDark
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    String value(double? amount, int digits) =>
        amount == null ? 'อ่านไม่ได้' : amount.toStringAsFixed(digits);

    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
        title: Text('ข้อมูลจาก Dime!', style: TextStyle(color: textColor)),
        content: SingleChildScrollView(
          child: Text(
            'หุ้น ${draft.ticker ?? 'ไม่ระบุ'}\n'
            'จำนวน ${value(draft.shares, 7)} หุ้น\n'
            'ราคาที่ได้จริง ${value(draft.priceUsd, 4)} USD\n'
            'มูลค่าหุ้น ${value(draft.grossUsd, 2)} USD\n'
            'ค่าคอมมิชชัน ${value(draft.brokerFeeUsd, 4)} USD\n'
            'VAT ${value(draft.vatUsd, 4)} USD\n'
            'SEC/TAF ${value(draft.exchangeFeeUsd, 4)} USD\n'
            'ยอดสุทธิ ${value(draft.netUsd, 2)} USD\n\n'
            'เมื่อกดเติมฟอร์ม ค่าที่มีอยู่จะถูกเขียนทับ และช่องที่อ่านไม่ได้จะถูกเว้นว่าง\n\n'
            'เลือกวันที่และตรวจข้อมูลก่อนบันทึก',
            style: TextStyle(color: textColor),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('เติมฟอร์ม'),
          ),
        ],
      ),
    );
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<SettingsProvider>().isDarkMode;
    final textColor = isDark
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    return ListTile(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.xLarge),
      ),
      leading: Icon(Icons.document_scanner_outlined, color: textColor),
      title: Text('เติมข้อมูลจากภาพ', style: TextStyle(color: textColor)),
      subtitle: Text(
        'เลือกโบรกเกอร์ แล้วเลือกรูปคำสั่งที่สำเร็จ',
        style: TextStyle(color: secondary),
      ),
      trailing: _reading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(Icons.chevron_right, color: secondary),
      onTap: _reading ? null : _chooseImage,
    );
  }
}

String _tickerKey(String value) => value.toUpperCase().replaceAll('0', 'O');
