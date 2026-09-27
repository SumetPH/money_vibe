import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/planned_purchase.dart';
import '../../providers/cash_flow_forecast_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_amount_hero_card.dart';
import '../../widgets/app_bar_buttons.dart';
import '../../widgets/app_confirm_dialog.dart';
import '../../widgets/app_form_row.dart';
import '../../widgets/app_inset_card.dart';
import '../../widgets/calculator_keyboard_host.dart';
import 'cash_flow_section.dart';

/// ฟอร์มเพิ่ม/แก้ไขรายการอยากซื้อ
class PlannedPurchaseFormScreen extends StatefulWidget {
  final PlannedPurchase? purchase;

  const PlannedPurchaseFormScreen({super.key, this.purchase});

  @override
  State<PlannedPurchaseFormScreen> createState() =>
      _PlannedPurchaseFormScreenState();
}

class _PlannedPurchaseFormScreenState extends State<PlannedPurchaseFormScreen>
    with CalculatorKeyboardHost {
  static const _sectionHeaderPadding = EdgeInsets.fromLTRB(4, 16, 4, 6);

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _amountFocusNode = FocusNode();
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  bool _isLoading = false;

  bool get _isEditing => widget.purchase != null;

  @override
  GlobalKey<ScaffoldState> get calculatorScaffoldKey => _scaffoldKey;
  @override
  TextEditingController get calculatorController => _amountController;
  @override
  FocusNode get calculatorFocusNode => _amountFocusNode;
  @override
  Color get calculatorActionColor =>
      AppColors.expenseFor(context.read<SettingsProvider>().isDarkMode);

  @override
  void initState() {
    super.initState();
    final purchase = widget.purchase;
    _nameController = TextEditingController(text: purchase?.name ?? '');
    _amountController = TextEditingController();
    attachCalculatorKeyboard();
    // ตั้งหลัง attach เพื่อให้ได้รูปแบบตัวเลขพร้อมคอมมา
    if (purchase != null) {
      _amountController.text = purchase.amount.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    detachCalculatorKeyboard();
    _amountFocusNode.dispose();
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _closeKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
    closeCalculatorKeyboard();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    _closeKeyboard();
    final name = _nameController.text.trim();
    final amount = calculatorAmount;
    if (name.isEmpty) {
      _showMessage('กรุณากรอกชื่อรายการ');
      return;
    }
    if (amount == null || amount <= 0) {
      _showMessage('กรุณากรอกจำนวนเงินมากกว่า 0');
      return;
    }

    final provider = context.read<CashFlowForecastProvider>();
    setState(() => _isLoading = true);
    try {
      final existing = widget.purchase;
      if (existing == null) {
        await provider.addPlannedPurchase(name: name, amount: amount);
      } else {
        await provider.updatePlannedPurchase(
          existing.copyWith(name: name, amount: amount),
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('PlannedPurchaseForm: save error: $e');
      if (mounted) _showMessage('บันทึกรายการไม่สำเร็จ กรุณาลองใหม่');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _delete() async {
    final purchase = widget.purchase;
    if (purchase == null) return;
    _closeKeyboard();
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'ลบรายการ',
      message: 'ต้องการลบ "${purchase.name}" ออกจากรายการอยากซื้อ?',
      confirmLabel: 'ลบ',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => _isLoading = true);
    try {
      await context.read<CashFlowForecastProvider>().deletePlannedPurchase(
        purchase.id,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('PlannedPurchaseForm: delete error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _showMessage('ลบรายการไม่สำเร็จ กรุณาลองใหม่');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.select<SettingsProvider, bool>(
      (s) => s.isDarkMode,
    );
    final bgColor = AppColors.backgroundFor(isDarkMode);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: bgColor,
      appBar: _buildAppBar(bgColor, isDarkMode),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _closeKeyboard,
        child: AbsorbPointer(
          absorbing: _isLoading,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            children: [
              AppAmountHeroCard(
                controller: _amountController,
                focusNode: _amountFocusNode,
                accentColor: AppColors.expenseFor(isDarkMode),
              ),
              const AppSectionHeader(
                'ข้อมูลรายการ',
                padding: _sectionHeaderPadding,
              ),
              AppInsetCard(
                margin: EdgeInsets.zero,
                children: [_buildNameRow(isDarkMode)],
              ),
              if (_isEditing)
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: CashFlowDeleteButton(
                    onTap: _delete,
                    isDarkMode: isDarkMode,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(Color bgColor, bool isDarkMode) => AppBar(
    backgroundColor: bgColor,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: true,
    leadingWidth: 64,
    leading: AppCloseButton(
      onPressed: _isLoading
          ? null
          : () {
              _closeKeyboard();
              Navigator.pop(context);
            },
    ),
    title: Text(
      _isEditing ? 'แก้ไขรายการอยากซื้อ' : 'เพิ่มรายการอยากซื้อ',
      style: TextStyle(
        color: AppColors.textPrimaryFor(isDarkMode),
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),
    actions: [AppSaveButton(onPressed: _save, isLoading: _isLoading)],
  );

  Widget _buildNameRow(bool isDarkMode) {
    final textSecondary = AppColors.textSecondaryFor(isDarkMode);
    return AppFormRow(
      icon: Icons.shopping_bag_outlined,
      label: 'ชื่อ',
      trailing: TextField(
        controller: _nameController,
        textAlign: TextAlign.right,
        onTap: closeCalculatorKeyboard,
        onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
        decoration: InputDecoration(
          hintText: 'เช่น มือถือ, ตั๋วเครื่องบิน',
          hintTextDirection: TextDirection.rtl,
          hintStyle: TextStyle(
            color: textSecondary.withValues(alpha: 0.55),
            fontSize: 15,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
        ),
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimaryFor(isDarkMode),
        ),
      ),
    );
  }
}
