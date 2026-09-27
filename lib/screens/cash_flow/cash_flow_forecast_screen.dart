import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../main.dart';
import '../../models/fixed_cash_flow_item.dart';
import '../../providers/cash_flow_forecast_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/cash_flow_forecast_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/account_icon_widget.dart';
import '../../widgets/app_bar_action_button.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_form_row.dart';
import '../../widgets/app_inset_card.dart';
import '../../widgets/app_segmented_tabs.dart';
import '../../widgets/day_of_month_picker_sheet.dart';
import '../../widgets/app_status_chip.dart';
import 'cash_flow_forecast_scope.dart';
import 'cash_flow_section.dart';
import 'fixed_cash_flow_item_form_screen.dart';
import 'liquid_account_picker_sheet.dart';
import 'next_period_section.dart';

/// หน้ารายละเอียดของ Cash-flow forecast: ที่มาของตัวเลข, ติ๊ก paid mark,
/// เลือก liquid account และจัดการรายการเงินเข้าออกประจำ
class CashFlowForecastScreen extends StatefulWidget {
  const CashFlowForecastScreen({super.key});

  @override
  State<CashFlowForecastScreen> createState() => _CashFlowForecastScreenState();
}

enum _ForecastTab { current, next, manage }

class _CashFlowForecastScreenState extends State<CashFlowForecastScreen> {
  _ForecastTab _tab = _ForecastTab.current;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.select<SettingsProvider, bool>(
      (s) => s.isDarkMode,
    );
    final forecast = watchCashFlowForecast(context);
    final items = context.watch<CashFlowForecastProvider>().items;
    final bgColor = AppColors.backgroundFor(isDarkMode);

