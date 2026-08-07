import 'package:flutter/material.dart';
import 'package:pdfhawk/logic/helpers/pdf_helper.dart';

class SignaturePainter extends CustomPainter {
  final List<DrawingPath> paths;
  final List<Offset> currentPoints;
  final Color color;

  SignaturePainter({
    required this.paths,
    required this.currentPoints,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (final path in paths) {
      if (path.points.length < 2) continue;
      final p = Path();
      p.moveTo(path.points.first.dx, path.points.first.dy);
      for (int i = 1; i < path.points.length; i++) {
        p.lineTo(path.points[i].dx, path.points[i].dy);
      }
      canvas.drawPath(p, paint);
    }

    if (currentPoints.length > 1) {
      final p = Path();
      p.moveTo(currentPoints.first.dx, currentPoints.first.dy);
      for (int i = 1; i < currentPoints.length; i++) {
        p.lineTo(currentPoints[i].dx, currentPoints[i].dy);
      }
      canvas.drawPath(p, paint);
    }
  }

  @override
  bool shouldRepaint(covariant SignaturePainter oldDelegate) => true;
}
