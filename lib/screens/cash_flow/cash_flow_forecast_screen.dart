import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../main.dart';
import '../../models/budget.dart';
import '../../models/fixed_cash_flow_item.dart';
import '../../providers/budget_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/cash_flow_forecast_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/monthly_cycle.dart';
import '../../widgets/account_icon_widget.dart';
import '../../theme/app_radii.dart';
import '../../widgets/app_bar_action_button.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_modal_bottom_sheet.dart';
import '../../widgets/app_reorder_mode.dart';
import '../../widgets/app_switch.dart';
import '../../widgets/app_form_row.dart';
import '../../widgets/app_inset_card.dart';
import '../../widgets/app_segmented_tabs.dart';
import '../../widgets/day_of_month_picker_sheet.dart';
import '../../widgets/app_status_chip.dart';
import 'cash_flow_forecast_scope.dart';
import 'cash_flow_section.dart';
import 'period_list_sections.dart';
import 'liquid_account_picker_sheet.dart';
import 'next_period_section.dart';

/// หน้ารายละเอียดของ Cash-flow forecast: ที่มาของตัวเลข, ลิสต์จำลองเงินเข้าออก/อยากซื้อ
/// แยกงวดนี้และงวดถัดไป และเลือก liquid account
class CashFlowForecastScreen extends StatefulWidget {
  const CashFlowForecastScreen({super.key});

  @override
  State<CashFlowForecastScreen> createState() => _CashFlowForecastScreenState();
}

enum _ForecastTab { current, next }

