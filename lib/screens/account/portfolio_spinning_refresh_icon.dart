import 'package:flutter/material.dart';

/// ไอคอน refresh ที่หมุนระหว่างอัปเดตราคา และค่อย ๆ หมุนช้าลงจนหยุดเมื่อโหลดเสร็จ
class PortfolioSpinningRefreshIcon extends StatefulWidget {
  final bool isSpinning;
  final Color color;

  const PortfolioSpinningRefreshIcon({
    super.key,
    required this.isSpinning,
    required this.color,
  });

  @override
  State<PortfolioSpinningRefreshIcon> createState() =>
      _PortfolioSpinningRefreshIconState();
}

class _PortfolioSpinningRefreshIconState
    extends State<PortfolioSpinningRefreshIcon>
    with SingleTickerProviderStateMixin {
  static const _turnMs = 900;

  // upperBound 2 เผื่อหมุนเพิ่มอีกรอบตอนชะลอ เมื่อเหลือระยะถึงจุดเริ่มน้อยเกินไป
  late final AnimationController _controller = AnimationController(
    vsync: this,
    upperBound: 2,
    duration: const Duration(milliseconds: _turnMs),
  );

  @override
  void initState() {
    super.initState();
    if (widget.isSpinning) _spin();
  }

  @override
  void didUpdateWidget(PortfolioSpinningRefreshIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSpinning == oldWidget.isSpinning) return;
    widget.isSpinning ? _spin() : _settle();
  }

  void _spin() {
    _controller.value = _controller.value % 1;
    _controller.repeat(min: 0, max: 1);
  }

  /// ชะลอจนกลับมาที่มุมเริ่มต้น โดยความเร็วตอนเริ่มชะลอใกล้เคียงความเร็วหมุนปกติ
  void _settle() {
    final value = _controller.value;
    final target = value < 0.6 ? 1.0 : 2.0;
    // easeOut มีความชันตั้งต้นราว 1.7 เท่าของ linear จึงยืดเวลาให้ความเร็วต่อเนื่อง
    final ms = ((target - value) * _turnMs * 1.7).round();
    _controller
        .animateTo(
          target,
          duration: Duration(milliseconds: ms),
          curve: Curves.easeOut,
        )
        .whenCompleteOrCancel(() {
          if (mounted && !widget.isSpinning) _controller.value = 0;
        });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: Icon(Icons.refresh_rounded, size: 20, color: widget.color),
    );
  }
}
