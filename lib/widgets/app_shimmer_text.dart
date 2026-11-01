import 'package:flutter/material.dart';

/// ข้อความที่มีแถบจางวิ่งผ่านจากซ้ายไปขวา ใช้บอกว่ากำลังโหลดอยู่
/// (จังหวะเดียวกับข้อความใน AppLoadingView)
class AppShimmerText extends StatefulWidget {
  final String text;
  final TextStyle style;

  const AppShimmerText(this.text, {super.key, required this.style});

  @override
  State<AppShimmerText> createState() => _AppShimmerTextState();
}

class _AppShimmerTextState extends State<AppShimmerText>
    with SingleTickerProviderStateMixin {
  static const _sweepDuration = Duration(milliseconds: 1600);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _sweepDuration,
  );

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

  @override
  Widget build(BuildContext context) {
    final text = Text(widget.text, style: widget.style);
    if (!_controller.isAnimating) return text;

    final color = widget.style.color;
    if (color == null) return text;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (bounds) => LinearGradient(
          colors: [color, color, color.withValues(alpha: 0.25), color, color],
          stops: const [0, 0.4, 0.5, 0.6, 1],
          transform: _SlideGradientTransform(-1 + 2 * _controller.value),
        ).createShader(bounds),
        child: child,
      ),
      child: text,
    );
  }
}

class _SlideGradientTransform extends GradientTransform {
  final double offset;

  const _SlideGradientTransform(this.offset);

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * offset, 0, 0);
}
