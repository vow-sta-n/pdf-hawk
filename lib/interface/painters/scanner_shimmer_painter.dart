/*
 * PDF Hawk - Modern PDF Reader, Writer, Editor & Scanner
 * Copyright (C) 2026 Van Stan / Novaturients
 *
 * This software is licensed under the PolyForm Noncommercial License 1.0.0.
 * You may obtain a copy of the License at https://polyformproject.org/licenses/noncommercial/1.0.0
 */

import 'package:flutter/material.dart';
import 'package:pdfhawk/data/res/theme.dart';

/// Custom painter to draw a futuristic live scanning shimmer beam across the viewfinder
class ScannerShimmerPainter extends CustomPainter {
  final double progress;
  final Color glowColor;
  final double cornerRadius;

  const ScannerShimmerPainter({
    required this.progress,
    this.glowColor = royalblue,
    this.cornerRadius = 2.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final scanY = size.height * progress.clamp(0.0, 1.0);
    const double trailHeight = 70.0;

    canvas.save();
    // Clip within the document bounding box
    canvas.clipRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(cornerRadius),
      ),
    );

    // 1. Ambient scanning tint across document area
    final ambientPaint = Paint()
      ..color = glowColor.withValues(alpha: 0.03)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), ambientPaint);

    // 2. Trailing gradient beam
    final double trailTop = (scanY - trailHeight).clamp(0.0, size.height);
    final double trailBottom = (scanY + 8.0).clamp(0.0, size.height);
    if (trailBottom > trailTop) {
      final trailRect = Rect.fromLTRB(0, trailTop, size.width, trailBottom);
      final trailPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            glowColor.withValues(alpha: 0.0),
            glowColor.withValues(alpha: 0.08),
            glowColor.withValues(alpha: 0.22),
          ],
        ).createShader(trailRect);

      canvas.drawRect(trailRect, trailPaint);
    }

    // 3. Glowing outer laser scan line
    final outerGlowPaint = Paint()
      ..color = glowColor.withValues(alpha: 0.5)
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);

    canvas.drawLine(
      Offset(0, scanY),
      Offset(size.width, scanY),
      outerGlowPaint,
    );

    // 4. Bright gradient core scan line with fading edges
    final coreLinePaint = Paint()
      ..shader = LinearGradient(
        colors: [
          glowColor.withValues(alpha: 0.0),
          glowColor.withValues(alpha: 0.8),
          Colors.white,
          glowColor.withValues(alpha: 0.8),
          glowColor.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.15, 0.5, 0.85, 1.0],
      ).createShader(Rect.fromLTWH(0, scanY, size.width, 2.0))
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(0, scanY), Offset(size.width, scanY), coreLinePaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ScannerShimmerPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.glowColor != glowColor ||
        oldDelegate.cornerRadius != cornerRadius;
  }
}
