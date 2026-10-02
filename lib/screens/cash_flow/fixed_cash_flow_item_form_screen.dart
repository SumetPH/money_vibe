import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/fixed_cash_flow_item.dart';
import '../../providers/cash_flow_forecast_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_amount_hero_card.dart';
import '../../widgets/app_bar_buttons.dart';
import '../../widgets/app_confirm_dialog.dart';
import '../../widgets/app_form_row.dart';
import '../../widgets/app_inset_card.dart';
import '../../widgets/app_segmented_tabs.dart';
import '../../widgets/calculator_keyboard_host.dart';
import 'cash_flow_section.dart';

/// ฟอร์มเพิ่ม/แก้ไขรายการเงินเข้าออกในลิสต์จำลองของงวด (ย้ายงวดได้)
class FixedCashFlowItemFormScreen extends StatefulWidget {
  final FixedCashFlowItem? item;

  /// งวดของรายการใหม่ (รายการที่แก้ไขใช้งวดของตัวเอง)
  final CashFlowPeriod initialPeriod;

  const FixedCashFlowItemFormScreen({
    super.key,
    this.item,
    this.initialPeriod = CashFlowPeriod.current,
  });

  @override
  State<FixedCashFlowItemFormScreen> createState() =>
      _FixedCashFlowItemFormScreenState();
}

class _FixedCashFlowItemFormScreenState
    extends State<FixedCashFlowItemFormScreen>
    with CalculatorKeyboardHost {
  static const _sectionHeaderPadding = EdgeInsets.fromLTRB(4, 16, 4, 6);

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _amountFocusNode = FocusNode();
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late CashFlowDirection _direction;
  late CashFlowPeriod _period;
  bool _isLoading = false;

  bool get _isEditing => widget.item != null;

  @override
  GlobalKey<ScaffoldState> get calculatorScaffoldKey => _scaffoldKey;
  @override
  TextEditingController get calculatorController => _amountController;
  @override
  FocusNode get calculatorFocusNode => _amountFocusNode;
  @override
  Color get calculatorActionColor =>
      _accentColor(context.read<SettingsProvider>().isDarkMode);

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _nameController = TextEditingController(text: item?.name ?? '');
    _amountController = TextEditingController();
    _direction = item?.direction ?? CashFlowDirection.outgoing;
    _period = item?.period ?? widget.initialPeriod;
    attachCalculatorKeyboard();
    // ตั้งหลัง attach เพื่อให้ได้รูปแบบตัวเลขพร้อมคอมมา
    if (item != null) _amountController.text = item.amount.toStringAsFixed(2);
  }

  @override
  void dispose() {
    detachCalculatorKeyboard();
    _amountFocusNode.dispose();
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Color _accentColor(bool isDarkMode) =>
      _direction == CashFlowDirection.incoming
      ? AppColors.incomeFor(isDarkMode)
      : AppColors.expenseFor(isDarkMode);

  void _closeKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
    closeCalculatorKeyboard();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// คืนข้อความ error ถ้าข้อมูลไม่ครบ
  String? _validate(String name, double? amount) {
    if (name.isEmpty) return 'กรุณากรอกชื่อรายการ';
    if (amount == null || amount <= 0) return 'กรุณากรอกจำนวนเงินมากกว่า 0';
    return null;
  }

  Future<void> _save() async {
    _closeKeyboard();
    final name = _nameController.text.trim();
    final amount = calculatorAmount;
    final error = _validate(name, amount);
    if (error != null) {
      _showMessage(error);
      return;
    }

    final provider = context.read<CashFlowForecastProvider>();
    setState(() => _isLoading = true);
    try {
      final existing = widget.item;
      if (existing == null) {
        await provider.addItem(
          name: name,
          amount: amount!,
          direction: _direction,
          period: _period,
        );
      } else {
        await provider.updateItem(
          existing.copyWith(
            name: name,
            amount: amount,
            direction: _direction,
            period: _period,
          ),
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('FixedCashFlowItemForm: save error: $e');
      if (mounted) _showMessage('บันทึกรายการไม่สำเร็จ กรุณาลองใหม่');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _delete() async {
    final item = widget.item;
    if (item == null) return;
    _closeKeyboard();
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'ลบรายการ',
      message: 'ต้องการลบ "${item.name}" ออกจาก${item.period.label}?',
      confirmLabel: 'ลบ',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => _isLoading = true);
    try {
      await context.read<CashFlowForecastProvider>().deleteItem(item.id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('FixedCashFlowItemForm: delete error: $e');
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
              _buildDirectionTabs(),
              const SizedBox(height: 14),
              AppAmountHeroCard(
                controller: _amountController,
                focusNode: _amountFocusNode,
                accentColor: _accentColor(isDarkMode),
              ),
              const AppSectionHeader(
                'ข้อมูลรายการ',
                padding: _sectionHeaderPadding,
              ),
              AppInsetCard(
                margin: EdgeInsets.zero,
                children: [_buildNameRow(isDarkMode)],
              ),
              cashFlowNote(
                'ใส่เฉพาะเงินเข้า หรือรายจ่ายที่จ่ายจากบัญชีโดยตรง '
                'ไม่ต้องใส่รายการที่รูดบัตร จ่ายบัตร หรืออยู่ในงบ/แผนออมแล้ว '
                'เพราะนับให้อยู่แล้ว',
                isDarkMode,
              ),
              const AppSectionHeader('งวด', padding: _sectionHeaderPadding),
              buildCashFlowPeriodTabs(
                _period,
                (period) => setState(() => _period = period),
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
      _isEditing ? 'แก้ไขรายการ' : 'เพิ่มรายการ',
      style: TextStyle(
        color: AppColors.textPrimaryFor(isDarkMode),
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),
    actions: [AppSaveButton(onPressed: _save, isLoading: _isLoading)],
  );

  Widget _buildDirectionTabs() => AppSegmentedTabs(
    segments: [
      for (final direction in const [
        CashFlowDirection.outgoing,
        CashFlowDirection.incoming,
      ])
        AppSegment(
          label: direction.label,
          isSelected: _direction == direction,
          onTap: () => setState(() => _direction = direction),
        ),
    ],
  );

  Widget _buildNameRow(bool isDarkMode) {
    final textSecondary = AppColors.textSecondaryFor(isDarkMode);
    return AppFormRow(
      icon: Icons.edit_note_rounded,
      label: 'ชื่อ',
      trailing: TextField(
        controller: _nameController,
        textAlign: TextAlign.right,
        onTap: closeCalculatorKeyboard,
        onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
        decoration: InputDecoration(
          hintText: 'เช่น ค่าบ้าน, โบนัส',
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
