/*
 * PDF Hawk - Modern PDF Reader, Writer, Editor & Scanner
 * Copyright (C) 2026 Van Stan / Novaturients
 *
 * This software is licensed under the PolyForm Noncommercial License 1.0.0.
 * You may obtain a copy of the License at https://polyformproject.org/licenses/noncommercial/1.0.0
 */

import 'package:flutter/material.dart';
import 'package:pdfhawk/data/res/theme.dart';

class CropOverlayPainter extends CustomPainter {
  final Rect cropRect;

  CropOverlayPainter({required this.cropRect});

  @override
  void paint(Canvas canvas, Size size) {
    final paintDim = Paint()
      ..color = Colors.black.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;

    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()..addRect(cropRect),
      ),
      paintDim,
    );

    final paintBorder = Paint()
      ..color = royalblue.withAlpha(150)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawRect(cropRect, paintBorder);

    final paintGrid = Paint()
      ..color = Colors.white30
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    final wThird = cropRect.width / 3;
    final hThird = cropRect.height / 3;

    canvas.drawLine(
      Offset(cropRect.left + wThird, cropRect.top),
      Offset(cropRect.left + wThird, cropRect.bottom),
      paintGrid,
    );
    canvas.drawLine(
      Offset(cropRect.left + wThird * 2, cropRect.top),
      Offset(cropRect.left + wThird * 2, cropRect.bottom),
      paintGrid,
    );

    canvas.drawLine(
      Offset(cropRect.left, cropRect.top + hThird),
      Offset(cropRect.right, cropRect.top + hThird),
      paintGrid,
    );
    canvas.drawLine(
      Offset(cropRect.left, cropRect.top + hThird * 2),
      Offset(cropRect.right, cropRect.top + hThird * 2),
      paintGrid,
    );
  }

  @override
  bool shouldRepaint(covariant CropOverlayPainter oldDelegate) {
    return oldDelegate.cropRect != cropRect;
  }
}
