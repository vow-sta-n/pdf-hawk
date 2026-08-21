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
import 'package:pdfhawk/logic/helpers/pdf_helper.dart';

class DrawingPainter extends CustomPainter {
  final List<DrawingPath> paths;
  final List<Offset> currentPoints;
  final Color currentColor;
  final double currentStrokeWidth;
  final bool isCurrentHighlighter;
  final double scaleX;
  final double scaleY;
  final int? selectedPathIndex;
  final Offset? eyedropperPos;
  final Color? eyedropperColor;

  DrawingPainter({
    required this.paths,
    required this.currentPoints,
    required this.currentColor,
    required this.currentStrokeWidth,
    required this.isCurrentHighlighter,
    required this.scaleX,
    required this.scaleY,
    this.selectedPathIndex,
    this.eyedropperPos,
    this.eyedropperColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < paths.length; i++) {
      final dp = paths[i];
      _drawPath(canvas, dp.points, dp.color, dp.strokeWidth, dp.isHighlighter);

      // If this stroke is currently selected for moving, draw a subtle bounding box
      if (selectedPathIndex != null && selectedPathIndex == i) {
        _drawSelectionHighlight(canvas, dp);
      }
    }

    if (currentPoints.isNotEmpty) {
      _drawPath(
        canvas,
        currentPoints,
        currentColor,
        currentStrokeWidth,
        isCurrentHighlighter,
      );
    }

    // Draw Eyedropper Magnifier Loupe if active
    if (eyedropperPos != null && eyedropperColor != null) {
      _drawEyedropperLoupe(canvas, eyedropperPos!, eyedropperColor!);
    }
  }

  void _drawPath(
    Canvas canvas,
    List<Offset> pts,
    Color color,
    double strokeWidth,
    bool isHighlighter,
  ) {
    if (pts.isEmpty) return;

    if (pts.length == 1) {
      final dotPaint = Paint()
        ..color = isHighlighter ? color.withValues(alpha: 0.4) : color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(pts.first.dx * scaleX, pts.first.dy * scaleY),
        max(strokeWidth / 2, 1.5),
        dotPaint,
      );
      return;
    }

    final paint = Paint()
      ..color = isHighlighter ? color.withValues(alpha: 0.4) : color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    path.moveTo(pts.first.dx * scaleX, pts.first.dy * scaleY);
    for (int i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx * scaleX, pts[i].dy * scaleY);
    }

    canvas.drawPath(path, paint);
  }

  void _drawSelectionHighlight(Canvas canvas, DrawingPath dp) {
    if (dp.points.isEmpty) return;

    double minX = dp.points.first.dx, maxX = dp.points.first.dx;
    double minY = dp.points.first.dy, maxY = dp.points.first.dy;
    for (final p in dp.points) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }

    final rect = Rect.fromLTRB(
      (minX * scaleX) - 10,
      (minY * scaleY) - 10,
      (maxX * scaleX) + 10,
      (maxY * scaleY) + 10,
    );

    final boxPaint = Paint()
      ..color = royalblue.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(6)), boxPaint);

    final borderPaint = Paint()
      ..color = royalblue
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(6)), borderPaint);
  }

  void _drawEyedropperLoupe(Canvas canvas, Offset pos, Color color) {
    const loupeRadius = 26.0;
    // Offset loupe slightly above finger position
    final center = Offset(pos.dx, max(pos.dy - 50.0, loupeRadius + 10));

    // Outer shadow
    final shadowPaint = Paint()
      ..color = Colors.black45
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(center, loupeRadius + 2, shadowPaint);

    // Color fill circle
    final colorFillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, loupeRadius, colorFillPaint);

    // Inner White Ring
    final ringPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, loupeRadius, ringPaint);

    // Center crosshair
    final crosshairPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(center.dx - 6, center.dy), Offset(center.dx + 6, center.dy), crosshairPaint);
    canvas.drawLine(Offset(center.dx, center.dy - 6), Offset(center.dx, center.dy + 6), crosshairPaint);
  }

  @override
  bool shouldRepaint(covariant DrawingPainter oldDelegate) => true;
}
