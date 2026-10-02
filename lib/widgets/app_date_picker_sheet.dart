import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../utils/thai_date.dart';
import 'app_modal_bottom_sheet.dart';

final DateTime _defaultFirstDate = DateTime(2000);
final DateTime _defaultLastDate = DateTime(2100);
const double _timePickerHeight = 150;

/// เลือกวันที่เดียวด้วยปฏิทินใน bottom sheet (เดือนภาษาไทย ปี ค.ศ.)
///
/// เมื่อ [includeTime] เป็น `true` จะมีวงล้อเลือกเวลาใน sheet เดียวกัน และคืนค่า
/// วันที่พร้อมเวลา; ถ้าไม่ จะคืนเฉพาะวันที่ (เวลา 00:00).
Future<DateTime?> showAppDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
  String title = 'เลือกวันที่',
  bool includeTime = false,
}) async {
  final result = await showAppModalBottomSheet<List<DateTime>>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _AppDatePickerSheet(
      title: title,
      calendarType: CalendarDatePicker2Type.single,
      initialValue: [initialDate],
      firstDate: firstDate ?? _defaultFirstDate,
      lastDate: lastDate ?? _defaultLastDate,
      includeTime: includeTime,
    ),
  );
  if (result == null || result.isEmpty) return null;
  return result.first;
}

/// เลือกช่วงวันที่ (รวมวันเริ่มและวันสิ้นสุด) ด้วยปฏิทินใน bottom sheet
Future<DateTimeRange?> showAppDateRangePicker({
  required BuildContext context,
  DateTimeRange? initialRange,
  DateTime? firstDate,
  DateTime? lastDate,
  String title = 'เลือกช่วงวันที่',
}) async {
  final result = await showAppModalBottomSheet<List<DateTime>>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _AppDatePickerSheet(
      title: title,
      calendarType: CalendarDatePicker2Type.range,
      initialValue: initialRange == null
          ? const []
          : [initialRange.start, initialRange.end],
      firstDate: firstDate ?? _defaultFirstDate,
      lastDate: lastDate ?? _defaultLastDate,
      includeTime: false,
    ),
  );
  if (result == null || result.isEmpty) return null;
  // แตะวันเดียวในโหมดช่วง = ช่วงหนึ่งวัน
  return DateTimeRange(start: result.first, end: result.last);
}

class _DatePreset {
  final String label;
  final List<DateTime> value;

  const _DatePreset(this.label, this.value);
}

class _AppDatePickerSheet extends StatefulWidget {
  final String title;
  final CalendarDatePicker2Type calendarType;
  final List<DateTime> initialValue;
  final DateTime firstDate;
  final DateTime lastDate;
  final bool includeTime;

  const _AppDatePickerSheet({
    required this.title,
    required this.calendarType,
    required this.initialValue,
    required this.firstDate,
    required this.lastDate,
    required this.includeTime,
  });

  @override
  State<_AppDatePickerSheet> createState() => _AppDatePickerSheetState();
}

class _AppDatePickerSheetState extends State<_AppDatePickerSheet> {
  late List<DateTime> _value;
  late DateTime _displayedMonth;
  late TimeOfDay _time;

