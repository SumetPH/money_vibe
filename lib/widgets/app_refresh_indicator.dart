import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../theme/app_colors.dart';

/// Pull-to-refresh ของรายการหลัก: spinner แบบ adaptive สี accent ของธีม
/// ถ้า [onRefresh] ล้มเหลวจะแจ้งด้วย SnackBar และคงข้อมูลเดิมไว้
/// [child] ต้องเป็น scrollable ที่ใช้ [AlwaysScrollableScrollPhysics]
class AppRefreshIndicator extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final Widget child;

  const AppRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
  });

  Future<void> _handleRefresh(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await onRefresh();
    } catch (e) {
      debugPrint('[AppRefreshIndicator] Refresh failed: $e');
      messenger?.showSnackBar(
        const SnackBar(content: Text('รีเฟรชข้อมูลไม่สำเร็จ ลองใหม่อีกครั้ง')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isDarkMode = settings.isDarkMode;

    return RefreshIndicator.adaptive(
      onRefresh: () => _handleRefresh(context),
      color: AppColors.accentFor(isDarkMode, settings.themeColor),
      backgroundColor: AppColors.surfaceFor(isDarkMode),
      child: child,
    );
  }
}