class _CashFlowForecastScreenState extends State<CashFlowForecastScreen> {
  _ForecastTab _tab = _ForecastTab.current;
  bool _isReorderMode = false;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.select<SettingsProvider, bool>(
      (s) => s.isDarkMode,
    );
    final forecast = watchCashFlowForecast(context);
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
              _isReorderMode ? 'คาดการณ์เงินคงเหลือ' : 'การวางแผนการเงิน',
              style: TextStyle(
                color: AppColors.textSecondaryFor(isDarkMode),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              _isReorderMode ? 'จัดเรียง' : 'คาดการณ์เงินคงเหลือ',
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
          if (_isReorderMode)
            AppReorderDoneButton(
              onPressed: () => setState(() => _isReorderMode = false),
            )
          else if (forecast != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: AppBarActionButton(
                icon: Icon(
                  Icons.more_horiz_rounded,
                  color: AppColors.textPrimaryFor(isDarkMode),
                ),
                tooltip: 'ตัวเลือกเพิ่มเติม',
                onPressed: () => _showMenuSheet(isDarkMode),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
          children: forecast == null
              ? _buildWithoutAnchor(isDarkMode)
              : _buildForecast(
                  forecast,
                  watchNextPeriodForecast(context, forecast),
                  isDarkMode,
                ),
        ),
      ),
    );
  }

  List<Widget> _buildWithoutAnchor(bool isDarkMode) => [
    const _AnchorDayCard(),
    cashFlowNote(
      'ตั้งวันเคลียร์ยอด (วันที่เงินเดือนเข้าและจ่ายหนี้ต่าง ๆ) '
      'เพื่อดูว่าหลังเคลียร์ทุกอย่างจะเหลือเงินเท่าไหร่',
      isDarkMode,
    ),
  ];

  List<Widget> _buildForecast(
    CashFlowForecast forecast,
    NextPeriodForecast? next,
    bool isDarkMode,
  ) => [
    if (_isReorderMode)
      const AppReorderBanner(
        message: 'แตะค้างที่ไอคอนลากเพื่อจัดเรียงรายการเงินเข้าออกและอยากซื้อ',
      ),
    _buildTabs(hasNext: next != null),
    ...switch (_tab) {
      _ForecastTab.next when next != null => _buildNextTab(next, isDarkMode),
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
      ],
    ),
  );

  // ทั้งสองแท็บเริ่มจากลิสต์จำลองของงวดนั้น แล้วตามด้วยยอดที่คำนวณจากข้อมูลจริง
  List<Widget> _buildNextTab(NextPeriodForecast next, bool isDarkMode) => [
    NextPeriodHero(forecast: next, isDarkMode: isDarkMode),
    ...cashFlowItemSections(
      next.items,
      CashFlowPeriod.next,
      isDarkMode,
      isReorderMode: _isReorderMode,
    ),
    ...purchaseSections(
      next.purchases,
      next.purchaseTotal,
      CashFlowPeriod.next,
      isDarkMode,
      isReorderMode: _isReorderMode,
    ),
    ...nextPeriodDetailSections(next, isDarkMode),
  ];

  List<Widget> _buildCurrentTab(CashFlowForecast forecast, bool isDarkMode) => [
    _SummaryHero(forecast: forecast, isDarkMode: isDarkMode),

    ...cashFlowItemSections(
      forecast.items,
      CashFlowPeriod.current,
      isDarkMode,
      isReorderMode: _isReorderMode,
    ),
    ...purchaseSections(
      forecast.purchases,
      forecast.purchaseTotal,
      CashFlowPeriod.current,
      isDarkMode,
      isReorderMode: _isReorderMode,
    ),

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

    ...forecastBudgetSections(
      forecast.budgetLines,
      forecast.savingsPlans,
      forecast.budgetTotal,
      forecast.savingsTotal,
      isDarkMode,
      periodEnd: forecast.windowEnd,
      periodLabel: 'งวดนี้',
      budgetEmptyText:
          _closedCycleText(BudgetType.expense) ?? 'ยังไม่มีงบรายจ่าย',
      savingsEmptyText:
          _closedCycleText(BudgetType.savings) ?? 'ยังไม่มีแผนออมในงบประมาณ',
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

    const AppSectionHeader('ตั้งค่า'),
    const _AnchorDayCard(),
    cashFlowNote(
      'วันที่เงินเดือนเข้าและจ่ายหนี้ต่าง ๆ งวดจะเปลี่ยนเมื่อผ่านวันนี้ไป '
      'ไม่ใช่วันสรุปยอดบัตร (ตั้งแยกในบัญชีบัตรแต่ละใบ)',
      isDarkMode,
    ),
  ];

  /// เมนูตัวเลือก: เปิดปิดโหมดจัดเรียง (สวิตช์เปลี่ยนโหมดแล้วปิด sheet ทันที)
  void _showMenuSheet(bool isDarkMode) {
    final textColor = AppColors.textPrimaryFor(isDarkMode);
    final textSecondary = AppColors.textSecondaryFor(isDarkMode);
    final incomeColor = AppColors.incomeFor(isDarkMode);
    showAppModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppModalBottomSheetHeader(title: 'ตัวเลือกคาดการณ์'),
              const SizedBox(height: 8),
              AppInsetCard(
                margin: EdgeInsets.zero,
                children: [
                  ListTile(
                    leading: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: incomeColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppRadii.medium),
                      ),
                      child: Icon(
                        Icons.reorder_rounded,
                        color: incomeColor,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      'จัดเรียงลำดับ',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      'เปิดโหมดลากสลับตำแหน่งรายการเงินเข้าออกและอยากซื้อ',
                      style: TextStyle(color: textSecondary, fontSize: 12),
                    ),
                    trailing: AppSwitch(
                      value: _isReorderMode,
                      onChanged: (value) {
                        setState(() => _isReorderMode = value);
                        Navigator.pop(sheetContext);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ข้อความเมื่อมีงบแต่ไม่มีรอบงบที่จบก่อนวันเคลียร์ยอด (รอบงบปิดไปแล้ว)
  /// null เมื่อยังไม่มีงบประเภทนี้
  String? _closedCycleText(BudgetType type) {
    final hasBudgets = context.read<BudgetProvider>().budgets.any(
      (b) => b.type == type && !b.isHidden,
    );
    if (!hasBudgets) return null;
    final startDay = context.read<SettingsProvider>().monthlyCycleStartDay;
    final now = DateTime.now();
    final newCycleStart = monthlyCyclePeriod(
      monthlyCycleReportingMonth(now, startDay),
      startDay,
    ).start;
    final closedEnd = DateTime(
      newCycleStart.year,
      newCycleStart.month,
      newCycleStart.day - 1,
    );
    return type == BudgetType.savings
        ? 'รอบที่จบ ${formatCashFlowDate(closedEnd)} ปิดแล้ว '
              'แผนออมของรอบใหม่ (เริ่ม ${formatCashFlowDate(newCycleStart)}) อยู่ในแท็บงวดถัดไป'
        : 'รอบงบที่จบ ${formatCashFlowDate(closedEnd)} ปิดแล้ว '
              'ยอดที่ใช้จริงนับอยู่ในยอดบัตรและเงินในบัญชีแล้ว · '
              'งบรอบใหม่ (เริ่ม ${formatCashFlowDate(newCycleStart)}) อยู่ในแท็บงวดถัดไป';
  }
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
        _metric('งบรายจ่าย', -forecast.budgetTotal),
        _metric('แผนออม', -forecast.savingsTotal),
        _metric('อยากซื้อ', -forecast.purchaseTotal),
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
