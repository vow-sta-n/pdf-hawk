/*
 * PDF Hawk - Modern PDF Reader, Writer, Editor & Scanner
 * Copyright (C) 2026 Van Stan / Novaturients
 *
 * This software is licensed under the PolyForm Noncommercial License 1.0.0.
 * You may obtain a copy of the License at https://polyformproject.org/licenses/noncommercial/1.0.0
 */

import 'package:flutter/material.dart';

class CircularColorChip extends StatelessWidget {
  final double? height;
  final double? width;
  final double? elevation;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final BoxShape shape;
  final BoxBorder? border;
  final Widget? child;

  const CircularColorChip({
    super.key,
    this.height,
    this.width,
    this.elevation,
    this.margin,
    this.color,
    this.shape = BoxShape.rectangle,
    this.border,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      margin: margin,
      decoration: BoxDecoration(
        color: color,
        shape: shape,
        border: border,
        boxShadow: elevation != null && elevation! > 0
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: elevation!,
                  spreadRadius: elevation! / 2,
                ),
              ]
            : null,
      ),
      child: child,
    );
  }
}