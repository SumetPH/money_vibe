import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

const hideOnScrollDuration = Duration(milliseconds: 220);

/// สถานะแสดง/ซ่อน app bar และ bottom nav ของ Main Tab ตามทิศการเลื่อน
class BarsVisibility extends ValueNotifier<bool> {
  BarsVisibility() : super(true);

  /// เลื่อนลงดูเนื้อหา (นิ้วปัดขึ้น) = ซ่อน, เลื่อนกลับขึ้น = แสดง
  bool handleScroll(UserScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    switch (notification.direction) {
      case ScrollDirection.reverse:
        value = false;
      case ScrollDirection.forward:
        value = true;
      case ScrollDirection.idle:
        break;
    }
    return false;
  }
}

/// ห่อหน้าที่มี [HideOnScrollAppBar] ให้ app bar ซ่อน/แสดงตามการเลื่อน
/// (Main Tab จัดการเองเพราะต้องคุม bottom nav ด้วย)
class HideOnScroll extends StatefulWidget {
  final Widget child;

  const HideOnScroll({super.key, required this.child});

  @override
  State<HideOnScroll> createState() => _HideOnScrollState();
}

class _HideOnScrollState extends State<HideOnScroll> {
  final _barsVisibility = BarsVisibility();

  @override
  void dispose() {
    _barsVisibility.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _barsVisibility,
      child: NotificationListener<UserScrollNotification>(
        onNotification: _barsVisibility.handleScroll,
        child: widget.child,
      ),
    );
  }
}

/// ห่อ AppBar ให้ยุบ toolbar ขึ้นไปใต้ status bar เมื่อ [BarsVisibility] เป็น false
/// หน้าที่ไม่ได้อยู่ใต้ Main Tab (ไม่มี provider) จะแสดงตลอด
class HideOnScrollAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final PreferredSizeWidget child;

  const HideOnScrollAppBar({super.key, required this.child});

  @override
  Size get preferredSize => child.preferredSize;

  @override
  Widget build(BuildContext context) {
    final isVisible = context.watch<BarsVisibility?>()?.value ?? true;
    final topPadding = MediaQuery.paddingOf(context).top;
    final fullHeight = topPadding + preferredSize.height;

    return TweenAnimationBuilder<double>(
      tween: Tween(end: isVisible ? 1 : 0),
      duration: hideOnScrollDuration,
      curve: Curves.easeOut,
      child: child,
      builder: (context, factor, child) => ClipRect(
        child: SizedBox(
          height: topPadding + preferredSize.height * factor,
          child: OverflowBox(
            alignment: Alignment.bottomCenter,
            minHeight: fullHeight,
            maxHeight: fullHeight,
            // จางไปพร้อมกัน ไม่ให้ส่วนล่างของ toolbar ค้างอยู่ใต้ status bar
            child: Opacity(opacity: factor, child: child),
          ),
        ),
      ),
    );
  }
}
