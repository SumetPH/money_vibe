import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/fixed_cash_flow_item.dart';
import '../../providers/cash_flow_forecast_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../widgets/app_amount_hero_card.dart';
import '../../widgets/app_bar_buttons.dart';
import '../../widgets/app_confirm_dialog.dart';
import '../../widgets/app_form_row.dart';
import '../../widgets/app_inset_card.dart';
import '../../widgets/app_segmented_tabs.dart';
import '../../widgets/calculator_keyboard_host.dart';
import '../../widgets/day_of_month_picker_sheet.dart';
import 'cash_flow_forecast_scope.dart';

/// ฟอร์มเพิ่ม/แก้ไขรายการเงินเข้าออก (ทุกเดือนหรือครั้งเดียว)
class FixedCashFlowItemFormScreen extends StatefulWidget {
  final FixedCashFlowItem? item;

  const FixedCashFlowItemFormScreen({super.key, this.item});

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
  late bool _isOneTime;
  int? _dayOfMonth;
  DateTime? _oneTimeDate;
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
    _isOneTime = item?.isOneTime ?? false;
    _dayOfMonth = item?.dayOfMonth;
    _oneTimeDate = item?.oneTimeDate;
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
    if (_isOneTime && _oneTimeDate == null) return 'กรุณาเลือกวันที่';
    if (!_isOneTime && _dayOfMonth == null) return 'กรุณาเลือกวันที่ในเดือน';
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
    final dayOfMonth = _isOneTime ? null : _dayOfMonth;
    final oneTimeDate = _isOneTime ? _oneTimeDate : null;
    setState(() => _isLoading = true);
    try {
      final existing = widget.item;
      if (existing == null) {
        await provider.addItem(
          name: name,
          amount: amount!,
          direction: _direction,
          dayOfMonth: dayOfMonth,
          oneTimeDate: oneTimeDate,
        );
      } else {
        await provider.updateItem(
          FixedCashFlowItem(
            id: existing.id,
            name: name,
            amount: amount!,
            direction: _direction,
            dayOfMonth: dayOfMonth,
            oneTimeDate: oneTimeDate,
            sortOrder: existing.sortOrder,
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
      message: 'ต้องการลบ "${item.name}" และสถานะการติ๊กทั้งหมดของรายการนี้?',
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

  Future<void> _pickDayOfMonth() async {
    _closeKeyboard();
    final pick = await showDayOfMonthPickerSheet(
      context: context,
      title: 'เลือกวันที่ในเดือน',
      selectedDay: _dayOfMonth,
    );
    if (pick == null || !mounted) return;
    setState(() => _dayOfMonth = pick.day);
  }

  Future<void> _pickOneTimeDate() async {
    _closeKeyboard();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _oneTimeDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null || !mounted) return;
    setState(() => _oneTimeDate = picked);
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
              const AppSectionHeader(
                'กำหนดการ',
                padding: _sectionHeaderPadding,
              ),
              _buildScheduleTabs(),
              const SizedBox(height: 10),
              AppInsetCard(
                margin: EdgeInsets.zero,
                children: [_buildScheduleRow()],
              ),
              if (_isEditing)
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: _DeleteButton(onTap: _delete, isDarkMode: isDarkMode),
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

  Widget _buildScheduleTabs() => AppSegmentedTabs(
    segments: [
      AppSegment(
        label: 'ทุกเดือน',
        isSelected: !_isOneTime,
        onTap: () => setState(() => _isOneTime = false),
      ),
      AppSegment(
        label: 'ครั้งเดียว',
        isSelected: _isOneTime,
        onTap: () => setState(() => _isOneTime = true),
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

  Widget _buildScheduleRow() {
    final date = _oneTimeDate;
    if (_isOneTime) {
      return AppFormRow(
        icon: Icons.event_rounded,
        label: 'วันที่',
        value: date == null
            ? 'เลือกวันที่'
            : '${formatCashFlowDate(date)} ${date.year}',
        onTap: _pickOneTimeDate,
      );
    }
    return AppFormRow(
      icon: Icons.calendar_today_rounded,
      label: 'วันที่ในเดือน',
      value: _dayOfMonth == null ? 'เลือกวัน' : 'ทุกวันที่ $_dayOfMonth',
      onTap: _pickDayOfMonth,
    );
  }
}

class _DeleteButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool isDarkMode;

  const _DeleteButton({required this.onTap, required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    final expense = AppColors.expenseFor(isDarkMode);
    return Material(
      color: AppColors.surfaceFor(isDarkMode),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.xLarge),
        side: BorderSide(color: expense.withValues(alpha: 0.25)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.delete_outline_rounded, color: expense, size: 20),
              const SizedBox(width: 8),
              Text(
                'ลบรายการนี้',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: expense,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
