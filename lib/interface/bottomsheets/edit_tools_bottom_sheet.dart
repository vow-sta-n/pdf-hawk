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
import 'package:pdfhawk/interface/widgets/bubble_button.dart';
import 'package:pdfhawk/interface/widgets/glass_grid_tile_button.dart';

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
    double h = getHeight(context);
    return Container(
      height: h / 1.5,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161616) : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(8.r),
          topRight: Radius.circular(8.r),
        ),
      ),

      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Gap(20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              BubbleButton(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
          Gap(15),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Tools & Options",
                  style: GoogleFonts.outfit(
                    height: 1,
                    fontSize: 37.sp,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Gap(5),
                Text(
                  "Select an edit tool to manage and transform your PDFs",
                  style: GoogleFonts.instrumentSans(
                    fontSize: 16.sp,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Gap(30),

          // 2x2 Grid of Edit Options
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            padding: EdgeInsets.all(10),
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12.w,
            mainAxisSpacing: 12.h,
            childAspectRatio: 1.4,
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
          Gap(30),
        ],
      ),
    );
  }
}
