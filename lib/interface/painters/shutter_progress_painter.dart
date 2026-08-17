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

/// Custom painter to draw the circular shutter button with a radial progress overlay
class ShutterProgressPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Color baseColor;
  final Color progressColor;

  const ShutterProgressPainter({
    required this.progress,
    this.strokeWidth = 4.0,
    this.baseColor = Colors.white,
    this.progressColor = royalblue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    if (radius <= 0) return;

    // 1. Base ring
    final basePaint = Paint()
      ..color = baseColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, radius, basePaint);

    // 2. Overlay progress arc starting at 90 degrees (pi/2) going clockwise
    if (progress > 0) {
      final progressPaint = Paint()
        ..color = progressColor
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      const double startAngle = pi / 2; // 90 degree angle (bottom)
      final double sweepAngle = 2 * pi * progress.clamp(0.0, 1.0);

      final rect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawArc(rect, startAngle, sweepAngle, false, progressPaint);
    }
  }

  @override
  bool shouldRepaint(covariant ShutterProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.baseColor != baseColor ||
        oldDelegate.progressColor != progressColor;
  }
}
