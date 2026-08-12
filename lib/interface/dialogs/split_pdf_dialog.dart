/*
 * PDF Hawk - Modern PDF Reader, Writer, Editor & Scanner
 * Copyright (C) 2026 Van Stan / Novaturients
 *
 * This software is licensed under the PolyForm Noncommercial License 1.0.0.
 * You may obtain a copy of the License at https://polyformproject.org/licenses/noncommercial/1.0.0
 */

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdfhawk/interface/pages/pdf_reader_page.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:pdfhawk/logic/helpers/pdf_helper.dart';

class SplitPdfDialog extends StatefulWidget {
  final File pdfFile;
  final String? safDirectoryUri;

  const SplitPdfDialog({
    super.key,
    required this.pdfFile,
    this.safDirectoryUri,
  });

  @override
  State<SplitPdfDialog> createState() => _SplitPdfDialogState();
}

class _SplitPdfDialogState extends State<SplitPdfDialog> {
  int _totalPages = 0;
  bool _isLoadingPages = true;
  List<Uint8List?> _thumbnails = [];

  final TextEditingController _splitCountController =
      TextEditingController(text: "2");
  int? _splitCount = 2;
  List<TextEditingController> _cutPointControllers = [];
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadPdfDetails();
  }

  @override
  void dispose() {
    _splitCountController.dispose();
    for (final c in _cutPointControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadPdfDetails() async {
    try {
      final doc = await pdfx.PdfDocument.openFile(widget.pdfFile.path);
      _totalPages = doc.pagesCount;
      _thumbnails = List.filled(_totalPages, null);

      // Render thumbnails for first few pages (up to 12)
      final renderCount = _totalPages > 12 ? 12 : _totalPages;
      for (int i = 0; i < renderCount; i++) {
        final page = await doc.getPage(i + 1);
        final rendered = await page.render(
          width: page.width * 0.4,
          height: page.height * 0.4,
          format: pdfx.PdfPageImageFormat.png,
        );
        await page.close();
        if (rendered != null) {
          _thumbnails[i] = rendered.bytes;
        }
      }
      await doc.close();

      _updateCutPointControllers();

      setState(() {
        _isLoadingPages = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingPages = false;
      });
    }
  }

  void _onSplitCountChanged(String val) {
    final count = int.tryParse(val.trim());
    setState(() {
      _splitCount = count;
      _updateCutPointControllers();
    });
  }

  void _updateCutPointControllers() {
    if (_totalPages <= 0) return;
    final n = _splitCount ?? 0;
    final isCustomCut = n > 1 && n <= _totalPages && n <= (_totalPages * 0.7);

    if (isCustomCut) {
      final requiredCutCount = n - 1;
      for (final c in _cutPointControllers) {
        c.dispose();
      }
      _cutPointControllers = [];

      final double avgPagesPerPart = _totalPages / n;
      for (int i = 0; i < requiredCutCount; i++) {
        final defaultCutPoint = ((i + 1) * avgPagesPerPart).floor();
        _cutPointControllers.add(
          TextEditingController(text: defaultCutPoint.toString()),
        );
      }
    }
  }

  List<List<int>> _calculateRanges() {
    final n = _splitCount ?? 1;
    if (n <= 1 || _totalPages <= 1) {
      return [
        [1, _totalPages],
      ];
    }

    final isCustomCut = n <= (_totalPages * 0.7);

    if (isCustomCut && _cutPointControllers.length == n - 1) {
      final List<int> cutPoints = [];
      for (final c in _cutPointControllers) {
        final val = int.tryParse(c.text.trim()) ?? 1;
        cutPoints.add(val);
      }

      final List<List<int>> ranges = [];
      int currentStart = 1;

      for (int i = 0; i < cutPoints.length; i++) {
        int cut = cutPoints[i];
        if (cut < currentStart) cut = currentStart;
        if (cut >= _totalPages) cut = _totalPages - 1;

        ranges.add([currentStart, cut]);
        currentStart = cut + 1;
      }

      if (currentStart <= _totalPages) {
        ranges.add([currentStart, _totalPages]);
      }

      return ranges;
    } else {
      // Equal split mode when N > 70% of pageCount
      final List<List<int>> ranges = [];
      final double perPart = _totalPages / n;

      int currentStart = 1;
      for (int i = 0; i < n; i++) {
        int end = ((i + 1) * perPart).round();
        if (i == n - 1 || end > _totalPages) {
          end = _totalPages;
        }
        if (currentStart <= _totalPages) {
          ranges.add([currentStart, end]);
          currentStart = end + 1;
        }
      }
      return ranges;
    }
  }

  Future<void> _executeSplit() async {
    final ranges = _calculateRanges();
    if (ranges.isEmpty) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final splitFiles = await PdfHelper.splitPdf(
        pdfFile: widget.pdfFile,
        ranges: ranges,
        safDirectoryUri: widget.safDirectoryUri,
      );

      if (!mounted) return;
      Navigator.pop(context, splitFiles);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Successfully split document into ${splitFiles.length} files!",
          ),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: "Open First",
            textColor: Colors.white,
            onPressed: () {
              if (splitFiles.isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PDFReaderPage(
                      pdfFile: splitFiles.first,
                    ),
                  ),
                );
              }
            },
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to split PDF: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fileName = widget.pdfFile.path.split('/').last;

    final n = _splitCount ?? 0;
    final isCustomCut = n > 1 && n <= _totalPages && n <= (_totalPages * 0.7);
    final rangesPreview = _calculateRanges();

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24.r),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(20.r),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Title & Info
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10.r),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.call_split_rounded,
                    color: theme.colorScheme.primary,
                    size: 24.r,
                  ),
                ),
                Gap(12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Split PDF",
                        style: GoogleFonts.outfit(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        "$fileName • $_totalPages Pages",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.instrumentSans(
                          fontSize: 12.sp,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Gap(16.h),

            // Page Thumbnail Strip (similar to Go To Page dialog)
            if (_isLoadingPages)
              SizedBox(
                height: 90.h,
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else
              SizedBox(
                height: 100.h,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _totalPages,
                  separatorBuilder: (context, index) => Gap(8.w),
                  itemBuilder: (context, index) {
                    final thumbBytes = _thumbnails[index];
                    return Container(
                      width: 70.w,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.grey.shade900
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(
                          color: isDark ? Colors.white12 : Colors.black12,
                        ),
                      ),
                      child: Stack(
                        children: [
                          if (thumbBytes != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8.r),
                              child: Image.memory(
                                thumbBytes,
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            )
                          else
                            Center(
                              child: Icon(
                                Icons.article_outlined,
                                color: isDark
                                    ? Colors.white38
                                    : Colors.black38,
                                size: 24.r,
                              ),
                            ),
                          Positioned(
                            bottom: 4.h,
                            left: 4.w,
                            right: 4.w,
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 2.h),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(4.r),
                              ),
                              child: Text(
                                "p. ${index + 1}",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            Gap(16.h),

            // Split Count Input Textbox
            Text(
              "Number of parts to split into:",
              style: GoogleFonts.outfit(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            Gap(6.h),
            TextField(
              controller: _splitCountController,
              keyboardType: TextInputType.number,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              onChanged: _onSplitCountChanged,
              decoration: InputDecoration(
                hintText: "Enter number of parts (e.g. 3)",
                hintStyle: TextStyle(
                  color: isDark ? Colors.white38 : Colors.black38,
                  fontSize: 13.sp,
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 14.w,
                  vertical: 12.h,
                ),
                filled: true,
                fillColor: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            Gap(16.h),

            // Cut Points Input Textboxes if N <= 70% of Page Count
            if (isCustomCut && _cutPointControllers.isNotEmpty) ...[
              Container(
                padding: EdgeInsets.all(12.r),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.content_cut_rounded,
                          size: 16.r,
                          color: theme.colorScheme.primary,
                        ),
                        Gap(6.w),
                        Text(
                          "Custom Cut Points (Part Boundaries)",
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    Gap(8.h),
                    ...List.generate(_cutPointControllers.length, (idx) {
                      return Padding(
                        padding: EdgeInsets.only(bottom: 8.h),
                        child: Row(
                          children: [
                            Text(
                              "Part ${idx + 1} ends at page:",
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: isDark
                                    ? Colors.white70
                                    : Colors.black87,
                              ),
                            ),
                            Gap(12.w),
                            SizedBox(
                              width: 60.w,
                              height: 38.h,
                              child: TextField(
                                controller: _cutPointControllers[idx],
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white
                                      : Colors.black87,
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  contentPadding: EdgeInsets.zero,
                                  filled: true,
                                  fillColor: isDark
                                      ? Colors.black26
                                      : Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(8.r),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
              Gap(16.h),
            ],

            // Resulting Ranges Summary Badge
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(10.r),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Resulting Parts Summary:",
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  Gap(4.h),
                  Wrap(
                    spacing: 6.w,
                    runSpacing: 4.h,
                    children: List.generate(rangesPreview.length, (idx) {
                      final r = rangesPreview[idx];
                      return Chip(
                        visualDensity: VisualDensity.compact,
                        backgroundColor: isDark
                            ? Colors.grey.shade800
                            : Colors.white,
                        label: Text(
                          "Part ${idx + 1}: p.${r[0]}-${r[1]}",
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
            Gap(20.h),

            // Actions (Cancel / Split PDF)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    "Cancel",
                    style: TextStyle(
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ),
                Gap(12.w),
                ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _executeSplit,
                  icon: _isProcessing
                      ? SizedBox(
                          width: 16.r,
                          height: 16.r,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.content_cut_rounded, color: Colors.white),
                  label: Text(
                    _isProcessing ? "Splitting..." : "Split PDF",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14.sp,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    padding: EdgeInsets.symmetric(
                      horizontal: 18.w,
                      vertical: 12.h,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
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
