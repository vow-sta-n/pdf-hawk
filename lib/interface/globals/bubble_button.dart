import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pdfhawk/data/res/utils.dart';

class BubbleButton extends StatelessWidget {
  final IconData icon;
  final Function() onTap;
  final double? iconSize;
  final EdgeInsetsGeometry? padding;
  final double? buttonHeight;
  final double? buttonWidth;
  final String? tooltip;
  final BoxShape? shape;
  const BubbleButton({
    super.key,

    required this.icon,
    required this.onTap,
    this.shape,
    this.iconSize,
    this.padding,
    this.tooltip,
    this.buttonHeight,
    this.buttonWidth,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: padding ?? EdgeInsets.only(left: 10, right: 10),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: allradius(10),
        child: Tooltip(
          message: tooltip ?? "",
          child: InkWell(
            borderRadius: allradius(10),
            onTap: onTap,
            child: Container(
              width: buttonWidth ?? 38.r,
              height: buttonHeight ?? 38.r,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.02)
                    : Colors.black.withValues(alpha: 0.05),
                borderRadius: shape != null ? null : allradius(10),
                shape: shape ?? BoxShape.rectangle,
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.black.withValues(alpha: 0.12),
                  width: 1.5,
                ),
              ),
              child: Icon(
                icon,
                size: iconSize ?? 16.sp,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
