import 'dart:math';
import 'package:flutter/material.dart';

class AngleKnobPainter extends CustomPainter {
  final double angleInDegrees;
  final Color activeColor;

  AngleKnobPainter({required this.angleInDegrees, required this.activeColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 4.0;

    // 1. Translucent Background Dial Disc
    final discPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, discPaint);

    // 2. Outer Track Ring
    final trackPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, radius, trackPaint);

    // 3. Dense precision tick marks every 5 degrees (72 ticks total)
    for (int i = 0; i < 72; i++) {
      final tickAngle = i * (2 * pi / 72) - (pi / 2);
      final degree = i * 5;
      double tickLength;
      double strokeWidth;
      Color tickColor;

      if (degree % 90 == 0) {
        tickLength = 12.0;
        strokeWidth = 2.0;
        tickColor = Colors.white;
      } else if (degree % 45 == 0) {
        tickLength = 9.0;
        strokeWidth = 1.6;
        tickColor = Colors.white.withValues(alpha: 0.8);
      } else if (degree % 15 == 0) {
        tickLength = 6.5;
        strokeWidth = 1.2;
        tickColor = Colors.white.withValues(alpha: 0.5);
      } else {
        tickLength = 3.5;
        strokeWidth = 0.8;
        tickColor = Colors.white.withValues(alpha: 0.25);
      }

      final p1 = Offset(
        center.dx + (radius - 2) * cos(tickAngle),
        center.dy + (radius - 2) * sin(tickAngle),
      );
      final p2 = Offset(
        center.dx + (radius - 2 - tickLength) * cos(tickAngle),
        center.dy + (radius - 2 - tickLength) * sin(tickAngle),
      );

      final tickPaint = Paint()
        ..color = tickColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;
      canvas.drawLine(p1, p2, tickPaint);
    }

    // 4. Active Progress Arc
    final sweepAngle = (angleInDegrees * pi / 180);
    if (sweepAngle > 0.01) {
      final activeArcPaint = Paint()
        ..color = activeColor
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 3.5;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2, // start from top (12 o'clock)
        sweepAngle,
        false,
        activeArcPaint,
      );
    }

    // 5. Indicator Knob Pointer (thumb dot on outer rim)
    final indicatorAngle = (angleInDegrees * pi / 180) - (pi / 2);
    final knobOffset = Offset(
      center.dx + radius * cos(indicatorAngle),
      center.dy + radius * sin(indicatorAngle),
    );

    // Outer glow / halo around pointer
    final glowPaint = Paint()
      ..color = activeColor.withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(knobOffset, 7.5, glowPaint);

    // Solid pointer dot
    final knobPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(knobOffset, 4.5, knobPaint);

    // Inner rim dot border
    final knobBorderPaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(knobOffset, 4.5, knobBorderPaint);
  }

  @override
  bool shouldRepaint(covariant AngleKnobPainter oldDelegate) {
    return oldDelegate.angleInDegrees != angleInDegrees ||
        oldDelegate.activeColor != activeColor;
  }
}
