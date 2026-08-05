import 'package:flutter/material.dart';
import 'package:pdfhawk/data/res/enum.dart';

class ShapePainter extends CustomPainter {
  final ShapeType shapeType;
  final Color fillColor;
  final Color borderColor;
  final double borderWidth;

  ShapePainter({
    required this.shapeType,
    required this.fillColor,
    required this.borderColor,
    required this.borderWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paintFill = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    final paintBorder = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    if (shapeType == ShapeType.rectangle) {
      canvas.drawRect(rect, paintFill);
      if (borderWidth > 0) {
        canvas.drawRect(rect, paintBorder);
      }
    } else if (shapeType == ShapeType.circle || shapeType == ShapeType.oval) {
      canvas.drawOval(rect, paintFill);
      if (borderWidth > 0) {
        canvas.drawOval(rect, paintBorder);
      }
    }
  }

  @override
  bool shouldRepaint(covariant ShapePainter oldDelegate) {
    return oldDelegate.shapeType != shapeType ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.borderWidth != borderWidth;
  }
}
