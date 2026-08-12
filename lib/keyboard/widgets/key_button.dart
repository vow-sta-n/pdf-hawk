/*
 * PDF Hawk - Modern PDF Reader, Writer, Editor & Scanner
 * Copyright (C) 2026 Van Stan / Novaturients
 *
 * This software is licensed under the PolyForm Noncommercial License 1.0.0.
 * You may obtain a copy of the License at https://polyformproject.org/licenses/noncommercial/1.0.0
 */

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdfhawk/keyboard/models/keyboard_key.dart';

class KeyButton extends StatefulWidget {
  final KeyData keyData;
  final VoidCallback onTap;
  final bool isDark;
  final Color? activeColor;
  final bool isSpecialKey;
  final bool isActive;
  final double? customHeight;

  const KeyButton({
    super.key,
    required this.keyData,
    required this.onTap,
    this.isDark = false,
    this.activeColor,
    this.isSpecialKey = false,
    this.isActive = false,
    this.customHeight,
  });

  @override
  State<KeyButton> createState() => _KeyButtonState();
}

class _KeyButtonState extends State<KeyButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final themePrimary = widget.activeColor ?? Theme.of(context).colorScheme.primary;

    Color keyBgColor;
    if (widget.isActive) {
      keyBgColor = themePrimary;
    } else if (_isPressed) {
      keyBgColor = widget.isDark
          ? Colors.grey.shade700
          : Colors.grey.shade400;
    } else if (widget.isSpecialKey) {
      keyBgColor = widget.isDark
          ? const Color(0xFF2C2C2E)
          : const Color(0xFFD0D3D9);
    } else {
      keyBgColor = widget.isDark
          ? const Color(0xFF3A3A3C)
          : Colors.white;
    }

    Color textColor;
    if (widget.isActive) {
      textColor = Colors.white;
    } else {
      textColor = widget.isDark ? Colors.white : const Color(0xFF1C1C1E);
    }

    return Expanded(
      flex: (widget.keyData.flex * 100).toInt(),
      child: Padding(
        padding: EdgeInsets.all(2.5.r),
        child: GestureDetector(
          onTapDown: (_) {
            HapticFeedback.lightImpact();
            setState(() => _isPressed = true);
          },
          onTapUp: (_) {
            setState(() => _isPressed = false);
            widget.onTap();
          },
          onTapCancel: () {
            setState(() => _isPressed = false);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 60),
            height: widget.customHeight ?? 42.h,
            decoration: BoxDecoration(
              color: keyBgColor,
              borderRadius: BorderRadius.circular(6.r),
              boxShadow: widget.isActive || _isPressed
                  ? []
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: widget.isDark ? 0.3 : 0.18),
                        blurRadius: 1,
                        offset: const Offset(0, 1.2),
                      ),
                    ],
              border: widget.isActive
                  ? Border.all(color: themePrimary, width: 1.2)
                  : Border.all(
                      color: widget.isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.06),
                      width: 0.8,
                    ),
            ),
            child: Stack(
              children: [
                if (widget.keyData.secondaryLabel != null)
                  Positioned(
                    top: 2.h,
                    right: 4.w,
                    child: Text(
                      widget.keyData.secondaryLabel!,
                      style: GoogleFonts.inter(
                        fontSize: 9.sp,
                        color: textColor.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                Center(
                  child: _buildKeyContent(textColor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeyContent(Color textColor) {
    switch (widget.keyData.type) {
      case KeyType.backspace:
        return Icon(
          Icons.backspace_outlined,
          size: 18.sp,
          color: textColor,
        );
      case KeyType.enter:
        return Icon(
          Icons.keyboard_return_rounded,
          size: 18.sp,
          color: textColor,
        );
      case KeyType.shift:
      case KeyType.capsLock:
        return Icon(
          widget.isActive
              ? Icons.keyboard_capslock_rounded
              : Icons.arrow_upward_rounded,
          size: 18.sp,
          color: textColor,
        );
      case KeyType.arrowUp:
        return Icon(Icons.arrow_drop_up_rounded, size: 20.sp, color: textColor);
      case KeyType.arrowDown:
        return Icon(Icons.arrow_drop_down_rounded, size: 20.sp, color: textColor);
      case KeyType.arrowLeft:
        return Icon(Icons.arrow_left_rounded, size: 20.sp, color: textColor);
      case KeyType.arrowRight:
        return Icon(Icons.arrow_right_rounded, size: 20.sp, color: textColor);
      case KeyType.emoji:
        return Icon(Icons.emoji_emotions_outlined, size: 18.sp, color: textColor);
      default:
        return Text(
          widget.keyData.label,
          style: GoogleFonts.inter(
            fontSize: widget.keyData.label.length > 2 ? 11.sp : 15.sp,
            fontWeight: widget.keyData.type == KeyType.character
                ? FontWeight.w500
                : FontWeight.w600,
            color: textColor,
          ),
        );
    }
  }
}
