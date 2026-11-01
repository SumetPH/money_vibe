import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../providers/sync_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../utils/user_error_message.dart';
import 'app_bar_action_button.dart';
import 'app_cupertino_refresh.dart';
import 'app_loading_view.dart';

/// สั่ง Manual Refresh ของ [modules] และแสดง SnackBar เมื่อโหลดไม่สำเร็จ
/// (ข้อมูลเดิมยังแสดงอยู่ตามเดิม)
Future<void> refreshDataModules(
  BuildContext context,
  Set<SyncModule> modules,
) async {
  final syncProvider = context.read<SyncProvider>();
  final messenger = ScaffoldMessenger.of(context);
  try {
    await syncProvider.refresh(modules);
  } catch (error) {
    messenger.showSnackBar(
      SnackBar(content: Text(userErrorMessage(error, action: 'โหลดข้อมูล'))),
    );
  }
}

/// แสดงเนื้อหาของหน้าตามความพร้อมของ [modules]: [AppLoadingView] ระหว่างรอ Initial Load,
/// error state เมื่อโหลดไม่สำเร็จ และ [builder] เมื่อทุก module พร้อม
///
/// [builder] ต้องคืน scroll view ที่ใช้ `AlwaysScrollableScrollPhysics`
/// เพื่อให้ดึงลงได้แม้เนื้อหาสั้น
class AppDataStateView extends StatelessWidget {
  final Set<SyncModule> modules;
  final WidgetBuilder builder;

  /// false สำหรับหน้าที่แสดงแค่ loading/error โดยไม่มี pull-to-refresh
  final bool enablePullToRefresh;

  const AppDataStateView({
    super.key,
    required this.modules,
    required this.builder,
    this.enablePullToRefresh = true,
  });

  @override
  Widget build(BuildContext context) {
    final readiness = context.select<SyncProvider, DataReadiness>(
      (syncProvider) => syncProvider.readinessOf(modules),
    );

    final content = switch (readiness) {
      DataReadiness.ready => builder(context),
      DataReadiness.failed => _StateScrollView(
        child: AppDataErrorView(
          onRetry: () => refreshDataModules(context, modules),
        ),
      ),
      _ => _StateScrollView(
        isCentered: true,
        child: AppLoadingView(
          subtitles: [for (final m in modules) _syncModuleLabels[m]!],
        ),
      ),
    };

    if (!enablePullToRefresh) return content;
    return AppCupertinoRefresh(
      onRefresh: () => refreshDataModules(context, modules),
      child: content,
    );
  }
}

const _syncModuleLabels = {
  SyncModule.accounts: 'บัญชีและยอดคงเหลือ',
  SyncModule.portfolio: 'พอร์ตการลงทุน',
  SyncModule.categories: 'หมวดหมู่',
  SyncModule.transactions: 'รายการล่าสุด',
  SyncModule.budgets: 'งบประมาณเดือนนี้',
  SyncModule.recurring: 'รายการประจำ',
  SyncModule.cashFlow: 'กระแสเงินสด',
};

class _StateScrollView extends StatelessWidget {
  final Widget child;

  /// true = วาง [child] กลางจอในแนวตั้ง
  final bool isCentered;

  const _StateScrollView({required this.child, this.isCentered = false});

  @override
  Widget build(BuildContext context) {
    if (isCentered) {
      // SliverFillRemaining ให้ child เต็มความสูงที่เหลือ แต่ยังดึงลงเพื่อ refresh ได้
      return CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: _ScreenCenteredBox(child: child),
          ),
        ],
      );
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(
        bottom: 24 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [child],
    );
  }
}

/// จัด [child] ให้อยู่กลางจอทั้งจอ แทนกลางพื้นที่ของตัวเอง เพื่อชดเชย AppBar/header
/// ด้านบนและ bottom navigation ที่สูงไม่เท่ากัน
class _ScreenCenteredBox extends StatefulWidget {
  final Widget child;

  const _ScreenCenteredBox({required this.child});

  @override
  State<_ScreenCenteredBox> createState() => _ScreenCenteredBoxState();
}

class _ScreenCenteredBoxState extends State<_ScreenCenteredBox> {
  // เลื่อนได้ไม่เกิน 1/4 ของพื้นที่ เพื่อไม่ให้ child ล้นออกนอกพื้นที่
  static const _maxShiftFraction = 0.25;

  double _shiftY = 0;

  void _measure() {
    if (!mounted) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final areaTop = box.localToGlobal(Offset.zero).dy;
    final areaHeight = box.size.height;
    final screenCenter = MediaQuery.sizeOf(context).height / 2;
    final maxShift = areaHeight * _maxShiftFraction;
    final shift = (screenCenter - (areaTop + areaHeight / 2)).clamp(
      -maxShift,
      maxShift,
    );
    if ((shift - _shiftY).abs() > 0.5) setState(() => _shiftY = shift);
  }

  @override
  Widget build(BuildContext context) {
    // วัดตำแหน่งหลัง layout ทุกครั้ง (ขนาดจอ/header เปลี่ยนได้)
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    return Center(
      child: Transform.translate(
        offset: Offset(0, _shiftY),
        child: widget.child,
      ),
    );
  }
}

/// ปุ่ม refresh บน AppBar สำหรับจอกว้างที่ใช้เมาส์ดึงหน้าจอไม่ได้
class AppRefreshActionButton extends StatefulWidget {
  final Set<SyncModule> modules;

  const AppRefreshActionButton({super.key, required this.modules});

  @override
  State<AppRefreshActionButton> createState() => _AppRefreshActionButtonState();
}

class _AppRefreshActionButtonState extends State<AppRefreshActionButton> {
  bool _isRefreshing = false;

  Future<void> _refresh() async {
    setState(() => _isRefreshing = true);
    await refreshDataModules(context, widget.modules);
    if (mounted) setState(() => _isRefreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    return AppBarActionButton(
      icon: const Icon(Icons.refresh_rounded),
      tooltip: 'โหลดข้อมูลใหม่',
      isLoading: _isRefreshing,
      onPressed: _refresh,
    );
  }
}

/// Error state เมื่อข้อมูลของหน้าโหลดไม่สำเร็จตั้งแต่ครั้งแรก
class AppDataErrorView extends StatelessWidget {
  final VoidCallback onRetry;

  const AppDataErrorView({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.select<SettingsProvider, bool>(
      (s) => s.isDarkMode,
    );
    final textSecondary = AppColors.textSecondaryFor(isDarkMode);

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 80, 32, 0),
      child: Column(
        children: [
          Icon(Icons.cloud_off_rounded, size: 48, color: textSecondary),
          const SizedBox(height: 16),
          Text(
            'โหลดข้อมูลไม่สำเร็จ',
            style: TextStyle(
              color: AppColors.textPrimaryFor(isDarkMode),
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'ตรวจสอบการเชื่อมต่ออินเทอร์เน็ต แล้วลองใหม่อีกครั้ง',
            textAlign: TextAlign.center,
            style: TextStyle(color: textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 20),
          Material(
            color: AppColors.raisedFillFor(isDarkMode),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.full),
              side: BorderSide(color: AppColors.borderFor(isDarkMode)),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onRetry,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.refresh_rounded,
                      size: 18,
                      color: AppColors.textPrimaryFor(isDarkMode),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'ลองใหม่',
                      style: TextStyle(
                        color: AppColors.textPrimaryFor(isDarkMode),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
