import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class BubbleButton extends StatelessWidget {
  final IconData icon;
  final Function() onTap;
  final double? iconSize;
  final EdgeInsetsGeometry? padding;
  final double? buttonHeight;
  final double? buttonWidth;
  const BubbleButton({
    super.key,

    required this.icon,
    required this.onTap,
    this.iconSize,
    this.padding,
    this.buttonHeight,
    this.buttonWidth,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: padding ?? EdgeInsets.only(left: 10, right: 10),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: buttonWidth ?? 15,
            vertical: buttonHeight ?? 15,
          ),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.02)
                : Colors.black.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.12),
              width: 1.5,
            ),
          ),
          child: Center(child: Icon(icon, size: iconSize ?? 18.sp)),
        ),
      ),
    );
  }
}
