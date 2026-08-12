/*
 * PDF Hawk - Modern PDF Reader, Writer, Editor & Scanner
 * Copyright (C) 2026 Van Stan / Novaturients
 *
 * This software is licensed under the PolyForm Noncommercial License 1.0.0.
 * You may obtain a copy of the License at https://polyformproject.org/licenses/noncommercial/1.0.0
 */

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:pdfhawk/data/res/theme.dart';

class CircleDialPainter extends CustomPainter {
  final Color circleColor;
  final Color tickColor;

  CircleDialPainter({
    this.circleColor = Colors.white,
    this.tickColor = Colors.white,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final Paint circlePaint = Paint()
      ..color = transparent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Draw outer circle
    canvas.drawCircle(center, radius, circlePaint);

    final Paint tickPaint = Paint()
      ..color = tickColor
      ..strokeCap = StrokeCap.round;

    const int tickCount = 60;

    for (int i = 0; i < tickCount; i++) {
      double angle = (i * 6) * pi / 180; // 360° / 60 = 6°
      final double cosA = cos(angle);
      final double sinA = sin(angle);

      // Major ticks at 12, 3, 6, 9
      bool isMajor = (i % 15 == 0);

      double tickLength = isMajor ? radius * 0.15 : radius * 0.07;
      double tickWidth = isMajor ? 2 : .5;

      tickPaint.strokeWidth = tickWidth;

      // Start point (outer rim)
      final Offset p1 = Offset(
        center.dx + cosA * radius,
        center.dy + sinA * radius,
      );

      // End point (inwards)
      final Offset p2 = Offset(
        center.dx + cosA * (radius - tickLength),
        center.dy + sinA * (radius - tickLength),
      );

      canvas.drawLine(p1, p2, tickPaint);
    }
  }

  @override
  bool shouldRepaint(CircleDialPainter oldDelegate) {
    return false;
  }
}
