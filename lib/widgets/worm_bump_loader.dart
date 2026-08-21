import 'dart:math' as math;
import 'package:flutter/material.dart';

/// WormBumpLoader - Converted directly from Uiverse.io by Bethel-nz
/// CSS specs:
/// - Container: 3s duration, bump9 keyframe translations (jolts/bumps)
/// - Worm: 3s duration, cubic-bezier(0.42, 0.17, 0.75, 0.83), stroke-dashoffset: 10 -> 295 -> 1165
class WormBumpLoader extends StatefulWidget {
  const WormBumpLoader({
    super.key,
    this.size = 72.0,
    this.strokeWidth,
    this.color,
    this.trackColor,
  });

  final double size;
  final double? strokeWidth;
  final Color? color;
  final Color? trackColor;

  @override
  State<WormBumpLoader> createState() => _WormBumpLoaderState();
}

class _WormBumpLoaderState extends State<WormBumpLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // Exact cubic-bezier from CSS: cubic-bezier(0.42, 0.17, 0.75, 0.83)
  static const Curve _wormCurve = Cubic(0.42, 0.17, 0.75, 0.83);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Exact piecewise interpolation of @keyframes bump9
  Offset _getBumpOffset(double p) {
    // Keyframe list: (percentage, dx%, dy%)
    // 0%..42%: (0, 0)
    // 44%: (1.33%, 6.75%)
    // 46%: (0, 0)
    // 51%: (0, 0)
    // 53%: (-16.67%, -0.54%)
    // 55%: (0, 0)
    // 59%: (0, 0)
    // 61%: (3.66%, -2.46%)
    // 63%: (0, 0)
    // 67%: (0, 0)
    // 69%: (-0.59%, 15.27%)
    // 71%: (0, 0)
    // 74%: (0, 0)
    // 76%: (-1.92%, -4.68%)
    // 78%: (0, 0)
    // 81%: (0, 0)
    // 83%: (9.38%, 0.96%)
    // 85%: (0, 0)
    // 88%: (0, 0)
    // 90%: (-4.55%, 1.98%)
    // 92%..100%: (0, 0)

    double dx = 0;
    double dy = 0;

    if (p >= 0.42 && p < 0.44) {
      final t = (p - 0.42) / 0.02;
      dx = 0.0133 * t;
      dy = 0.0675 * t;
    } else if (p >= 0.44 && p < 0.46) {
      final t = (p - 0.44) / 0.02;
      dx = 0.0133 * (1 - t);
      dy = 0.0675 * (1 - t);
    } else if (p >= 0.51 && p < 0.53) {
      final t = (p - 0.51) / 0.02;
      dx = -0.1667 * t;
      dy = -0.0054 * t;
    } else if (p >= 0.53 && p < 0.55) {
      final t = (p - 0.53) / 0.02;
      dx = -0.1667 * (1 - t);
      dy = -0.0054 * (1 - t);
    } else if (p >= 0.59 && p < 0.61) {
      final t = (p - 0.59) / 0.02;
      dx = 0.0366 * t;
      dy = -0.0246 * t;
    } else if (p >= 0.61 && p < 0.63) {
      final t = (p - 0.61) / 0.02;
      dx = 0.0366 * (1 - t);
      dy = -0.0246 * (1 - t);
    } else if (p >= 0.67 && p < 0.69) {
      final t = (p - 0.67) / 0.02;
      dx = -0.0059 * t;
      dy = 0.1527 * t;
    } else if (p >= 0.69 && p < 0.71) {
      final t = (p - 0.69) / 0.02;
      dx = -0.0059 * (1 - t);
      dy = 0.1527 * (1 - t);
    } else if (p >= 0.74 && p < 0.76) {
      final t = (p - 0.74) / 0.02;
      dx = -0.0192 * t;
      dy = -0.0468 * t;
    } else if (p >= 0.76 && p < 0.78) {
      final t = (p - 0.76) / 0.02;
      dx = -0.0192 * (1 - t);
      dy = -0.0468 * (1 - t);
    } else if (p >= 0.81 && p < 0.83) {
      final t = (p - 0.81) / 0.02;
      dx = 0.0938 * t;
      dy = 0.0096 * t;
    } else if (p >= 0.83 && p < 0.85) {
      final t = (p - 0.83) / 0.02;
      dx = 0.0938 * (1 - t);
      dy = 0.0096 * (1 - t);
    } else if (p >= 0.88 && p < 0.90) {
      final t = (p - 0.88) / 0.02;
      dx = -0.0455 * t;
      dy = 0.0198 * t;
    } else if (p >= 0.90 && p < 0.92) {
      final t = (p - 0.90) / 0.02;
      dx = -0.0455 * (1 - t);
      dy = 0.0198 * (1 - t);
    }

    return Offset(dx * widget.size, dy * widget.size);
  }

  /// Exact piecewise interpolation of @keyframes worm9
  /// from: 10
  /// 25%: 295
  /// to: 1165
  double _getWormAngle(double p) {
    final curvedP = _wormCurve.transform(p);
    double dashOffset;
    if (curvedP <= 0.25) {
      final t = curvedP / 0.25;
      dashOffset = 10.0 + (295.0 - 10.0) * t;
    } else {
      final t = (curvedP - 0.25) / 0.75;
      dashOffset = 295.0 + (1165.0 - 295.0) * t;
    }

    // 295 units is 1 complete circumference in Bethel-nz's SVG
    const circumferenceUnits = 295.0;
    // Invert direction to match SVG stroke-dashoffset clockwise flow
    return (dashOffset / circumferenceUnits) * 2 * math.pi;
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = widget.color ?? const Color(0xFF2E7CFF);
    final trackColor = widget.trackColor ?? const Color(0x18000000);
    final strokeWidth = widget.strokeWidth ?? (widget.size * 0.10).clamp(3.5, 7.5);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = _controller.value;
        final bumpOffset = _getBumpOffset(progress);
        final wormAngle = _getWormAngle(progress);

        return Transform.translate(
          offset: bumpOffset,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: CustomPaint(
              painter: _WormBumpPainter(
                strokeWidth: strokeWidth,
                color: primaryColor,
                trackColor: trackColor,
                wormAngle: wormAngle,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WormBumpPainter extends CustomPainter {
  _WormBumpPainter({
    required this.strokeWidth,
    required this.color,
    required this.trackColor,
    required this.wormAngle,
  });

  final double strokeWidth;
  final Color color;
  final Color trackColor;
  final double wormAngle;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    if (radius <= 0) return;

    // 1. Static track ring (hsla(var(--hue), 10%, 10%, 0.1))
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // 2. Animated worm stroke
    final wormPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(center: center, radius: radius);
    
    // Worm arc length: ~80 degrees (approx 0.22 * 2pi)
    const sweepAngle = 0.22 * 2 * math.pi;
    final startAngle = wormAngle - (math.pi / 2);

    canvas.drawArc(rect, startAngle, sweepAngle, false, wormPaint);
  }

  @override
  bool shouldRepaint(covariant _WormBumpPainter oldDelegate) {
    return oldDelegate.wormAngle != wormAngle ||
        oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

