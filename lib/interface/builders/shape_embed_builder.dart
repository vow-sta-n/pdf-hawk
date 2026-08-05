import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

class ShapeEmbedBuilder extends EmbedBuilder {
  @override
  String get key => 'shape';

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    try {
      final value = embedContext.node.value.data as String;
      final data = jsonDecode(value) as Map<String, dynamic>;

      final shapeStr = data['shapeType'] as String? ?? 'rectangle';
      final fillColorVal = data['fillColor'] as int?;
      final borderColorVal = data['borderColor'] as int?;
      final borderWidth = (data['borderWidth'] as num? ?? 1.0).toDouble();
      final width = (data['width'] as num? ?? 100.0).toDouble();
      final height = (data['height'] as num? ?? 60.0).toDouble();

      final fillColor = fillColorVal != null
          ? Color(fillColorVal)
          : Colors.transparent;
      final borderColor = borderColorVal != null
          ? Color(borderColorVal)
          : Colors.black;

      Widget shapeWidget;
      if (shapeStr == 'circle') {
        shapeWidget = Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: fillColor,
            border: Border.all(color: borderColor, width: borderWidth),
          ),
        );
      } else if (shapeStr == 'oval') {
        shapeWidget = Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.all(
              Radius.elliptical(width / 2, height / 2),
            ),
            color: fillColor,
            border: Border.all(color: borderColor, width: borderWidth),
          ),
        );
      } else {
        // Rectangle
        shapeWidget = Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: fillColor,
            border: Border.all(color: borderColor, width: borderWidth),
          ),
        );
      }

      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: shapeWidget,
        ),
      );
    } catch (e) {
      return Container(
        color: Colors.red.shade100,
        padding: const EdgeInsets.all(8),
        child: Text("Error rendering inline shape: $e"),
      );
    }
  }
}
