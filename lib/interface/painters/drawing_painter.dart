import 'package:flutter/material.dart';
import 'package:pdfhawk/logic/helpers/pdf_helper.dart';

class DrawingPainter extends CustomPainter {
  final List<DrawingPath> paths;
  final List<Offset> currentPoints;
  final Color currentColor;
  final double currentStrokeWidth;
  final bool isCurrentHighlighter;
  final double scaleX;
  final double scaleY;

  DrawingPainter({
    required this.paths,
    required this.currentPoints,
    required this.currentColor,
    required this.currentStrokeWidth,
    required this.isCurrentHighlighter,
    required this.scaleX,
    required this.scaleY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final dp in paths) {
      _drawPath(canvas, dp.points, dp.color, dp.strokeWidth, dp.isHighlighter);
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
  }

  void _drawPath(
    Canvas canvas,
    List<Offset> pts,
    Color color,
    double strokeWidth,
    bool isHighlighter,
  ) {
    if (pts.isEmpty) return;

    final paint = Paint()
      ..color = isHighlighter ? color.withValues(alpha: 0.4) : color
      ..strokeWidth = strokeWidth * ((scaleX + scaleY) / 2)
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

  @override
  bool shouldRepaint(covariant DrawingPainter oldDelegate) => true;
}