  bool get _isRange => widget.calendarType == CalendarDatePicker2Type.range;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue.map(DateUtils.dateOnly).toList();
    final anchor = _value.isNotEmpty ? _value.first : DateTime.now();
    _displayedMonth = DateTime(anchor.year, anchor.month);
    _time = TimeOfDay.fromDateTime(
      widget.initialValue.isNotEmpty
          ? widget.initialValue.first
          : DateTime.now(),
    );
  }

  List<_DatePreset> _presets() {
    final today = DateUtils.dateOnly(DateTime.now());
    final presets = _isRange
        ? [
            _DatePreset('7 วัน', [
              today.subtract(const Duration(days: 6)),
              today,
            ]),
            _DatePreset('30 วัน', [
              today.subtract(const Duration(days: 29)),
              today,
            ]),
            _DatePreset('เดือนนี้', [DateTime(today.year, today.month), today]),
            _DatePreset('เดือนที่แล้ว', [
              DateTime(today.year, today.month - 1),
              DateTime(today.year, today.month, 0),
            ]),
          ]
        : [
            _DatePreset('วันนี้', [today]),
            _DatePreset('เมื่อวาน', [today.subtract(const Duration(days: 1))]),
          ];
    return presets
        .where(
          (preset) => preset.value.every(
            (date) =>
                !date.isBefore(DateUtils.dateOnly(widget.firstDate)) &&
                !date.isAfter(widget.lastDate),
          ),
        )
        .toList();
  }

  bool _isPresetSelected(_DatePreset preset) =>
      preset.value.length == _value.length &&
      List.generate(
        _value.length,
        (i) => DateUtils.isSameDay(preset.value[i], _value[i]),
      ).every((isSame) => isSame);

  void _applyPreset(_DatePreset preset) {
    final start = preset.value.first;
    setState(() {
      _value = preset.value;
      _displayedMonth = DateTime(start.year, start.month);
    });
  }

  void _confirm() {
    final result = widget.includeTime
        ? _value
              .map(
                (date) => DateTime(
                  date.year,
                  date.month,
                  date.day,
                  _time.hour,
                  _time.minute,
                ),
              )
              .toList()
        : _value;
    Navigator.pop(context, result);
  }

  String _summaryText() {
    if (_value.isEmpty) return _isRange ? 'เลือกวันเริ่มต้น' : 'เลือกวันที่';
    if (!_isRange) return formatThaiShortDate(_value.first);
    if (_value.length == 1) {
      return '${formatThaiShortDate(_value.first)} – เลือกวันสิ้นสุด';
    }
    return '${formatThaiShortDate(_value.first)} – '
        '${formatThaiShortDate(_value.last)}';
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isDarkMode = settings.isDarkMode;
    final accent = AppColors.accentFor(isDarkMode, settings.themeColor);
    final presets = _presets();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppModalBottomSheetHeader(title: widget.title),
            if (presets.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final preset in presets)
                    _PresetChip(
                      label: preset.label,
                      isSelected: _isPresetSelected(preset),
                      accent: accent,
                      isDarkMode: isDarkMode,
                      onTap: () => _applyPreset(preset),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            _buildCalendar(isDarkMode, accent),
            if (widget.includeTime) ...[
              const SizedBox(height: 12),
              _buildTimePicker(isDarkMode),
            ],
            const SizedBox(height: 12),
            Text(
              _summaryText(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondaryFor(isDarkMode),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            _ConfirmButton(
              accent: accent,
              onPressed: _value.isEmpty ? null : _confirm,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendar(bool isDarkMode, Color accent) {
    final textPrimary = AppColors.textPrimaryFor(isDarkMode);
    final textSecondary = AppColors.textSecondaryFor(isDarkMode);
    final onAccent = _onColor(accent);

    final config = CalendarDatePicker2Config(
      calendarType: widget.calendarType,
      firstDate: widget.firstDate,
      lastDate: widget.lastDate,
      currentDate: DateTime.now(),
      firstDayOfWeek: 0,
      weekdayLabels: thaiWeekdayShortNames,
      weekdayLabelTextStyle: TextStyle(
        color: textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      disableMonthPicker: true,
      modePickerTextHandler: ({required monthDate, isMonthPicker}) =>
          '${thaiMonthNames[monthDate.month - 1]} ${monthDate.year}',
      controlsTextStyle: TextStyle(
        color: textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
      customModePickerIcon: Icon(
        Icons.keyboard_arrow_down_rounded,
        size: 20,
        color: textSecondary,
      ),
      lastMonthIcon: Icon(Icons.chevron_left_rounded, color: textPrimary),
      nextMonthIcon: Icon(Icons.chevron_right_rounded, color: textPrimary),
      dayTextStyle: TextStyle(color: textPrimary, fontSize: 14),
      disabledDayTextStyle: TextStyle(
        color: textSecondary.withValues(alpha: 0.35),
        fontSize: 14,
      ),
      todayTextStyle: TextStyle(
        color: accent,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
      selectedDayTextStyle: TextStyle(
        color: onAccent,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
      selectedRangeDayTextStyle: TextStyle(color: textPrimary, fontSize: 14),
      selectedDayHighlightColor: accent,
      selectedRangeHighlightColor: accent.withValues(alpha: 0.18),
      yearTextStyle: TextStyle(color: textPrimary, fontSize: 15),
      selectedYearTextStyle: TextStyle(
        color: onAccent,
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
      daySplashColor: accent.withValues(alpha: 0.12),
    );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.insetFillFor(isDarkMode),
        borderRadius: BorderRadius.circular(AppRadii.xLarge),
      ),
      child: CalendarDatePicker2(
        config: config,
        value: _value,
        // ส่งเดือนที่แสดงกลับไปทุกครั้ง เพื่อไม่ให้ rebuild ดีดกลับเดือนเดิม
        displayedMonthDate: _displayedMonth,
        onDisplayedMonthChanged: (month) => _displayedMonth = month,
        onValueChanged: (dates) => setState(() {
          _value = dates.map(DateUtils.dateOnly).toList()..sort();
        }),
      ),
    );
  }

  Widget _buildTimePicker(bool isDarkMode) {
    final now = DateTime.now();
    return Container(
      height: _timePickerHeight,
      decoration: BoxDecoration(
        color: AppColors.insetFillFor(isDarkMode),
        borderRadius: BorderRadius.circular(AppRadii.xLarge),
      ),
      child: CupertinoTheme(
        data: CupertinoThemeData(
          brightness: isDarkMode ? Brightness.dark : Brightness.light,
          textTheme: CupertinoTextThemeData(
            dateTimePickerTextStyle: GoogleFonts.ibmPlexSansThai(
              color: AppColors.textPrimaryFor(isDarkMode),
              fontSize: 20,
            ),
          ),
        ),
        child: CupertinoDatePicker(
          mode: CupertinoDatePickerMode.time,
          use24hFormat: true,
          initialDateTime: DateTime(
            now.year,
            now.month,
            now.day,
            _time.hour,
            _time.minute,
          ),
          onDateTimeChanged: (value) => _time = TimeOfDay.fromDateTime(value),
        ),
      ),
    );
  }
}

Color _onColor(Color background) =>
    ThemeData.estimateBrightnessForColor(background) == Brightness.dark
    ? Colors.white
    : Colors.black;

class _PresetChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color accent;
  final bool isDarkMode;
  final VoidCallback onTap;

  const _PresetChip({
    required this.label,
    required this.isSelected,
    required this.accent,
    required this.isDarkMode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? accent.withValues(alpha: 0.15)
          : AppColors.raisedFillFor(isDarkMode),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.full),
        side: BorderSide(
          color: isSelected ? accent : AppColors.borderFor(isDarkMode),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? accent : AppColors.textPrimaryFor(isDarkMode),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _ConfirmButton extends StatelessWidget {
  final Color accent;
  final VoidCallback? onPressed;

  const _ConfirmButton({required this.accent, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;
    final background = isEnabled ? accent : accent.withValues(alpha: 0.4);
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(AppRadii.full),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Text(
            'ตกลง',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _onColor(accent),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
