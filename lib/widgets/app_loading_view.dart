import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../theme/app_colors.dart';

/// สถานะรอข้อมูลครั้งแรก: เหรียญหยอดลงกระปุกออมสิน (โลโก้แอป) พร้อมข้อความ
class AppLoadingView extends StatefulWidget {
  final String label;

  const AppLoadingView({super.key, this.label = 'กำลังโหลดข้อมูล'});

  @override
  State<AppLoadingView> createState() => _AppLoadingViewState();
}

class _AppLoadingViewState extends State<AppLoadingView>
    with SingleTickerProviderStateMixin {
  static const _iconSize = 72.0;
  static const _coinSize = 16.0;
  static const _dropHeight = 24.0;

  // ตำแหน่งช่องหยอดของ Icons.savings_rounded บน grid 24×24
  static const _slotCenterX = _iconSize * 10.5 / 24;
  static const _slotCenterY = _dropHeight + _iconSize * 8 / 24;
  // ขอบบนลำตัวหมู: ซ่อนเหรียญส่วนที่เลยเส้นนี้ ไม่ให้โผล่ผ่านช่องโปร่งของ icon
  static const _bodyTopY = _dropHeight + _iconSize * 5 / 24;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  // เหรียญตกถึงช่องหยอดใน 40% แรกของรอบ แล้วจางหายภายใน 48%
  late final Animation<double> _coinDrop = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.4, curve: Curves.easeIn),
  );
  late final Animation<double> _coinOpacity = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0, end: 1), weight: 15),
    TweenSequenceItem(tween: ConstantTween(1), weight: 25),
    TweenSequenceItem(tween: Tween(begin: 1, end: 0), weight: 8),
    TweenSequenceItem(tween: ConstantTween(0), weight: 52),
  ]).animate(_controller);

  // กระปุกยุบรับเหรียญแล้วเด้งกลับ (1 = ยุบสุด, ค่าลบ = ยืดขึ้น)
  late final Animation<double> _squash = TweenSequence<double>([
    TweenSequenceItem(tween: ConstantTween(0), weight: 40),
    TweenSequenceItem(tween: Tween(begin: 0, end: 1), weight: 8),
    TweenSequenceItem(tween: Tween(begin: 1, end: -0.5), weight: 10),
    TweenSequenceItem(tween: Tween(begin: -0.5, end: 0), weight: 12),
    TweenSequenceItem(tween: ConstantTween(0), weight: 30),
  ]).animate(_controller);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// จุดท้ายข้อความสว่างไล่กันทีละจุด
  double _dotOpacity(int index) {
    final phase = (_controller.value - index * 0.15) % 1.0;
    final peak = phase < 0.4 ? phase / 0.4 : 1 - (phase - 0.4) / 0.6;
    return 0.2 + 0.8 * peak;
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.select<SettingsProvider, bool>(
      (s) => s.isDarkMode,
    );
    final color = AppColors.textSecondaryFor(isDarkMode);
    final coinColor = AppColors.saveButtonFor(isDarkMode);
    final textStyle = TextStyle(
      color: color,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    );

    return Semantics(
      label: widget.label,
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.only(top: 120),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final drop = _coinDrop.value;
              final squash = _squash.value;
              return Column(
                children: [
                  SizedBox(
                    width: _iconSize,
                    height: _iconSize + _dropHeight,
                    child: Stack(
                      children: [
                        // วาดเหรียญก่อนกระปุก และ clip ที่ขอบบนลำตัว
                        // ให้ดูเหมือนหล่นหายเข้าไปในกระปุก
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 0,
                          height: _bodyTopY,
                          child: Stack(
                            clipBehavior: Clip.hardEdge,
                            children: [
                              Positioned(
                                left: _slotCenterX - _coinSize / 2,
                                top: drop * (_slotCenterY - _coinSize / 2),
                                child: Opacity(
                                  opacity: _coinOpacity.value,
                                  child: Transform.scale(
                                    scaleX: 1 - 0.65 * drop,
                                    child: Container(
                                      width: _coinSize,
                                      height: _coinSize,
                                      decoration: BoxDecoration(
                                        color: coinColor,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Color.lerp(
                                            coinColor,
                                            Colors.black,
                                            0.25,
                                          )!,
                                          width: 2.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Transform(
                            alignment: Alignment.bottomCenter,
                            transform: Matrix4.diagonal3Values(
                              1 + 0.06 * squash,
                              1 - 0.06 * squash,
                              1,
                            ),
                            child: Icon(
                              Icons.savings_rounded,
                              size: _iconSize,
                              color: color,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(widget.label, style: textStyle),
                      for (var i = 0; i < 3; i++)
                        Opacity(
                          opacity: _dotOpacity(i),
                          child: Text('.', style: textStyle),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