    final isLargeScreen = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      backgroundColor: bgColor,
      drawer: isLargeScreen
          ? null
          : const AppDrawer(currentRoute: '/cash-flow'),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 100,
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: isLargeScreen ? 24 : 16,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'การวางแผนการเงิน',
              style: TextStyle(
                color: AppColors.textSecondaryFor(isDarkMode),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'คาดการณ์เงินคงเหลือ',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textPrimaryFor(isDarkMode),
                fontSize: 30,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: AppBarActionButton(
              icon: Icon(
                Icons.add_rounded,
                color: AppColors.textPrimaryFor(isDarkMode),
              ),
              tooltip: 'เพิ่มรายการเงินเข้าออก',
              onPressed: () => _openItemForm(context),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
          children: forecast == null
              ? _buildWithoutAnchor(items, isDarkMode)
              : _buildForecast(
                  forecast,
                  watchNextPeriodForecast(context, forecast),
                  items,
                  isDarkMode,
                ),
        ),
      ),
    );
  }

  List<Widget> _buildWithoutAnchor(
    List<FixedCashFlowItem> items,
    bool isDarkMode,
  ) => [
    const _AnchorDayCard(),
    cashFlowNote(
      'ตั้งวันเคลียร์ยอด (วันที่เงินเดือนเข้าและจ่ายหนี้ต่าง ๆ) '
      'แล้วเพิ่มรายการเงินเข้าออก เพื่อดูว่าหลังเคลียร์ทุกอย่างจะเหลือเงินเท่าไหร่',
      isDarkMode,
    ),
    if (items.isNotEmpty) ..._itemListSection(items, isDarkMode),
  ];

  List<Widget> _buildForecast(
    CashFlowForecast forecast,
    NextPeriodForecast? next,
    List<FixedCashFlowItem> items,
    bool isDarkMode,
  ) => [
    _buildTabs(hasNext: next != null),
    ...switch (_tab) {
      _ForecastTab.next when next != null => _buildNextTab(next, isDarkMode),
      _ForecastTab.manage => _buildManageTab(items, isDarkMode),
      _ => _buildCurrentTab(forecast, isDarkMode),
    },
  ];

  Widget _buildTabs({required bool hasNext}) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    child: AppSegmentedTabs(
      segments: [
        AppSegment(
          label: 'งวดนี้',
          // แท็บงวดถัดไปหายไปชั่วคราวเมื่อยังคำนวณไม่ได้ จึงแสดงงวดนี้แทน
          isSelected:
              _tab == _ForecastTab.current ||
              (_tab == _ForecastTab.next && !hasNext),
          onTap: () => setState(() => _tab = _ForecastTab.current),
        ),
        if (hasNext)
          AppSegment(
            label: 'งวดถัดไป',
            isSelected: _tab == _ForecastTab.next,
            onTap: () => setState(() => _tab = _ForecastTab.next),
          ),
        AppSegment(
          label: 'จัดการ',
          isSelected: _tab == _ForecastTab.manage,
          onTap: () => setState(() => _tab = _ForecastTab.manage),
        ),
      ],
    ),
  );

  // ลำดับ section ของทั้งสองแท็บเรียงตาม metric ใน hero:
  // เงินในบัญชี → เงินเข้าออก → บัตรเครดิต → (งวดถัดไป: งบที่เหลือ → อยากซื้อ)
  List<Widget> _buildNextTab(NextPeriodForecast next, bool isDarkMode) => [
    NextPeriodHero(forecast: next, isDarkMode: isDarkMode),
    ..._occurrenceSection(next.itemLines, isDarkMode),
    ...nextPeriodDetailSections(next, isDarkMode),
  ];

  List<Widget> _buildCurrentTab(CashFlowForecast forecast, bool isDarkMode) => [
    _SummaryHero(forecast: forecast, isDarkMode: isDarkMode),

    ..._occurrenceSection(forecast.itemLines, isDarkMode),

    ...cashFlowSection(
      title:
          'บัตรเครดิต · ${formatAmount(-forecast.cardTotal, showSign: true)} บาท',
      emptyText: 'ไม่มียอดบัตรที่ต้องชำระในงวดนี้',
      rows: [
        for (final line in forecast.cardLines)
          _CardRow(line: line, isDarkMode: isDarkMode),
      ],
      isDarkMode: isDarkMode,
    ),
    cashFlowNote(
      'นับบิลที่สรุปก่อนวันเคลียร์ยอด บิลที่ยังไม่สรุปใช้ยอดที่รูดไปแล้วเป็นยอดประมาณ',
      isDarkMode,
    ),

    ...cashFlowSection(
      title: 'เงินในบัญชี · ${formatAmount(forecast.liquidTotal)} บาท',
      emptyText: 'ยังไม่มีบัญชีเงินสดหรือบัญชีธนาคาร',
      rows: [
        for (final line in forecast.liquidLines.where((l) => l.isIncluded))
          LiquidAccountRow(line: line, isDarkMode: isDarkMode),
        if (forecast.liquidLines.isNotEmpty)
          _LiquidAccountSelectorRow(
            lines: forecast.liquidLines,
            isDarkMode: isDarkMode,
          ),
      ],
      isDarkMode: isDarkMode,
    ),
  ];

  List<Widget> _buildManageTab(
    List<FixedCashFlowItem> items,
    bool isDarkMode,
  ) => [
    const _AnchorDayCard(),
    cashFlowNote(
      'วันที่เงินเดือนเข้าและจ่ายหนี้ต่าง ๆ งวดจะเปลี่ยนเมื่อผ่านวันนี้ไป '
      'ไม่ใช่วันสรุปยอดบัตร (ตั้งแยกในบัญชีบัตรแต่ละใบ)',
      isDarkMode,
    ),
    ..._itemListSection(items, isDarkMode),
  ];

  List<Widget> _occurrenceSection(
    List<CashFlowItemLine> lines,
    bool isDarkMode,
  ) => cashFlowSection(
    title: 'เงินเข้าออก (ติ๊กเมื่อเกิดขึ้นแล้ว)',
    emptyText: 'ยังไม่มีรายการในงวดนี้',
    rows: [
      for (final line in lines)
        _OccurrenceRow(line: line, isDarkMode: isDarkMode),
    ],
    isDarkMode: isDarkMode,
  );

  List<Widget> _itemListSection(
    List<FixedCashFlowItem> items,
    bool isDarkMode,
  ) => cashFlowSection(
    title: 'รายการเงินเข้าออกทั้งหมด',
    emptyText: 'ยังไม่มีรายการ',
    rows: [
      for (final item in sortCashFlowItems(items))
        _ItemRow(item: item, isDarkMode: isDarkMode),
    ],
    isDarkMode: isDarkMode,
  );
}

