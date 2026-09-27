import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../main.dart';
import '../../providers/settings_provider.dart';
import '../../services/cash_flow_forecast_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_inset_card.dart';
import '../../widgets/app_status_chip.dart';
import 'cash_flow_forecast_scope.dart';
import 'cash_flow_forecast_screen.dart';

/// การ์ดสรุป Projected leftover บนแท็บแผน
class CashFlowForecastCard extends StatelessWidget {
  const CashFlowForecastCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.select<SettingsProvider, bool>(
      (s) => s.isDarkMode,
    );
    final forecast = watchCashFlowForecast(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AppInsetCard(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CashFlowForecastScreen(),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: forecast == null
                    ? _EmptyContent(isDarkMode: isDarkMode)
                    : _ForecastContent(
                        forecast: forecast,
                        isDarkMode: isDarkMode,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ForecastContent extends StatelessWidget {
  final CashFlowForecast forecast;
  final bool isDarkMode;

  const _ForecastContent({required this.forecast, required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    final textSecondary = AppColors.textSecondaryFor(isDarkMode);
    final leftover = forecast.projectedLeftover;
    final warningCount = forecast.warningCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'คาดว่าจะเหลือถึง ${formatCashFlowDate(forecast.windowEnd)}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: textSecondary,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: textSecondary.withValues(alpha: 0.5),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${formatAmount(leftover, showSign: true)} บาท',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppColors.amountColor(leftover, isDarkMode: isDarkMode),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          leftover < 0
              ? 'เงินไม่พอชำระภาระก่อนเงินเดือนงวดถัดไป'
              : 'พอชำระภาระจนถึงก่อนเงินเดือนงวดถัดไป',
          style: TextStyle(fontSize: 12, color: textSecondary),
        ),
        if (warningCount > 0) ...[
          const SizedBox(height: 10),
          AppStatusChip(
            label: '$warningCount รายการต้องตรวจสอบ',
            color: AppColors.saveButtonFor(isDarkMode),
          ),
        ],
      ],
    );
  }
}

class _EmptyContent extends StatelessWidget {
  final bool isDarkMode;

  const _EmptyContent({required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    final textSecondary = AppColors.textSecondaryFor(isDarkMode);
    return Row(
      children: [
        Icon(Icons.payments_outlined, color: textSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'คาดการณ์เงินคงเหลือ',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimaryFor(isDarkMode),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'ตั้งรายการเงินเดือนเพื่อดูการคาดการณ์',
                style: TextStyle(fontSize: 12, color: textSecondary),
              ),
            ],
          ),
        ),
        Icon(
          Icons.chevron_right,
          size: 18,
          color: textSecondary.withValues(alpha: 0.5),
        ),
      ],
    );
  }
}
