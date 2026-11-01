import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../providers/sync_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../utils/user_error_message.dart';
import 'app_bar_action_button.dart';
import 'app_inset_card.dart';

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

/// แสดงเนื้อหาของหน้าตามความพร้อมของ [modules]: skeleton ระหว่างรอ Initial Load,
/// error state เมื่อโหลดไม่สำเร็จ และ [builder] เมื่อทุก module พร้อม
///
/// [builder] ต้องคืน scroll view ที่ใช้ `AlwaysScrollableScrollPhysics`
/// เพื่อให้ดึงลงได้แม้เนื้อหาสั้น
class AppDataStateView extends StatelessWidget {
  final Set<SyncModule> modules;
  final WidgetBuilder builder;

  /// false สำหรับหน้าที่แสดงแค่ skeleton/error โดยไม่มี pull-to-refresh
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
      _ => const _StateScrollView(child: AppSkeletonList()),
    };

    if (!enablePullToRefresh) return content;
    return RefreshIndicator(
      onRefresh: () => refreshDataModules(context, modules),
      child: content,
    );
  }
}

class _StateScrollView extends StatelessWidget {
  final Widget child;

  const _StateScrollView({required this.child});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(
        bottom: 24 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [child],
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

/// โครงร่างแบบนิ่งแทนข้อมูลที่ยังโหลดไม่เสร็จ: การ์ดสรุปหนึ่งใบตามด้วยการ์ดรายการ
class AppSkeletonList extends StatelessWidget {
  final int rowCount;

  const AppSkeletonList({super.key, this.rowCount = 5});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppInsetCard(
          margin: AppInsetCard.stackedMargin,
          padding: EdgeInsets.all(16),
          children: [
            AppSkeletonBar(width: 96, height: 12),
            SizedBox(height: 12),
            AppSkeletonBar(width: 180, height: 28),
          ],
        ),
        AppInsetCard(
          children: [
            for (var i = 0; i < rowCount; i++) ...[
              if (i > 0) const AppCardDivider(),
              const _SkeletonRow(),
            ],
          ],
        ),
      ],
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          AppSkeletonBar(width: 36, height: 36, radius: AppRadii.full),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSkeletonBar(width: 140, height: 14),
                SizedBox(height: 8),
                AppSkeletonBar(width: 80, height: 10),
              ],
            ),
          ),
          AppSkeletonBar(width: 72, height: 14),
        ],
      ),
    );
  }
}

/// แท่ง placeholder สีพื้นยุบ (`insetFillFor`) สำหรับประกอบ skeleton
class AppSkeletonBar extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const AppSkeletonBar({
    super.key,
    required this.width,
    required this.height,
    this.radius = AppRadii.small,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.select<SettingsProvider, bool>(
      (s) => s.isDarkMode,
    );
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.insetFillFor(isDarkMode),
        borderRadius: BorderRadius.circular(radius),
      ),
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
