import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../main.dart';
import '../../models/fixed_cash_flow_item.dart';
import '../../providers/account_provider.dart';
import '../../providers/cash_flow_forecast_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/cash_flow_forecast_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/account_icon_widget.dart';
import '../../widgets/app_bar_action_button.dart';
import '../../widgets/app_bar_buttons.dart';
import '../../widgets/app_inset_card.dart';
import '../../widgets/app_status_chip.dart';
import '../../widgets/app_switch.dart';
import 'cash_flow_forecast_scope.dart';
import 'fixed_cash_flow_item_form_screen.dart';

/// หน้ารายละเอียดของ Cash-flow forecast: ที่มาของตัวเลข, ติ๊ก paid mark,
/// เลือก liquid account และจัดการรายการเงินเข้าออกประจำ
class CashFlowForecastScreen extends StatelessWidget {
  const CashFlowForecastScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.select<SettingsProvider, bool>(
      (s) => s.isDarkMode,
    );
    final forecast = watchCashFlowForecast(context);
    final items = context.watch<CashFlowForecastProvider>().items;
    final bgColor = AppColors.backgroundFor(isDarkMode);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leadingWidth: 64,
        leading: const AppBackButton(),
        title: Text(
          'คาดการณ์เงินคงเหลือ',
          style: TextStyle(
            color: AppColors.textPrimaryFor(isDarkMode),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: AppBarActionButton(
              icon: const Icon(Icons.add_rounded),
              tooltip: 'เพิ่มรายการประจำ',
              onPressed: () => _openItemForm(context),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
          children: forecast == null
              ? _buildWithoutPayday(items, isDarkMode)
              : _buildForecast(forecast, items, isDarkMode),
        ),
      ),
    );
  }

  List<Widget> _buildWithoutPayday(
    List<FixedCashFlowItem> items,
    bool isDarkMode,
  ) => [
    _note(
      items.isEmpty
          ? 'เพิ่มรายการเงินเข้าออกประจำ เช่น เงินเดือน ค่าบ้าน ค่ารถ '
                'แล้วตั้งรายการเงินเดือนเพื่อดูว่าเงินพอชำระภาระจนถึงเงินเดือนงวดถัดไปไหม'
          : 'ตั้งรายการเงินเข้ารายการหนึ่งเป็น "เงินเดือน" เพื่อเริ่มคาดการณ์',
      isDarkMode,
    ),
    if (items.isNotEmpty) ..._itemListSection(items, isDarkMode),
  ];

  List<Widget> _buildForecast(
    CashFlowForecast forecast,
    List<FixedCashFlowItem> items,
    bool isDarkMode,
  ) => [
    _SummaryHero(forecast: forecast, isDarkMode: isDarkMode),
    ..._section(
      title: 'เงินในบัญชี · ${formatAmount(forecast.liquidTotal)} บาท',
      emptyText: 'ยังไม่มีบัญชีเงินสดหรือบัญชีธนาคาร',
      divider: _iconRowDivider,
      rows: [
        for (final line in forecast.liquidLines)
          _LiquidRow(line: line, isDarkMode: isDarkMode),
      ],
      isDarkMode: isDarkMode,
    ),
    ..._section(
      title: 'เงินเข้าออกประจำ (ติ๊กเมื่อเกิดขึ้นแล้ว)',
      emptyText: 'ยังไม่มีรายการในช่วงนี้',
      divider: const AppCardDivider(),
      rows: [
        for (final line in forecast.itemLines)
          _OccurrenceRow(line: line, isDarkMode: isDarkMode),
      ],
      isDarkMode: isDarkMode,
    ),
    ..._section(
      title: 'บัตรเครดิต · -${formatAmount(forecast.cardTotal)} บาท',
      emptyText: 'ไม่มียอดบัตรที่ต้องชำระในช่วงนี้',
      divider: _iconRowDivider,
      rows: [
        for (final line in forecast.cardLines)
          _CardRow(line: line, isDarkMode: isDarkMode),
      ],
      isDarkMode: isDarkMode,
    ),
    _note(
      'นับเฉพาะยอดบัตรที่สรุปแล้ว ยอดที่ใช้หลังวันสรุปยอดจะไปอยู่ในรอบถัดไป',
      isDarkMode,
    ),
    ..._itemListSection(items, isDarkMode),
  ];

  static const _iconRowDivider = AppCardDivider(indent: 60, endIndent: 16);

  List<Widget> _itemListSection(
    List<FixedCashFlowItem> items,
    bool isDarkMode,
  ) => _section(
    title: 'รายการประจำทั้งหมด',
    emptyText: 'ยังไม่มีรายการประจำ',
    divider: const AppCardDivider(),
    rows: [
      for (final item in items) _ItemRow(item: item, isDarkMode: isDarkMode),
    ],
    isDarkMode: isDarkMode,
  );

  List<Widget> _section({
    required String title,
    required String emptyText,
    required Widget divider,
    required List<Widget> rows,
    required bool isDarkMode,
  }) => [
    AppSectionHeader(title),
    AppInsetCard(
      children: rows.isEmpty
          ? [_emptyRow(emptyText, isDarkMode)]
          : [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) divider,
                rows[i],
              ],
            ],
    ),
  ];

  Widget _note(String text, bool isDarkMode) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12,
        color: AppColors.textSecondaryFor(isDarkMode),
      ),
    ),
  );

  Widget _emptyRow(String text, bool isDarkMode) => Padding(
    padding: const EdgeInsets.all(16),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 13,
        color: AppColors.textSecondaryFor(isDarkMode),
      ),
    ),
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
          'ช่วง ${formatCashFlowDate(forecast.windowStart)} – '
          '${formatCashFlowDate(forecast.windowEnd)} · '
          'เงินเดือน ${formatCashFlowDate(forecast.cyclePayday)}',
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
        _metric('เงินในบัญชี', forecast.liquidTotal),
        _metric('เงินเข้าที่ยังไม่ติ๊ก', forecast.incomingTotal),
        _metric('เงินออกที่ยังไม่ติ๊ก', -forecast.outgoingTotal),
        _metric('ยอดบัตรที่ต้องชำระ', -forecast.cardTotal),
      ],
    );
  }

  Widget _metric(String label, double amount) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondaryFor(isDarkMode),
            ),
          ),
        ),
        Text(
          formatAmount(amount, showSign: true),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimaryFor(isDarkMode),
          ),
        ),
      ],
    ),
  );
}

