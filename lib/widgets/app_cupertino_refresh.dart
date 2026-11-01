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
  static const _collapseDuration = Duration(milliseconds: 250);

  /// สัดส่วนช่องที่ค้างไว้ (1 = เต็ม [_holdExtent]) ยุบลงเป็น 0 เมื่อโหลดเสร็จ
  late final AnimationController _hold = AnimationController(
    vsync: this,
    duration: _collapseDuration,
  )..addListener(() => setState(() {}));

  /// ระยะที่ scroll view ถูกดึงเกินขอบบน (ค่าบวก)
  double _overscroll = 0;
  bool _isArmed = false;
  bool _isRefreshing = false;

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  // ช่องที่ต้องเติมเพิ่มจาก overscroll เพื่อให้เนื้อหาไม่ขึ้นสูงกว่าช่อง spinner
  // ขณะ bouncing ดีดกลับ ทำให้เนื้อหาเลื่อนจากระยะดึงลงมาค้างที่ช่องอย่างต่อเนื่อง
  double get _gap =>
      (_hold.value * _holdExtent - _overscroll).clamp(0.0, _holdExtent);

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
      _startRefresh();
    }
    return false;
  }

  void _updateArmed(bool isArmed) {
    if (isArmed == _isArmed) return;
    if (isArmed) HapticFeedback.lightImpact();
    setState(() => _isArmed = isArmed);
  }

  Future<void> _startRefresh() async {
    setState(() {
      _isArmed = false;
      _isRefreshing = true;
    });
    _hold.value = 1;
    try {
      await widget.onRefresh();
    } finally {
      if (mounted) await _collapse();
    }
  }

  Future<void> _collapse() async {
    if (MediaQuery.disableAnimationsOf(context)) {
      _hold.value = 0;
    } else {
      await _hold.animateTo(0, curve: Curves.easeOutCubic);
    }
    if (mounted) setState(() => _isRefreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.select<SettingsProvider, bool>(
      (s) => s.isDarkMode,
    );
    final gap = _gap;
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
