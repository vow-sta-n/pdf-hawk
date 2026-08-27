/*
 * PDF Hawk - Modern PDF Reader, Writer, Editor & Scanner
 * Copyright (C) 2026 Van Stan / Novaturients
 *
 * This software is licensed under the PolyForm Noncommercial License 1.0.0.
 * You may obtain a copy of the License at https://polyformproject.org/licenses/noncommercial/1.0.0
 */

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:pdfhawk/data/res/enum.dart';

class ShapePainter extends CustomPainter {
  final ShapeType shapeType;
  final Color fillColor;
  final Color borderColor;
  final double borderWidth;
  final bool isFilled;

  ShapePainter({
    required this.shapeType,
    required this.fillColor,
    required this.borderColor,
    required this.borderWidth,
    this.isFilled = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paintFill = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    final paintBorder = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final w = size.width;
    final h = size.height;

    switch (shapeType) {
      case ShapeType.rectangle:
        if (isFilled && fillColor != Colors.transparent) {
          canvas.drawRect(rect, paintFill);
        }
        if (borderWidth > 0) {
          canvas.drawRect(rect, paintBorder);
        }
        break;

      case ShapeType.roundedRectangle:
        final rrect = RRect.fromRectAndRadius(
          rect,
          Radius.circular(min(w, h) * 0.15),
        );
        if (isFilled && fillColor != Colors.transparent) {
          canvas.drawRRect(rrect, paintFill);
        }
        if (borderWidth > 0) {
          canvas.drawRRect(rrect, paintBorder);
        }
        break;

      case ShapeType.circle:
      case ShapeType.oval:
        if (isFilled && fillColor != Colors.transparent) {
          canvas.drawOval(rect, paintFill);
        }
        if (borderWidth > 0) {
          canvas.drawOval(rect, paintBorder);
        }
        break;

      case ShapeType.triangle:
        final path = Path()
          ..moveTo(w / 2, 0)
          ..lineTo(w, h)
          ..lineTo(0, h)
          ..close();
        if (isFilled && fillColor != Colors.transparent) {
          canvas.drawPath(path, paintFill);
        }
        if (borderWidth > 0) {
          canvas.drawPath(path, paintBorder);
        }
        break;

      case ShapeType.star:
        final path = _createStarPath(size);
        if (isFilled && fillColor != Colors.transparent) {
          canvas.drawPath(path, paintFill);
        }
        if (borderWidth > 0) {
          canvas.drawPath(path, paintBorder);
        }
        break;

      case ShapeType.heart:
        final path = _createHeartPath(size);
        if (isFilled && fillColor != Colors.transparent) {
          canvas.drawPath(path, paintFill);
        }
        if (borderWidth > 0) {
          canvas.drawPath(path, paintBorder);
        }
        break;

      case ShapeType.arrow:
        final path = _createArrowPath(size);
        if (isFilled && fillColor != Colors.transparent) {
          canvas.drawPath(path, paintFill);
        }
        if (borderWidth > 0) {
          canvas.drawPath(path, paintBorder);
        }
        break;

      case ShapeType.line:
        canvas.drawLine(
          Offset(0, h / 2),
          Offset(w, h / 2),
          paintBorder..style = PaintingStyle.stroke,
        );
        break;

      case ShapeType.checkmark:
        final path = Path()
          ..moveTo(w * 0.15, h * 0.55)
          ..lineTo(w * 0.42, h * 0.85)
          ..lineTo(w * 0.85, h * 0.15);
        canvas.drawPath(
          path,
          paintBorder
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
        break;

      case ShapeType.cross:
        canvas.drawLine(
          Offset(w * 0.2, h * 0.2),
          Offset(w * 0.8, h * 0.8),
          paintBorder,
        );
        canvas.drawLine(
          Offset(w * 0.8, h * 0.2),
          Offset(w * 0.2, h * 0.8),
          paintBorder,
        );
        break;
    }
  }

  Path _createStarPath(Size size, {int points = 5}) {
    final path = Path();
    final halfWidth = size.width / 2;
    final halfHeight = size.height / 2;
    final outerRadius = min(halfWidth, halfHeight);
    final innerRadius = outerRadius * 0.42;

    final step = pi / points;
    var angle = -pi / 2;

    for (var i = 0; i < points * 2; i++) {
      final r = i.isEven ? outerRadius : innerRadius;
      final x = halfWidth + r * cos(angle);
      final y = halfHeight + r * sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      angle += step;
    }
    path.close();
    return path;
  }

  Path _createHeartPath(Size size) {
    final path = Path();
    final w = size.width;
    final h = size.height;

    path.moveTo(w * 0.5, h * 0.82);
    path.cubicTo(w * 0.2, h * 0.6, 0, h * 0.38, 0, h * 0.22);
    path.cubicTo(0, h * 0.08, w * 0.18, 0, w * 0.35, 0);
    path.cubicTo(w * 0.45, 0, w * 0.5, h * 0.08, w * 0.5, h * 0.12);
    path.cubicTo(w * 0.5, h * 0.08, w * 0.55, 0, w * 0.65, 0);
    path.cubicTo(w * 0.82, 0, w, h * 0.08, w, h * 0.22);
    path.cubicTo(w, h * 0.38, w * 0.8, h * 0.6, w * 0.5, h * 0.82);
    path.close();
    return path;
  }

  Path _createArrowPath(Size size) {
    final path = Path();
    final w = size.width;
    final h = size.height;
    final shaftHeight = h * 0.28;
    final headWidth = w * 0.35;

    path.moveTo(0, (h - shaftHeight) / 2);
    path.lineTo(w - headWidth, (h - shaftHeight) / 2);
    path.lineTo(w - headWidth, h * 0.1);
    path.lineTo(w, h * 0.5);
    path.lineTo(w - headWidth, h * 0.9);
    path.lineTo(w - headWidth, (h + shaftHeight) / 2);
    path.lineTo(0, (h + shaftHeight) / 2);
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant ShapePainter oldDelegate) {
    return oldDelegate.shapeType != shapeType ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.borderWidth != borderWidth ||
        oldDelegate.isFilled != isFilled;
  }
}
