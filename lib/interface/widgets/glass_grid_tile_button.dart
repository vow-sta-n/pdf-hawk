/*
 * PDF Hawk - Modern PDF Reader, Writer, Editor & Scanner
 * Copyright (C) 2026 Van Stan / Novaturients
 *
 * This software is licensed under the PolyForm Noncommercial License 1.0.0.
 * You may obtain a copy of the License at https://polyformproject.org/licenses/noncommercial/1.0.0
 */

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdfhawk/data/res/constants.dart';

class GlassGridTileButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;
  final double space;
  final bool isLoading;
  final ThemeData? theme;
  final bool? isDark;

  const GlassGridTileButton({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    this.isLoading = false,
    this.space = 0,
    this.theme,
    this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTheme = theme ?? Theme.of(context);
    final effectiveIsDark =
        isDark ?? (effectiveTheme.brightness == Brightness.dark);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: effectiveIsDark
              ? Colors.white.withValues(alpha: 0.02)
              : Colors.black.withValues(alpha: 0.02),
          borderRadius: allradius(22.r),
          border: Border.all(
            color: effectiveIsDark
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.12),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            isLoading
                ? SizedBox(
                    width: 34.r,
                    height: 34.r,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: effectiveTheme.colorScheme.primary,
                    ),
                  )
                : Icon(
                    icon,
                    size: 34.r,
                    color: effectiveTheme.colorScheme.primary,
                  ),
            Gap(space),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.bold,
                    color: effectiveIsDark ? Colors.white : Colors.black87,
                  ),
                ),
                Gap(1.h),
                Text(
                  description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.instrumentSans(
                    fontSize: 11.sp,
                    color: effectiveIsDark
                        ? Colors.grey.shade500
                        : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
