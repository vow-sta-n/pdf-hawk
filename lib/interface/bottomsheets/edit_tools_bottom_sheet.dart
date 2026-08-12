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
import 'package:pdfhawk/data/res/utils.dart';

class EditToolsBottomSheet extends StatelessWidget {
  final ThemeData theme;
  final bool isDark;
  final VoidCallback onConvertTap;
  final VoidCallback onSplitTap;
  final VoidCallback onMergeTap;
  final VoidCallback onRearrangeTap;

  const EditToolsBottomSheet({
    super.key,
    required this.theme,
    required this.isDark,
    required this.onConvertTap,
    required this.onSplitTap,
    required this.onMergeTap,
    required this.onRearrangeTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161616) : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(8.r),
          topRight: Radius.circular(8.r),
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          uihandle(bottom: 15),
          Row(
            children: [
              Text(
                "PDF Tools & Options",
                style: GoogleFonts.outfit(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          Gap(6.h),
          Text(
            "Select an edit tool to manage and transform your PDFs",
            style: GoogleFonts.instrumentSans(
              fontSize: 13.sp,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          Gap(24.h),

          // 2x2 Grid of Edit Options
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12.w,
            mainAxisSpacing: 12.h,
            childAspectRatio: 1.05,
            children: [
              _buildTile(
                context: context,
                icon: PDFHawkIcons.file_word,
                title: "Convert",
                description: "Images or DOCX to PDF",
                onTap: onConvertTap,
              ),
              _buildTile(
                context: context,
                icon: PDFHawkIcons.split,
                title: "Split",
                description: "Divide PDF into parts",
                onTap: onSplitTap,
              ),
              _buildTile(
                context: context,
                icon: PDFHawkIcons.merge,
                title: "Merge",
                description: "Combine multiple PDFs",
                onTap: onMergeTap,
              ),
              _buildTile(
                context: context,
                icon: Icons.grid_view_rounded,
                title: "Rearrange",
                description: "Reorder & edit pages",
                onTap: onRearrangeTap,
              ),
            ],
          ),
          Gap(16.h),
        ],
      ),
    );
  }

  Widget _buildTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(7.r),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 22.r, color: theme.colorScheme.primary),
            ),
            Gap(8.h),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            Gap(2.h),
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.instrumentSans(
                fontSize: 10.5.sp,
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