void _openItemForm(BuildContext context, [FixedCashFlowItem? item]) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => FixedCashFlowItemFormScreen(item: item)),
  );
}

void _showError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

class _SummaryHero extends StatelessWidget {
  final CashFlowForecast forecast;
  final bool isDarkMode;

  const _SummaryHero({required this.forecast, required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    final textSecondary = AppColors.textSecondaryFor(isDarkMode);
    final leftover = forecast.projectedLeftover;
    return AppInsetCard(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'หลังเคลียร์ยอด ${formatCashFlowDate(forecast.windowEnd)} จะเหลือ',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${formatAmount(leftover, showSign: true)} บาท',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            color: AppColors.amountColor(leftover, isDarkMode: isDarkMode),
          ),
        ),
        const SizedBox(height: 12),
        CashFlowTimeline(steps: _timelineSteps(), isDarkMode: isDarkMode),
        const SizedBox(height: 14),
        _metric('เงินในบัญชี ณ วันนี้', forecast.liquidTotal),
        _metric('เงินเข้าที่ยังไม่ติ๊ก', forecast.incomingTotal),
        _metric('เงินออกที่ยังไม่ติ๊ก', -forecast.outgoingTotal),
        _metric('ยอดบัตรที่ต้องชำระ', -forecast.cardTotal),
        if (forecast.warningCount > 0) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: AppStatusChip(
              label: '${forecast.warningCount} รายการต้องตรวจสอบ',
              color: AppColors.saveButtonFor(isDarkMode),
            ),
          ),
        ],
      ],
    );
  }

  /// วันเริ่มรอบ, วันนี้ และวันสุดท้ายของงวด เรียงตามวันที่
  List<CashFlowTimelineStep> _timelineSteps() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return [
      CashFlowTimelineStep('วันนี้', today, isHighlighted: true),
      if (today != forecast.windowStart)
        CashFlowTimelineStep('เริ่มงวด', forecast.windowStart),
      CashFlowTimelineStep('วันเคลียร์', forecast.windowEnd),
    ]..sort((a, b) => a.date.compareTo(b.date));
  }

  Widget _metric(String label, double amount) =>
      CashFlowMetricRow(label: label, amount: amount, isDarkMode: isDarkMode);
}

/// แถวเปิด sheet เลือกบัญชีที่นำมาคำนวณ
class _LiquidAccountSelectorRow extends StatelessWidget {
  final List<LiquidBalanceLine> lines;
  final bool isDarkMode;

  const _LiquidAccountSelectorRow({
    required this.lines,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) => CashFlowSelectorRow(
    label: 'เลือกบัญชีที่นำมาคำนวณ',
    includedCount: lines.where((l) => l.isIncluded).length,
    totalCount: lines.length,
    onTap: () => showLiquidAccountPickerSheet(context),
    isDarkMode: isDarkMode,
  );
}

class _OccurrenceRow extends StatelessWidget {
  final CashFlowItemLine line;
  final bool isDarkMode;

  const _OccurrenceRow({required this.line, required this.isDarkMode});

