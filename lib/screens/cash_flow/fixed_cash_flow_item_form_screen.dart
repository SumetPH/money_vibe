import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/fixed_cash_flow_item.dart';
import '../../providers/cash_flow_forecast_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../widgets/app_bar_buttons.dart';
import '../../widgets/app_confirm_dialog.dart';
import '../../widgets/app_inset_card.dart';
import '../../widgets/app_switch.dart';
import '../../widgets/day_of_month_picker_sheet.dart';

/// ฟอร์มเพิ่ม/แก้ไข Fixed cash-flow item
class FixedCashFlowItemFormScreen extends StatefulWidget {
  final FixedCashFlowItem? item;

  const FixedCashFlowItemFormScreen({super.key, this.item});

  @override
  State<FixedCashFlowItemFormScreen> createState() =>
      _FixedCashFlowItemFormScreenState();
}

class _FixedCashFlowItemFormScreenState
    extends State<FixedCashFlowItemFormScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late CashFlowDirection _direction;
  int? _dayOfMonth;
  late bool _isPayday;
  bool _isLoading = false;

  bool get _isEditing => widget.item != null;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _nameController = TextEditingController(text: item?.name ?? '');
    _amountController = TextEditingController(
      text: item == null ? '' : item.amount.toStringAsFixed(2),
    );
    _direction = item?.direction ?? CashFlowDirection.outgoing;
    _dayOfMonth = item?.dayOfMonth;
    _isPayday = item?.isPayday ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _closeKeyboard() => FocusManager.instance.primaryFocus?.unfocus();

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// คืนข้อความ error ถ้าข้อมูลไม่ครบ
  String? _validate(String name, double? amount) {
    if (name.isEmpty) return 'กรุณากรอกชื่อรายการ';
    if (amount == null || amount <= 0) return 'กรุณากรอกจำนวนเงินมากกว่า 0';
    if (_dayOfMonth == null) return 'กรุณาเลือกวันที่ของเดือน';
    return null;
  }

  Future<void> _save() async {
    _closeKeyboard();
    final name = _nameController.text.trim();
    final amount = double.tryParse(_amountController.text.replaceAll(',', ''));
    final error = _validate(name, amount);
    if (error != null) {
      _showMessage(error);
      return;
    }

    final provider = context.read<CashFlowForecastProvider>();
    final isPayday = _isPayday && _direction == CashFlowDirection.incoming;
    setState(() => _isLoading = true);
    try {
      final existing = widget.item;
      if (existing == null) {
        await provider.addItem(
          name: name,
          amount: amount!,
          dayOfMonth: _dayOfMonth!,
          direction: _direction,
          isPayday: isPayday,
        );
      } else {
        await provider.updateItem(
          existing.copyWith(
            name: name,
            amount: amount,
            dayOfMonth: _dayOfMonth,
            direction: _direction,
            isPayday: isPayday,
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
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'ลบรายการประจำ',
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

  Future<void> _pickDay() async {
    _closeKeyboard();
    final pick = await showDayOfMonthPickerSheet(
      context: context,
      title: 'เลือกวันที่ของเดือน',
      selectedDay: _dayOfMonth,
    );
    if (pick == null || !mounted) return;
    setState(() => _dayOfMonth = pick.day);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.select<SettingsProvider, bool>(
      (s) => s.isDarkMode,
    );
    final bgColor = AppColors.backgroundFor(isDarkMode);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: _buildAppBar(bgColor, isDarkMode),
      body: AbsorbPointer(
        absorbing: _isLoading,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
          children: [
            AppInsetCard(
              children: [
                _DirectionSelector(
                  value: _direction,
                  isDarkMode: isDarkMode,
                  onChanged: (d) => setState(() => _direction = d),
                ),
                const AppCardDivider(indent: 16),
                _AmountField(
                  controller: _amountController,
                  isDarkMode: isDarkMode,
                ),
              ],
            ),
            const AppSectionHeader('ข้อมูลรายการ'),
            _buildDetailsCard(isDarkMode),
            if (_isEditing)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                child: _DeleteButton(onTap: _delete, isDarkMode: isDarkMode),
              ),
          ],
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
      _isEditing ? 'แก้ไขรายการประจำ' : 'เพิ่มรายการประจำ',
      style: TextStyle(
        color: AppColors.textPrimaryFor(isDarkMode),
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),
    actions: [AppSaveButton(onPressed: _save, isLoading: _isLoading)],
  );

  Widget _buildDetailsCard(bool isDarkMode) {
    final textPrimary = AppColors.textPrimaryFor(isDarkMode);
    final textSecondary = AppColors.textSecondaryFor(isDarkMode);
    const divider = AppCardDivider(indent: 60, endIndent: 16);

    return AppInsetCard(
      children: [
        _FormRow(
          icon: Icons.edit_note_rounded,
          label: 'ชื่อ',
          isDarkMode: isDarkMode,
          trailing: TextField(
            controller: _nameController,
            textAlign: TextAlign.right,
            onTapOutside: (_) => _closeKeyboard(),
            decoration: _plainDecoration(
              'เช่น เงินเดือน, ค่าบ้าน',
              textSecondary,
            ),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
        ),
        divider,
        InkWell(
          onTap: _pickDay,
          child: _FormRow(
            icon: Icons.calendar_today_rounded,
            label: 'วันที่',
            isDarkMode: isDarkMode,
            trailing: _ChevronValue(
              text: _dayOfMonth == null ? 'เลือกวัน' : 'ทุกวันที่ $_dayOfMonth',
              isDarkMode: isDarkMode,
            ),
          ),
        ),
        if (_direction == CashFlowDirection.incoming) ...[
          divider,
          _FormRow(
            icon: Icons.work_outline_rounded,
            label: 'เป็นเงินเดือน',
            description: 'ใช้วันนี้เป็นจุดอ้างอิงของการคาดการณ์',
            isDarkMode: isDarkMode,
            trailing: AppSwitch(
              value: _isPayday,
              onChanged: (v) => setState(() => _isPayday = v),
            ),
          ),
        ],
      ],
    );
  }
}

class _ChevronValue extends StatelessWidget {
  final String text;
  final bool isDarkMode;

  const _ChevronValue({required this.text, required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    final textSecondary = AppColors.textSecondaryFor(isDarkMode);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: textSecondary,
          ),
        ),
        const SizedBox(width: 6),
        Icon(
          Icons.chevron_right,
          color: textSecondary.withValues(alpha: 0.5),
          size: 18,
        ),
      ],
    );
  }
}

InputDecoration _plainDecoration(String hint, Color textSecondary) =>
    InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: textSecondary.withValues(alpha: 0.55),
        fontSize: 14,
      ),
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      filled: false,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 12),
    );

