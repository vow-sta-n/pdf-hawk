/*
 * PDF Hawk - Modern PDF Reader, Writer, Editor & Scanner
 * Copyright (C) 2026 Van Stan / Novaturients
 *
 * This software is licensed under the PolyForm Noncommercial License 1.0.0.
 * You may obtain a copy of the License at https://polyformproject.org/licenses/noncommercial/1.0.0
 */

import 'package:flutter/material.dart';

/// Paints a semi-transparent dark mask over the camera viewfinder,
/// leaving the crop framing rectangle clear (un-tinted) to indicate
/// the active capture area and eliminated margins.
class CameraCropMaskPainter extends CustomPainter {
  final Rect frameRect;
  final Color maskColor;
  final double cornerRadius;

  const CameraCropMaskPainter({
    required this.frameRect,
    this.maskColor = const Color(0x99000000),
    this.cornerRadius = 4.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(
        RRect.fromRectAndRadius(
          frameRect,
          Radius.circular(cornerRadius),
        ),
      );

    final paint = Paint()
      ..color = maskColor
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CameraCropMaskPainter oldDelegate) {
    return oldDelegate.frameRect != frameRect ||
        oldDelegate.maskColor != maskColor ||
        oldDelegate.cornerRadius != cornerRadius;
  }
}
