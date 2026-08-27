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
import 'package:file_picker/file_picker.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdfhawk/data/res/constants.dart';
import 'package:pdfhawk/data/res/theme.dart';
import 'package:pdfhawk/interface/pages/pdf_reader_page.dart';
import 'package:pdfhawk/logic/helpers/pdf_helper.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:flutter_reorderable_grid_view/widgets/widgets.dart';
import 'package:pdfhawk/interface/widgets/tutorial_card_widget.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

class MergePdfsPage extends StatefulWidget {
  final List<File> initialPdfFiles;
  final String? safDirectoryUri;

  const MergePdfsPage({
    super.key,
    required this.initialPdfFiles,
    this.safDirectoryUri,
  });

  @override
  State<MergePdfsPage> createState() => _MergePdfsPageState();
}

class _MergePdfsPageState extends State<MergePdfsPage> {
  late List<File> _files;
  final Map<String, int> _pageCounts = {};
  final Map<String, Uint8List?> _thumbnails = {};
  bool _isMerging = false;

  final GlobalKey _keyHelp = GlobalKey();
  final GlobalKey _keyReorderList = GlobalKey();
  final GlobalKey _keyAddMore = GlobalKey();
  final GlobalKey _keyMergeBtn = GlobalKey();

  @override
  void initState() {
    super.initState();
    _files = List<File>.from(widget.initialPdfFiles);
    _loadMetadata();
  }

  Future<void> _loadMetadata() async {
    for (final file in _files) {
      if (!_pageCounts.containsKey(file.path)) {
        try {
          final doc = await pdfx.PdfDocument.openFile(file.path);
          _pageCounts[file.path] = doc.pagesCount;
          if (doc.pagesCount > 0) {
            final page = await doc.getPage(1);
            final rendered = await page.render(
              width: page.width * 0.4,
              height: page.height * 0.4,
              format: pdfx.PdfPageImageFormat.png,
            );
            await page.close();
            if (rendered != null) {
              _thumbnails[file.path] = rendered.bytes;
            }
          }
          await doc.close();
        } catch (_) {
          _pageCounts[file.path] = 0;
        }
      }
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _pickMorePdfs() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: true,
    );

    if (result != null && result.paths.isNotEmpty) {
      final newFiles = result.paths
          .whereType<String>()
          .map((p) => File(p))
          .where((f) => !_files.any((existing) => existing.path == f.path))
          .toList();

      setState(() {
        _files.addAll(newFiles);
      });
      _loadMetadata();
    }
  }

