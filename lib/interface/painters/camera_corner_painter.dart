/*
 * PDF Hawk - Modern PDF Reader, Writer, Editor & Scanner
 * Copyright (C) 2026 Van Stan / Novaturients
 *
 * This software is licensed under the PolyForm Noncommercial License 1.0.0.
 * You may obtain a copy of the License at https://polyformproject.org/licenses/noncommercial/1.0.0
 */

import 'package:flutter/material.dart';

/// Custom painter to draw clean corner framing guides for the camera viewfinder
class CameraCornerPainter extends CustomPainter {
  final Color color;
  final double cornerLength;
  final double strokeWidth;
  final double cornerRadius;

  const CameraCornerPainter({
    this.color = Colors.white70,
    this.cornerLength = 32.0,
    this.strokeWidth = 2.5,
    this.cornerRadius = 10.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final double effectiveLength = (cornerLength > size.width / 3)
        ? size.width / 3
        : cornerLength;
    final double effectiveRadius = (cornerRadius > effectiveLength / 2)
        ? effectiveLength / 2
        : cornerRadius;

    final path = Path();

    // Top-Left corner
    if (effectiveRadius > 0) {
      path.moveTo(0, effectiveLength);
      path.lineTo(0, effectiveRadius);
      path.arcToPoint(
        Offset(effectiveRadius, 0),
        radius: Radius.circular(effectiveRadius),
      );
      path.lineTo(effectiveLength, 0);
    } else {
      path.moveTo(0, effectiveLength);
      path.lineTo(0, 0);
      path.lineTo(effectiveLength, 0);
    }

    // Top-Right corner
    if (effectiveRadius > 0) {
      path.moveTo(size.width - effectiveLength, 0);
      path.lineTo(size.width - effectiveRadius, 0);
      path.arcToPoint(
        Offset(size.width, effectiveRadius),
        radius: Radius.circular(effectiveRadius),
      );
      path.lineTo(size.width, effectiveLength);
    } else {
      path.moveTo(size.width - effectiveLength, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, effectiveLength);
    }

    // Bottom-Left corner
    if (effectiveRadius > 0) {
      path.moveTo(0, size.height - effectiveLength);
      path.lineTo(0, size.height - effectiveRadius);
      path.arcToPoint(
        Offset(effectiveRadius, size.height),
        radius: Radius.circular(effectiveRadius),
        clockwise: false,
      );
      path.lineTo(effectiveLength, size.height);
    } else {
      path.moveTo(0, size.height - effectiveLength);
      path.lineTo(0, size.height);
      path.lineTo(effectiveLength, size.height);
    }

    // Bottom-Right corner
    if (effectiveRadius > 0) {
      path.moveTo(size.width - effectiveLength, size.height);
      path.lineTo(size.width - effectiveRadius, size.height);
      path.arcToPoint(
        Offset(size.width, size.height - effectiveRadius),
        radius: Radius.circular(effectiveRadius),
        clockwise: false,
      );
      path.lineTo(size.width, size.height - effectiveLength);
    } else {
      path.moveTo(size.width - effectiveLength, size.height);
      path.lineTo(size.width, size.height);
      path.lineTo(size.width, size.height - effectiveLength);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CameraCornerPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.cornerLength != cornerLength ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.cornerRadius != cornerRadius;
  }
}
