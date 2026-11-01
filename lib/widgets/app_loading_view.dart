import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../theme/app_colors.dart';

/// สถานะรอข้อมูลครั้งแรก: วงแหวนหมุนรอบกระปุกออมสิน (โลโก้แอป) พร้อมข้อความมีแสงวิ่ง
class AppLoadingView extends StatefulWidget {
  final String label;

  /// บรรทัดรองใต้ข้อความหลัก สลับทีละข้อความตามจังหวะ animation (ว่าง = ไม่แสดง)
  final List<String> subtitles;

  const AppLoadingView({
    super.key,
    this.label = 'กำลังโหลดข้อมูล',
    this.subtitles = const [],
  });

  @override
  State<AppLoadingView> createState() => _AppLoadingViewState();
}

class _AppLoadingViewState extends State<AppLoadingView>
    with SingleTickerProviderStateMixin {
  static const _ringSize = 112.0;
  static const _ringStroke = 4.0;
  static const _iconSize = 54.0;

  // หนึ่งรอบ controller = วงแหวนหมุน 3 รอบ, เส้นยืด/หด/กระปุกหายใจ/แสงวิ่ง 2 รอบ
  static const _ringTurns = 3;
  static const _pulseCycles = 2;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );

  // สลับบรรทัดรองทุกครึ่งรอบ controller ให้ตรงจังหวะแสงวิ่ง
  static const _subtitleInterval = Duration(milliseconds: 1600);
  static const _subtitleFade = Duration(milliseconds: 250);
  Timer? _subtitleTimer;
  int _subtitleIndex = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _subtitleTimer?.cancel();
      _subtitleTimer = null;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
      _subtitleTimer ??= Timer.periodic(
        _subtitleInterval,
        (_) => setState(() => _subtitleIndex++),
      );
    }
  }

  @override
  void dispose() {
    _subtitleTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// 0 → 1 → 0 แบบนุ่มนวล วน [_pulseCycles] ครั้งต่อรอบ controller
  double get _pulse {
    final phase = (_controller.value * _pulseCycles) % 1.0;
    return (1 - math.cos(phase * 2 * math.pi)) / 2;
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.select<SettingsProvider, bool>(
      (s) => s.isDarkMode,
    );
    final color = AppColors.textSecondaryFor(isDarkMode);
    final trackColor = AppColors.insetFillFor(isDarkMode);
    final textStyle = TextStyle(
      color: color,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    );

    return Semantics(
      label: widget.label,
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final pulse = _pulse;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox.square(
                  dimension: _ringSize,
                  child: CustomPaint(
                    painter: _LoadingRingPainter(
                      rotation: _controller.value * _ringTurns,
                      sweepFraction: 0.06 + 0.4 * pulse,
                      color: color,
                      trackColor: trackColor,
                      strokeWidth: _ringStroke,
                    ),
                    child: Center(
                      child: Transform.scale(
                        scale: 0.94 + 0.1 * pulse,
                        child: Icon(
                          Icons.savings_rounded,
                          size: _iconSize,
                          color: color,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildShimmerLabel(textStyle, color),
                if (widget.subtitles.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  _buildSubtitle(color),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSubtitle(Color color) {
    final subtitles = widget.subtitles;
    final text = subtitles[_subtitleIndex % subtitles.length];
    return AnimatedSwitcher(
      duration: _subtitleFade,
      child: Text(
        text,
        key: ValueKey(text),
        textAlign: TextAlign.center,
        style: TextStyle(color: color.withValues(alpha: 0.65), fontSize: 12),
      ),
    );
  }

  /// แถบจางวิ่งผ่านข้อความจากซ้ายไปขวา
  Widget _buildShimmerLabel(TextStyle textStyle, Color color) {
    final phase = (_controller.value * _pulseCycles) % 1.0;
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => LinearGradient(
        colors: [color, color, color.withValues(alpha: 0.25), color, color],
        stops: const [0, 0.4, 0.5, 0.6, 1],
        transform: _SlideGradientTransform(-1 + 2 * phase),
      ).createShader(bounds),
      child: Text(widget.label, style: textStyle),
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

class _LoadingRingPainter extends CustomPainter {
  final double rotation;
  final double sweepFraction;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  const _LoadingRingPainter({
    required this.rotation,
    required this.sweepFraction,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(strokeWidth / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawOval(arcRect, paint..color = trackColor);
    canvas.drawArc(
      arcRect,
      rotation * 2 * math.pi - math.pi / 2,
      sweepFraction * 2 * math.pi,
      false,
      paint..color = color,
    );
  }

  @override
  bool shouldRepaint(_LoadingRingPainter oldDelegate) =>
      rotation != oldDelegate.rotation ||
      sweepFraction != oldDelegate.sweepFraction ||
      color != oldDelegate.color ||
      trackColor != oldDelegate.trackColor ||
      strokeWidth != oldDelegate.strokeWidth;
}