  Future<void> _insertPdfsAt(int targetIndex) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: true,
    );

    if (result != null && result.paths.isNotEmpty) {
      final newFiles = result.paths
          .whereType<String>()
          .map((p) => File(p))
          .where((f) => !_files.any((existing) => existing.path == f.path))
          .toList();

      if (newFiles.isNotEmpty) {
        setState(() {
          final clampedIndex = targetIndex.clamp(0, _files.length);
          _files.insertAll(clampedIndex, newFiles);
        });
        _loadMetadata();
      }
    }
  }

  void _showFileOptionsMenu(int index) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final file = _files[index];
    final fileName = file.path.split('/').last;

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black26,
                      borderRadius: allradius(2.r),
                    ),
                  ),
                ),
                SizedBox(height: 12.h),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 6.h, horizontal: 4.w),
                  child: Row(
                    children: [
                      Icon(
                        Icons.picture_as_pdf_rounded,
                        color: theme.colorScheme.primary,
                        size: 20.r,
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 16),
                ListTile(
                  leading: const Icon(
                    Icons.arrow_upward_rounded,
                    color: Colors.blueAccent,
                  ),
                  title: Text(
                    "Add PDF previous to this",
                    style: GoogleFonts.instrumentSans(
                      fontWeight: FontWeight.w600,
                      fontSize: 14.sp,
                    ),
                  ),
                  subtitle: Text(
                    "Insert before #${index + 1}",
                    style: GoogleFonts.instrumentSans(
                      fontSize: 12.sp,
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _insertPdfsAt(index);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.arrow_downward_rounded,
                    color: Colors.tealAccent,
                  ),
                  title: Text(
                    "Add PDF next to this",
                    style: GoogleFonts.instrumentSans(
                      fontWeight: FontWeight.w600,
                      fontSize: 14.sp,
                    ),
                  ),
                  subtitle: Text(
                    "Insert after #${index + 1}",
                    style: GoogleFonts.instrumentSans(
                      fontSize: 12.sp,
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _insertPdfsAt(index + 1);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: red),
                  title: Text(
                    "Delete this PDF",
                    style: GoogleFonts.instrumentSans(
                      fontWeight: FontWeight.w600,
                      fontSize: 14.sp,
                      color: red,
                    ),
                  ),
                  subtitle: Text(
                    "Remove from merge sequence",
                    style: GoogleFonts.instrumentSans(
                      fontSize: 12.sp,
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _files.removeAt(index);
                    });
                  },
                ),
                SizedBox(height: 8.h),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _executeMerge() async {
    if (_files.length < 2) {
      await _pickMorePdfs();
      return;
    }

    setState(() {
      _isMerging = true;
    });

    try {
      final mergedFile = await PdfHelper.mergePdfs(
        pdfFiles: _files,
        safDirectoryUri: widget.safDirectoryUri,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("PDFs Merged Successfully!"),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => PDFReaderPage(
            pdfFile: mergedFile,
            safDirectoryUri: widget.safDirectoryUri,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to merge PDFs: $e")));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isMerging = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        iconTheme: IconThemeData(color: theme.appBarTheme.foregroundColor),
        title: Text(
          "Merge PDFs",
          style: GoogleFonts.outfit(
            color: theme.appBarTheme.foregroundColor,
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            key: _keyHelp,
            icon: Icon(Icons.help_outline_outlined, size: 22.sp),
            tooltip: "Help Guide",
            onPressed: _showTutorial,
          ),
          SizedBox(width: 8.w),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Header description banner
              Container(
                width: double.infinity,
                margin: EdgeInsets.all(8),
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF161616) : Colors.white,
                  borderRadius: allradius(8),
                ),

                child: Row(
                  children: [
                    Icon(
                      _files.length < 2
                          ? Icons.info_outline_rounded
                          : Icons.drag_indicator_rounded,
                      size: 20.r,
                      color: _files.length < 2
                          ? Colors.orangeAccent
                          : theme.colorScheme.primary,
                    ),
                    Gap(8.w),
                    Expanded(
                      child: Text(
                        _files.isEmpty
                            ? "No PDFs selected • Tap 'Add More' to pick files"
                            : _files.length == 1
                            ? "1 PDF selected • Add at least 1 more PDF to merge"
                            : "${_files.length} PDFs selected • Drag cards to reorder merge sequence",
                        style: GoogleFonts.instrumentSans(
                          fontSize: 12.sp,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Reorderable List of Selected PDF Files or Empty State
              Expanded(
                child: _files.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.picture_as_pdf_rounded,
                              size: 48.r,
                              color: Colors.grey,
                            ),
                            Gap(12.h),
                            Text(
                              "No PDFs Selected",
                              style: GoogleFonts.outfit(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                            Gap(6.h),
                            Text(
                              "Pick 2 or more PDF files to merge them together.",
                              style: GoogleFonts.instrumentSans(
                                fontSize: 13.sp,
                                color: Colors.grey,
                              ),
                            ),
                            Gap(16.h),
                            ElevatedButton.icon(
                              onPressed: _pickMorePdfs,
                              icon: const Icon(Icons.add_rounded),
                              label: const Text("Select PDFs"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: allradius(12.r),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Container(
                        key: _keyReorderList,
                        child: ReorderableBuilder<File>(
                          children: _files.map((file) {
                            final index = _files.indexOf(file);
                            final fileName = file.path.split('/').last;
                            final pageCount = _pageCounts[file.path];
                            final thumb = _thumbnails[file.path];
                            final fileSizeMb =
                                (file.lengthSync() / (1024 * 1024))
                                    .toStringAsFixed(1);

                            return Card(
                              key: ValueKey(file.path),
                              elevation: 2,
                              margin: EdgeInsets.only(bottom: 12.h),
                              color: isDark
                                  ? const Color(0xFF1E1E1E)
                                  : Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: allradius(8.r),
                                side: BorderSide(
                                  color: isDark
                                      ? Colors.white10
                                      : Colors.black12,
                                ),
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(12.r),
                                child: Row(
                                  children: [
                                    Gap(12.w),
                                    // Sequence Number Avatar Badge
                                    Text(
                                      "${index + 1}",
                                      style: GoogleFonts.lato(
                                        color: Colors.white,
                                        height: 1,
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Gap(22.w),

                                    // PDF Thumbnail
                                    Container(
                                      width: 40.w,
                                      height: 55.h,
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.grey.shade900
                                            : Colors.grey.shade200,
                                        borderRadius: allradius(
                                          8.r,
                                        ),
                                      ),
                                      child: thumb != null
                                          ? ClipRRect(
                                              borderRadius:
                                                  allradius(8.r),
                                              child: Image.memory(
                                                thumb,
                                                fit: BoxFit.cover,
                                              ),
                                            )
                                          : Center(
                                              child: Icon(
                                                Icons.picture_as_pdf_rounded,
                                                color:
                                                    theme.colorScheme.primary,
                                                size: 24.r,
                                              ),
                                            ),
                                    ),
                                    Gap(12.w),

                                    // File Name & Details
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            fileName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.outfit(
                                              fontSize: 14.sp,
                                              fontWeight: FontWeight.bold,
                                              color: isDark
                                                  ? Colors.white
                                                  : Colors.black87,
                                            ),
                                          ),
                                          Gap(4.h),
                                          Text(
                                            pageCount != null
                                                ? "$pageCount Pages • $fileSizeMb MB"
                                                : "$fileSizeMb MB",
                                            style: GoogleFonts.instrumentSans(
                                              fontSize: 11.sp,
                                              color: isDark
                                                  ? Colors.grey.shade400
                                                  : Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // More Options Action Button
                                    IconButton(
                                      icon: Icon(
                                        Icons.more_vert_rounded,
                                        color: isDark
                                            ? Colors.white70
                                            : Colors.black54,
                                      ),
                                      onPressed: () =>
                                          _showFileOptionsMenu(index),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                          onReorder:
                              (
                                ReorderedListFunction<File>
                                reorderedListFunction,
                              ) {
                                setState(() {
                                  final updatedFiles = reorderedListFunction(
                                    _files,
                                  );
                                  _files.clear();
                                  _files.addAll(updatedFiles);
                                });
                              },
                          builder: (children) {
                            return ListView(
                              padding: EdgeInsets.symmetric(
                                horizontal: 16.w,
                                vertical: 12.h,
                              ),
                              children: [
                                ...children,
                                // Inline "Add Another PDF" button card
                                InkWell(
                                  key: _keyAddMore,
                                  onTap: _pickMorePdfs,
                                  borderRadius: allradius(16.r),
                                  child: Container(
                                    width: double.infinity,
                                    padding: EdgeInsets.symmetric(
                                      vertical: 16.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.04)
                                          : Colors.black.withValues(
                                              alpha: 0.03,
                                            ),
                                      borderRadius: allradius(6.r),
                                      border: Border.all(
                                        color: isDark
                                            ? Colors.white60
                                            : Colors.black26,
                                        style: BorderStyle.solid,
                                        width: 1.2,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.add_circle_outline_rounded,
                                          size: 20.r,
                                          color: isDark
                                              ? Colors.white60
                                              : Colors.black26,
                                        ),
                                        Gap(8.w),
                                        Text(
                                          "Add Another PDF",
                                          style: GoogleFonts.outfit(
                                            color: isDark
                                                ? Colors.white60
                                                : Colors.black26,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14.sp,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Gap(16.h),
                              ],
                            );
                          },
                        ),
                      ),
              ),
              // Bottom Bar with "Merge PDFs" Action Button
              Container(
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF161616) : Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 52.h,
                  child: ElevatedButton.icon(
                    key: _keyMergeBtn,
                    onPressed: _isMerging
                        ? null
                        : (_files.length < 2 ? _pickMorePdfs : _executeMerge),
                    icon: Icon(
                      _files.length < 2
                          ? Icons.add_rounded
                          : Icons.merge_type_rounded,
                      color: Colors.white,
                    ),
                    label: Text(
                      _files.length < 2
                          ? "Add Another PDF to Merge"
                          : "Merge ${_files.length} PDFs",
                      style: GoogleFonts.outfit(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: allradius(6.r),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Loading Spinner Overlay
          if (_isMerging)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  // --- TUTORIAL COACH MARK ---
  void _showTutorial() {
    showAppTutorial(
      context: context,
      steps: [
        TutorialStep(
          identify: "reorder_and_options",
          keyTarget: _keyReorderList,
          shape: ShapeLightFocus.RRect,
          radius: 12.r,
          align: ContentAlign.bottom,
          title: "Reorder & File Options",
          description:
              "Long-press and drag any PDF card up or down to reorder the sequence. Tap more options (⋮) on any card to insert files previous/next to it or delete.",
          icon: Icons.drag_indicator_rounded,
        ),
        TutorialStep(
          identify: "add_more",
          keyTarget: _keyAddMore,
          shape: ShapeLightFocus.RRect,
          radius: 10.r,
          align: ContentAlign.top,
          title: "Add More PDF Files",
          description:
              "Pick and append additional PDF files from your device storage to merge them all together.",
          icon: Icons.add_circle_outline_rounded,
        ),
        TutorialStep(
          identify: "merge",
          keyTarget: _keyMergeBtn,
          shape: ShapeLightFocus.RRect,
          radius: 16.r,
          align: ContentAlign.top,
          title: "Merge & Save PDFs",
          description:
              "Combine all selected PDF files into a single unified PDF document and save it directly to your PDFHawk folder.",
          icon: Icons.merge_type_rounded,
        ),
      ],
    );
  }
}
