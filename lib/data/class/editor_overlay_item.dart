/*
 * PDF Hawk - Modern PDF Reader, Writer, Editor & Scanner
 * Copyright (C) 2026 Van Stan / Novaturients
 *
 * This software is licensed under the PolyForm Noncommercial License 1.0.0.
 * You may obtain a copy of the License at https://polyformproject.org/licenses/noncommercial/1.0.0
 */

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdfhawk/data/res/enum.dart';
import 'package:pdfhawk/data/res/theme.dart';

class EditorOverlayItem {
  final String id;
  ElementType type;

  // Normalized geometry (0.0 to 1.0 relative to canvas width/height)
  Offset position; // Center point
  double width;
  double height;
  double rotation; // Degrees (0 to 360)
  double opacity;

  // Image Specifics
  String? imagePath;
  Uint8List? imageBytes;

  // Shape Specifics
  ShapeType shapeType;
  Color fillColor;
  Color strokeColor;
  double strokeWidth;
  bool isFilled;

  // Text Specifics
  String text;
  Color textColor;
  double fontSize;
  bool isBold;
  bool isItalic;
  Color? backgroundColor;

  EditorOverlayItem({
    String? id,
    required this.type,
    this.position = const Offset(0.5, 0.5),
    this.width = 0.35,
    this.height = 0.35,
    this.rotation = 0.0,
    this.opacity = 1.0,
    this.imagePath,
    this.imageBytes,
    this.shapeType = ShapeType.rectangle,
    this.fillColor = Colors.transparent,
    this.strokeColor = royalblue,
    this.strokeWidth = 3.0,
    this.isFilled = false,
    this.text = "Sample Text",
    this.textColor = Colors.white,
    this.fontSize = 24.0,
    this.isBold = false,
    this.isItalic = false,
    this.backgroundColor,
  }) : id = id ?? UniqueKey().toString();

  EditorOverlayItem clone({Offset? offset}) {
    return EditorOverlayItem(
      id: UniqueKey().toString(),
      type: type,
      position: offset != null
          ? Offset(
              (position.dx + offset.dx).clamp(0.05, 0.95),
              (position.dy + offset.dy).clamp(0.05, 0.95),
            )
          : position,
      width: width,
      height: height,
      rotation: rotation,
      opacity: opacity,
      imagePath: imagePath,
      imageBytes: imageBytes,
      shapeType: shapeType,
      fillColor: fillColor,
      strokeColor: strokeColor,
      strokeWidth: strokeWidth,
      isFilled: isFilled,
      text: text,
      textColor: textColor,
      fontSize: fontSize,
      isBold: isBold,
      isItalic: isItalic,
      backgroundColor: backgroundColor,
    );
  }
}
