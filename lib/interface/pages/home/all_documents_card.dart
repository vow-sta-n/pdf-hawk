/*
 * PDF Hawk - Modern PDF Reader, Writer, Editor & Scanner
 * Copyright (C) 2026 Van Stan / Novaturients
 *
 * This software is licensed under the PolyForm Noncommercial License 1.0.0.
 * You may obtain a copy of the License at https://polyformproject.org/licenses/noncommercial/1.0.0
 */

import 'package:community_material_icon/community_material_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdfhawk/data/models/device_document_model.dart';
import 'package:pdfhawk/data/res/enum.dart';
import 'package:pdfhawk/data/res/theme.dart';
import 'package:pdfhawk/data/res/utils.dart';
import 'package:pdfhawk/interface/pages/home/all_documents_page.dart';
import 'package:pdfhawk/logic/services/device_documents_service.dart';
import 'package:primer_progress_bar/primer_progress_bar.dart';

class AllDocumentsCard extends StatefulWidget {
  final bool? isDark;
  final ThemeData? theme;

  const AllDocumentsCard({super.key, this.isDark, this.theme});

  @override
  State<AllDocumentsCard> createState() => _AllDocumentsCardState();
}

class _AllDocumentsCardState extends State<AllDocumentsCard> {
  @override
  void initState() {
    super.initState();
    DeviceDocumentsService.scanDeviceDocuments();
  }

