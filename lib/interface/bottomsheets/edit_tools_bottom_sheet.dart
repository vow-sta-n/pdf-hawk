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
import 'package:pdfhawk/data/class/p_d_f_hawk_icons_icons.dart';
import 'package:pdfhawk/data/res/constants.dart';
import 'package:pdfhawk/data/res/theme.dart';
import 'package:pdfhawk/interface/widgets/bubble_button.dart';
import 'package:pdfhawk/interface/widgets/glass_grid_tile_button.dart';

class EditToolsBottomSheet extends StatelessWidget {
  final ThemeData theme;
  final bool isDark;
  final VoidCallback onConvertTap;
  final VoidCallback onSplitTap;
  final VoidCallback onMergeTap;
  final VoidCallback onRearrangeTap;
  final VoidCallback? onCompressTap;

  const EditToolsBottomSheet({
    super.key,
    required this.theme,
    required this.isDark,
    required this.onConvertTap,
    required this.onSplitTap,
    required this.onMergeTap,
    required this.onRearrangeTap,
    this.onCompressTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161616) : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16.r),
          topRight: Radius.circular(16.r),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Gap(15.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  BubbleButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: () => Navigator.pop(context),
                  ),
                ],
              ),
              Gap(20.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Tools & Options",
                      style: GoogleFonts.outfit(
                        height: 1,
                        fontSize: 32.sp,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Gap(6.h),
                    Text(
                      "Select an edit tool to manage and transform your PDFs",
                      style: GoogleFonts.instrumentSans(
                        fontSize: 14.sp,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Gap(26.h),

              // 2x2 Grid of Edit Options
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                padding: EdgeInsets.symmetric(horizontal: 10.w),
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12.w,
                mainAxisSpacing: 12.h,
                childAspectRatio: 1.45,
                children: [
                  GlassGridTileButton(
                    icon: PDFHawkIcons.file_word,
                    title: "Convert",
                    description: "Images or DOCX to PDF",
                    onTap: onConvertTap,
                    theme: theme,
                    isDark: isDark,
                  ),
                  GlassGridTileButton(
                    icon: PDFHawkIcons.split,
                    title: "Split",
                    description: "Divide PDF into parts",
                    onTap: onSplitTap,
                    theme: theme,
                    isDark: isDark,
                  ),
                  GlassGridTileButton(
                    icon: PDFHawkIcons.merge,
                    title: "Merge",
                    description: "Combine multiple PDFs",
                    onTap: onMergeTap,
                    theme: theme,
                    isDark: isDark,
                  ),
                  GlassGridTileButton(
                    icon: Icons.grid_view_rounded,
                    title: "Rearrange",
                    description: "Reorder & edit pages",
                    onTap: onRearrangeTap,
                    theme: theme,
                    isDark: isDark,
                  ),
                ],
              ),
              Gap(12.h),

              // Compress Option Tile Button (Vertical axis inside column)
              if (onCompressTap != null)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10.w),
                  child: GestureDetector(
                    onTap: onCompressTap,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 14.h,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.02)
                            : Colors.black.withValues(alpha: 0.02),
                        borderRadius: allradius(22.r),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.12)
                              : Colors.black.withValues(alpha: 0.12),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(10.r),
                            decoration: BoxDecoration(
                              color: royalblue.withValues(alpha: 0.15),
                              borderRadius: allradius(12.r),
                            ),
                            child: Icon(
                              Icons.compress_rounded,
                              color: royalblue,
                              size: 22.r,
                            ),
                          ),
                          Gap(14.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Compress",
                                  style: GoogleFonts.outfit(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                                Gap(2.h),
                                Text(
                                  "Reduce PDF or image file size",
                                  style: GoogleFonts.instrumentSans(
                                    fontSize: 12.5.sp,
                                    color: isDark
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 16.r,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              Gap(16.h),
            ],
          ),
        ),
      ),
    );
  }
}
