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