class _FormRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? description;
  final Widget trailing;
  final bool isDarkMode;

  const _FormRow({
    required this.icon,
    required this.label,
    required this.trailing,
    required this.isDarkMode,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    final textSecondary = AppColors.textSecondaryFor(isDarkMode);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: textSecondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadii.medium),
            ),
            child: Icon(icon, color: textSecondary, size: 18),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimaryFor(isDarkMode),
                  ),
                ),
                if (description != null)
                  Text(
                    description!,
                    style: TextStyle(fontSize: 12, color: textSecondary),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Align(alignment: Alignment.centerRight, child: trailing),
          ),
        ],
      ),
    );
  }
}

class _AmountField extends StatelessWidget {
  final TextEditingController controller;
  final bool isDarkMode;

  const _AmountField({required this.controller, required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    final textSecondary = AppColors.textSecondaryFor(isDarkMode);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: TextField(
        controller: controller,
        textAlign: TextAlign.right,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
        ],
        onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
        decoration: InputDecoration(
          hintText: '0.00',
          hintStyle: TextStyle(
            color: textSecondary.withValues(alpha: 0.5),
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
          suffixText: ' บาท',
          suffixStyle: TextStyle(color: textSecondary, fontSize: 15),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          isDense: true,
        ),
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimaryFor(isDarkMode),
        ),
      ),
    );
  }
}

class _DirectionSelector extends StatelessWidget {
  final CashFlowDirection value;
  final bool isDarkMode;
  final ValueChanged<CashFlowDirection> onChanged;

  const _DirectionSelector({
    required this.value,
    required this.isDarkMode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: AppColors.insetFillFor(isDarkMode),
          borderRadius: BorderRadius.circular(AppRadii.large),
        ),
        child: Row(
          children: [
            for (final direction in CashFlowDirection.values)
              Expanded(child: _segment(direction)),
          ],
        ),
      ),
    );
  }

  Widget _segment(CashFlowDirection direction) {
    final isSelected = direction == value;
    final accent = direction == CashFlowDirection.incoming
        ? AppColors.incomeFor(isDarkMode)
        : AppColors.expenseFor(isDarkMode);
    return InkWell(
      onTap: () => onChanged(direction),
      borderRadius: BorderRadius.circular(AppRadii.medium),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.raisedFillFor(isDarkMode)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.medium),
        ),
        child: Text(
          direction.label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isSelected ? accent : AppColors.textSecondaryFor(isDarkMode),
          ),
        ),
      ),
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