  String _formatStorageBytes(int bytes) {
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) {
      return "${(bytes / 1024).toStringAsFixed(1)} KB";
    }
    if (bytes < 1024 * 1024 * 1024) {
      return "${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB";
    }
    return "${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB";
  }

  Color _getDocumentCategoryColor(DocumentCategory category, ThemeData theme) {
    switch (category) {
      case DocumentCategory.pdf:
        return theme.primaryColor;
      case DocumentCategory.word:
        return const Color(0xFF1E88E5);
      case DocumentCategory.excel:
        return const Color(0xFF00C853);
      case DocumentCategory.ppt:
        return const Color(0xFFFF9100);
      case DocumentCategory.text:
        return const Color(0xFFFFEA00);
      case DocumentCategory.hawk:
        return black;
      case DocumentCategory.image:
      case DocumentCategory.other:
      default:
        return grey;
    }
  }

  String _getDocumentCategoryName(DocumentCategory category) {
    switch (category) {
      case DocumentCategory.pdf:
        return "PDF";
      case DocumentCategory.word:
        return "Word";
      case DocumentCategory.excel:
        return "Excel";
      case DocumentCategory.ppt:
        return "PPT";
      case DocumentCategory.text:
        return "Text";
      case DocumentCategory.hawk:
        return "Hawk";
      case DocumentCategory.image:
      case DocumentCategory.other:
      default:
        return "Other";
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme ?? Theme.of(context);
    final isDark = widget.isDark ?? (theme.brightness == Brightness.dark);
    final double w = getWidth(context);

    return ValueListenableBuilder<List<DeviceDocumentModel>>(
      valueListenable: DeviceDocumentsService.documentsNotifier,
      builder: (context, docs, _) {
        final count = docs.length;
        final int totalBytes = docs.fold<int>(0, (sum, d) => sum + d.size);

        final Map<DocumentCategory, int> categorySizes = {};
        for (final doc in docs) {
          categorySizes[doc.category] =
              (categorySizes[doc.category] ?? 0) + doc.size;
        }

        final trackedDefs = [
          (
            category: DocumentCategory.pdf,
            name: _getDocumentCategoryName(DocumentCategory.pdf),
            color: _getDocumentCategoryColor(DocumentCategory.pdf, theme),
            size: categorySizes[DocumentCategory.pdf] ?? 0,
          ),
          (
            category: DocumentCategory.word,
            name: _getDocumentCategoryName(DocumentCategory.word),
            color: _getDocumentCategoryColor(DocumentCategory.word, theme),
            size: categorySizes[DocumentCategory.word] ?? 0,
          ),
          (
            category: DocumentCategory.excel,
            name: _getDocumentCategoryName(DocumentCategory.excel),
            color: _getDocumentCategoryColor(DocumentCategory.excel, theme),
            size: categorySizes[DocumentCategory.excel] ?? 0,
          ),
          (
            category: DocumentCategory.ppt,
            name: _getDocumentCategoryName(DocumentCategory.ppt),
            color: _getDocumentCategoryColor(DocumentCategory.ppt, theme),
            size: categorySizes[DocumentCategory.ppt] ?? 0,
          ),
        ];

        int otherBytes = 0;
        for (final entry in categorySizes.entries) {
          if (!trackedDefs.any((t) => t.category == entry.key)) {
            otherBytes += entry.value;
          }
        }

        List<Segment> segments = [];
        if (totalBytes == 0) {
          segments = [
            Segment(
              value: 1,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.25)
                  : Colors.black.withValues(alpha: 0.15),
              label: Text(
                "No files",
                style: GoogleFonts.instrumentSans(
                  fontSize: 11.5.sp,
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                ),
              ),
              valueLabel: Text(
                "0%",
                style: GoogleFonts.instrumentSans(
                  fontSize: 11.sp,
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                ),
              ),
            ),
          ];
        } else {
          final activeTracked = trackedDefs.where((t) => t.size > 0).toList()
            ..sort((a, b) => b.size.compareTo(a.size));

          for (final item in activeTracked) {
            final double pct = (item.size / totalBytes) * 100;
            final String pctStr = pct < 1
                ? "<1%"
                : "${pct.toStringAsFixed(0)}%";
            segments.add(
              Segment(
                value: (item.size / 1024).round().clamp(1, 1000000000),
                color: item.color,
                label: Text(
                  item.name,
                  style: GoogleFonts.instrumentSans(
                    fontSize: 11.5.sp,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                valueLabel: Text(
                  "${_formatStorageBytes(item.size)} ($pctStr)",
                  style: GoogleFonts.instrumentSans(
                    fontSize: 11.sp,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ),
            );
          }

          if (otherBytes > 0) {
            final double pct = (otherBytes / totalBytes) * 100;
            final String pctStr = pct < 1
                ? "<1%"
                : "${pct.toStringAsFixed(0)}%";
            segments.add(
              Segment(
                value: (otherBytes / 1024).round().clamp(1, 1000000000),
                color: const Color(0xFF9E9E9E),
                label: Text(
                  "Other",
                  style: GoogleFonts.instrumentSans(
                    fontSize: 11.5.sp,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                valueLabel: Text(
                  "${_formatStorageBytes(otherBytes)} ($pctStr)",
                  style: GoogleFonts.instrumentSans(
                    fontSize: 11.sp,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ),
            );
          }
        }

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AllDocumentsPage()),
            );
          },
          child: Container(
            width: w,
            padding: EdgeInsets.all(16.r),
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Container(
                          padding: EdgeInsets.all(10.r),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.12,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            CommunityMaterialIcons.chart_arc,
                            size: 18.r,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        Gap(15),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "Storage",
                                    style: GoogleFonts.instrumentSans(
                                      height: 1,
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    color: isDark
                                        ? Colors.white38
                                        : Colors.black38,
                                    size: 14.r,
                                  ),
                                ],
                              ),

                              Text(
                                _formatStorageBytes(totalBytes),
                                style: GoogleFonts.instrumentSans(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Gap(10.h),
                    PrimerProgressBar(
                      segments: segments,
                      barStyle: SegmentedBarStyle(
                        size: 8.h,
                        gap: 2.w,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                        backgroundColor: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.06),
                        padding: EdgeInsets.symmetric(vertical: 4.h),
                      ),
                      legendStyle: SegmentedBarLegendStyle(
                        spacing: 12.w,
                        runSpacing: 4.h,
                        padding: EdgeInsets.only(top: 4.h),
                      ),
                    ),
                  ],
                ),
                Gap(12.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "$count ${count == 1 ? 'doc' : 'docs'}",
                      style: GoogleFonts.instrumentSans(
                        fontSize: 12.sp,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 14.w,
                        vertical: 6.h,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.12)
                              : Colors.black.withValues(alpha: 0.12),
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          "Open PDF",
                          style: GoogleFonts.instrumentSans(
                            fontSize: 11.5.sp,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
