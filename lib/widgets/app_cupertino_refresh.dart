import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../theme/app_colors.dart';

/// Manual Refresh แบบ iOS: ดึงลงแล้วเนื้อหาถูกดันลง เผยให้เห็น spinner ใต้ header
/// และค้างช่องนั้นไว้จนโหลดเสร็จ
///
/// ใช้ได้กับ scroll view ทุกชนิดใน [child] (ไม่ต้องเป็น sliver) โดยบังคับ
/// bouncing physics ให้ดึงเกินขอบบนได้ทุก platform
class AppCupertinoRefresh extends StatefulWidget {
  final Future<void> Function() onRefresh;
  final Widget child;

  const AppCupertinoRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
  });

  @override
  State<AppCupertinoRefresh> createState() => _AppCupertinoRefreshState();
}

class _AppCupertinoRefreshState extends State<AppCupertinoRefresh>
    with SingleTickerProviderStateMixin {
  // ระยะดึงที่ต้องถึงก่อนปล่อยมือจึงจะ refresh
  static const _triggerDistance = 80.0;
  // ความสูงของช่อง spinner ที่ค้างไว้ระหว่างโหลด
  static const _holdExtent = 60.0;
  static const _indicatorRadius = 12.0;
  static const _settleDuration = Duration(milliseconds: 250);

  /// ระยะที่เลื่อนเนื้อหาลงเพื่อเปิดช่อง spinner ระหว่างโหลด (px)
  late final AnimationController _gap = AnimationController.unbounded(
    vsync: this,
  )..addListener(() => setState(() {}));

  /// ระยะที่ scroll view ถูกดึงเกินขอบบน (ค่าบวก)
  double _overscroll = 0;
  bool _isArmed = false;
  bool _isRefreshing = false;

  @override
  void dispose() {
    _gap.dispose();
    super.dispose();
  }

  bool _handleScroll(ScrollNotification notification) {
    if (notification.depth != 0 || notification.metrics.axis != Axis.vertical) {
      return false;
    }

    final metrics = notification.metrics;
    final overscroll = (metrics.minScrollExtent - metrics.pixels).clamp(
      0.0,
      double.infinity,
    );
    if (overscroll != _overscroll) setState(() => _overscroll = overscroll);

    if (_isRefreshing) return false;
    final isDragging =
        notification is ScrollUpdateNotification &&
        notification.dragDetails != null;
    if (isDragging) {
      _updateArmed(overscroll >= _triggerDistance);
    } else if (_isArmed &&
        (notification is ScrollUpdateNotification ||
            notification is ScrollEndNotification)) {
      _startRefresh(notification.context, overscroll);
    }
    return false;
  }

  void _updateArmed(bool isArmed) {
    if (isArmed == _isArmed) return;
    if (isArmed) HapticFeedback.lightImpact();
    setState(() => _isArmed = isArmed);
  }

  Future<void> _startRefresh(
    BuildContext? scrollContext,
    double overscroll,
  ) async {
    setState(() {
      _isArmed = false;
      _isRefreshing = true;
    });
    // ย้ายระยะ overscroll มาเป็นช่องของเราเอง แล้วหยุดการดีดกลับของ scroll view
    // ถ้าปล่อยให้ดีดกลับต่อ เนื้อหาที่เปลี่ยนขนาดระหว่างโหลดจะทำให้ตำแหน่ง scroll
    // กระโดดและเลื่อนต่อด้วยแรงดีด จนเนื้อหาขึ้นไปทับ spinner
    _gap.value = overscroll;
    final position = scrollContext == null
        ? null
        : Scrollable.maybeOf(scrollContext)?.position;
    position?.jumpTo(position.minScrollExtent);
    _animateGap(_holdExtent);
    try {
      await widget.onRefresh();
    } finally {
      if (mounted) {
        await _animateGap(0);
        if (mounted) setState(() => _isRefreshing = false);
      }
    }
  }

  Future<void> _animateGap(double target) async {
    if (MediaQuery.disableAnimationsOf(context)) {
      _gap.value = target;
      return;
    }
    await _gap.animateTo(
      target,
      duration: _settleDuration,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.select<SettingsProvider, bool>(
      (s) => s.isDarkMode,
    );
    final gap = _gap.value;
    final revealedExtent = _overscroll + gap;
    final behavior = ScrollConfiguration.of(context).copyWith(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
    );

    return Stack(
      children: [
        if (revealedExtent > 0)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: revealedExtent,
            child: Center(
              child: _RefreshSpinner(
                isRefreshing: _isRefreshing,
                progress: (_overscroll / _triggerDistance).clamp(0.0, 1.0),
                color: AppColors.textSecondaryFor(isDarkMode),
              ),
            ),
          ),
        NotificationListener<ScrollNotification>(
          onNotification: _handleScroll,
          child: Transform.translate(
            offset: Offset(0, gap),
            child: ScrollConfiguration(behavior: behavior, child: widget.child),
          ),
        ),
      ],
    );
  }
}

class _RefreshSpinner extends StatelessWidget {
  final bool isRefreshing;

  /// สัดส่วนระยะดึงเทียบกับระยะ trigger (0–1) ใช้เผยขีดของ spinner ทีละขีด
  final double progress;
  final Color color;

  const _RefreshSpinner({
    required this.isRefreshing,
    required this.progress,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (isRefreshing) {
      return CupertinoActivityIndicator(
        radius: _AppCupertinoRefreshState._indicatorRadius,
        color: color,
      );
    }
    return Opacity(
      opacity: progress,
      child: CupertinoActivityIndicator.partiallyRevealed(
        radius: _AppCupertinoRefreshState._indicatorRadius,
        progress: progress,
        color: color,
      ),
    );
  }
}