class _LiquidRow extends StatelessWidget {
  final LiquidBalanceLine line;
  final bool isDarkMode;

  const _LiquidRow({required this.line, required this.isDarkMode});

  Future<void> _toggle(BuildContext context, bool isIncluded) async {
    try {
      await context.read<AccountProvider>().updateAccount(
        line.account.copyWith(isExcludedFromCashForecast: !isIncluded),
      );
    } catch (e) {
      debugPrint('CashFlowForecastScreen: toggle account error: $e');
      if (context.mounted) {
        _showError(context, 'บันทึกการตั้งค่าบัญชีไม่สำเร็จ');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.textPrimaryFor(isDarkMode);
    final textSecondary = AppColors.textSecondaryFor(isDarkMode);
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
                    color: line.isIncluded
                        ? textPrimary
                        : textSecondary.withValues(alpha: 0.6),
                  ),
                ),
                Text(
                  line.isIncluded
                      ? '${formatAmount(line.balance)} บาท'
                      : 'ไม่นับ · ${formatAmount(line.balance)} บาท',
                  style: TextStyle(fontSize: 12, color: textSecondary),
                ),
              ],
            ),
          ),
          AppSwitch(
            value: line.isIncluded,
            onChanged: (value) => _toggle(context, value),
          ),
        ],
      ),
    );
  }
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
                      if (line.item.isPayday)
                        AppStatusChip(
                          label: 'เงินเดือน',
                          color: AppColors.incomeFor(isDarkMode),
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
                    'ทุกวันที่ ${item.dayOfMonth}',
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