  Future<void> _toggle(BuildContext context) async {
    try {
      await context.read<CashFlowForecastProvider>().setMarked(
        itemId: line.item.id,
        month: line.monthKey,
        isMarked: !line.isMarked,
      );
    } catch (e) {
      debugPrint('CashFlowForecastScreen: toggle paid mark error: $e');
      if (context.mounted) _showError(context, 'บันทึกสถานะไม่สำเร็จ');
    }
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.textPrimaryFor(isDarkMode);
    final textSecondary = AppColors.textSecondaryFor(isDarkMode);
    final amountColor = line.isMarked
        ? textSecondary.withValues(alpha: 0.6)
        : AppColors.amountColor(line.signedAmount, isDarkMode: isDarkMode);

    return InkWell(
      onTap: () => _openItemForm(context, line.item),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 6, 16, 6),
        child: Row(
          children: [
            IconButton(
              tooltip: line.isMarked ? 'ยกเลิกการติ๊ก' : 'ติ๊กว่าเกิดขึ้นแล้ว',
              onPressed: () => _toggle(context),
              icon: Icon(
                line.isMarked
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: line.isMarked
                    ? AppColors.incomeFor(isDarkMode)
                    : textSecondary.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    line.item.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: line.isMarked ? textSecondary : textPrimary,
                      decoration: line.isMarked
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Wrap(
                    spacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        formatCashFlowDate(line.date),
                        style: TextStyle(fontSize: 12, color: textSecondary),
                      ),
                      if (line.item.isOneTime)
                        AppStatusChip(
                          label: 'ครั้งเดียว',
                          color: AppColors.textSecondaryFor(isDarkMode),
                        ),
                      if (line.isOverdueUnmarked)
                        AppStatusChip(
                          label: 'ยังไม่ติ๊ก',
                          color: AppColors.saveButtonFor(isDarkMode),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Text(
              formatAmount(line.signedAmount, showSign: true),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: amountColor,
                decoration: line.isMarked ? TextDecoration.lineThrough : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardRow extends StatelessWidget {
  final CardObligationLine line;
  final bool isDarkMode;

  const _CardRow({required this.line, required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    final textSecondary = AppColors.textSecondaryFor(isDarkMode);
    final dueDate = line.dueDate;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          AccountIconWidget(
            account: line.account,
            size: 32,
            isDarkMode: isDarkMode,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.account.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimaryFor(isDarkMode),
                  ),
                ),
                const SizedBox(height: 2),
                Wrap(
                  spacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (dueDate != null)
                      Text(
                        'ครบกำหนด ${formatCashFlowDate(dueDate)}',
                        style: TextStyle(fontSize: 12, color: textSecondary),
                      ),
                    if (line.isOverdue)
                      AppStatusChip(
                        label: 'เลยกำหนด',
                        color: AppColors.expenseFor(isDarkMode),
                      ),
                    if (line.hasUnclosedStatement)
                      AppStatusChip(
                        label: 'ยังไม่สรุปยอด',
                        color: AppColors.saveButtonFor(isDarkMode),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Text(
            formatAmount(-line.outstanding, showSign: true),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.amountColor(
                -line.outstanding,
                isDarkMode: isDarkMode,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// แถวตั้งวันเคลียร์ยอด (forecast anchor day) ของการคาดการณ์ (เก็บในเครื่อง)
class _AnchorDayCard extends StatelessWidget {
  const _AnchorDayCard();

  Future<void> _pick(BuildContext context, int? current) async {
    final pick = await showDayOfMonthPickerSheet(
      context: context,
      title: 'เลือกวันเคลียร์ยอด',
      selectedDay: current,
      clearLabel: 'ล้างวันเคลียร์ยอด',
    );
    if (pick == null || !context.mounted) return;
    await context.read<SettingsProvider>().setCashFlowAnchorDay(pick.day);
  }

  @override
  Widget build(BuildContext context) {
    final anchorDay = context.select<SettingsProvider, int?>(
      (s) => s.cashFlowAnchorDay,
    );
    return AppInsetCard(
      children: [
        AppFormRow(
          icon: Icons.event_available_rounded,
          label: 'วันเคลียร์ยอด',
          value: anchorDay == null ? 'ยังไม่ได้ตั้ง' : 'ทุกวันที่ $anchorDay',
          onTap: () => _pick(context, anchorDay),
        ),
      ],
    );
  }
}

class _ItemRow extends StatelessWidget {
  final FixedCashFlowItem item;
  final bool isDarkMode;

  const _ItemRow({required this.item, required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    final signed = item.signedAmount;
    return InkWell(
      onTap: () => _openItemForm(context, item),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimaryFor(isDarkMode),
                    ),
                  ),
                  Text(
                    cashFlowScheduleLabel(item),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondaryFor(isDarkMode),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              formatAmount(signed, showSign: true),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.amountColor(signed, isDarkMode: isDarkMode),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
