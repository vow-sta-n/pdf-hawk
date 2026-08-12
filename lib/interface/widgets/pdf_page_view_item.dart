/*
 * PDF Hawk - Modern PDF Reader, Writer, Editor & Scanner
 * Copyright (C) 2026 Van Stan / Novaturients
 *
 * This software is licensed under the PolyForm Noncommercial License 1.0.0.
 * You may obtain a copy of the License at https://polyformproject.org/licenses/noncommercial/1.0.0
 */

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdfhawk/data/res/constants.dart';
import 'package:pdfhawk/data/res/enum.dart';
import 'package:pdfhawk/interface/painters/drawing_painter.dart';
import 'package:pdfhawk/logic/helpers/pdf_helper.dart';

class PdfPageViewItem extends StatefulWidget {
  final PdfPageModel pageModel;
  final int pageIndex;
  final int currentPageIndex;
  final EditorTool activeTool;
  final Color selectedColor;
  final double strokeWidth;
  final List<Offset> currentPoints;
  final ValueChanged<List<Offset>> onDrawingStarted;
  final ValueChanged<List<Offset>> onDrawingUpdated;
  final VoidCallback onDrawingEnded;
  final Function(PdfPageModel, List<Offset>) onErase;
  final VoidCallback onLongPressAnnotation;
  final ValueChanged<bool> onZoomChanged;
  final Widget Function(PdfPageModel) buildPageBackground;

  const PdfPageViewItem({
    super.key,
    required this.pageModel,
    required this.pageIndex,
    required this.currentPageIndex,
    required this.activeTool,
    required this.selectedColor,
    required this.strokeWidth,
    required this.currentPoints,
    required this.onDrawingStarted,
    required this.onDrawingUpdated,
    required this.onDrawingEnded,
    required this.onErase,
    required this.onLongPressAnnotation,
    required this.onZoomChanged,
    required this.buildPageBackground,
  });

  @override
  State<PdfPageViewItem> createState() => _PdfPageViewItemState();
}

class _PdfPageViewItemState extends State<PdfPageViewItem> {
  @override
  Widget build(BuildContext context) {
    final pageModel = widget.pageModel;
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final pdfWidth = pageModel.width;
            final pdfHeight = pageModel.height;
            final aspectRatio = pdfWidth / pdfHeight;

            double widgetWidth, widgetHeight;
            if (constraints.maxWidth / constraints.maxHeight > aspectRatio) {
              widgetHeight = constraints.maxHeight;
              widgetWidth = constraints.maxHeight * aspectRatio;
            } else {
              widgetWidth = constraints.maxWidth;
              widgetHeight = constraints.maxWidth / aspectRatio;
            }

            final scaleX = widgetWidth / pdfWidth;
            final scaleY = widgetHeight / pdfHeight;

            return SizedBox(
              width: widgetWidth,
              height: widgetHeight,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: allradius(6),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Background page rendering
                Positioned.fill(child: widget.buildPageBackground(pageModel)),

                // Page Number Identifier (Top Left - Low Contrast Grey)
                Positioned(
                  top: 8.h,
                  left: 8.w,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 3.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade800.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(6.r),
                      border: Border.all(
                        color: Colors.grey.shade400.withValues(alpha: 0.3),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      "${widget.pageIndex + 1}",
                      style: GoogleFonts.outfit(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade300,
                      ),
                    ),
                  ),
                ),

                // Canvas paint annotations overlay
                Positioned.fill(
                  child: CustomPaint(
                    painter: DrawingPainter(
                      paths: pageModel.drawings,
                      currentPoints: widget.pageIndex == widget.currentPageIndex
                          ? widget.currentPoints
                          : [],
                      currentColor: widget.selectedColor,
                      currentStrokeWidth: widget.strokeWidth,
                      isCurrentHighlighter:
                          widget.activeTool == EditorTool.highlighter,
                      scaleX: scaleX,
                      scaleY: scaleY,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  ),
);
}
}
