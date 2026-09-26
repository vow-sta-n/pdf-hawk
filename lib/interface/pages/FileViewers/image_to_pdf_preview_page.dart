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
import 'package:fluttertoast/fluttertoast.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdfhawk/data/res/theme.dart';
import 'package:pdfhawk/data/res/utils.dart';
import 'package:pdfhawk/interface/globals/pdf_page_renderer.dart';
import 'package:pdfhawk/logic/helpers/image_to_pdf_helper.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:share_plus/share_plus.dart';

/// Realtime PDF Preview Page: Compiles selected photos into a live PDF document
/// and renders pages in high fidelity with paper styling, pinch-to-zoom, and instant export.
class ImageToPdfPreviewPage extends StatefulWidget {
  final List<String> orderedImagePaths;
  final void Function(List<String> paths)? onSavePdf;

  const ImageToPdfPreviewPage({
    super.key,
    required this.orderedImagePaths,
    this.onSavePdf,
  });

  @override
  State<ImageToPdfPreviewPage> createState() => _ImageToPdfPreviewPageState();
}

class _ImageToPdfPreviewPageState extends State<ImageToPdfPreviewPage> {
  late List<String> _paths;
  File? _compiledPdfFile;
  int _totalPages = 0;
  bool _isCompiling = true;
  String? _compileError;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _paths = List.from(widget.orderedImagePaths);
    _compilePdf();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    if (_compiledPdfFile != null) {
      PdfPageImageRenderer.closeDocument(_compiledPdfFile!.path);
    }
    super.dispose();
  }

  // --- REALTIME PDF COMPILATION ---

  Future<void> _compilePdf() async {
    if (_paths.isEmpty) {
      setState(() {
        _compiledPdfFile = null;
        _totalPages = 0;
        _isCompiling = false;
        _compileError = null;
      });
      return;
    }

    setState(() {
      _isCompiling = true;
      _compileError = null;
    });

    try {
      final previewFile = await ImageToPdfHelper.compileImagesToTempPdf(
        _paths,
        quality: 92,
      );

      // Open rendered document to get page count
      final doc = await pdfx.PdfDocument.openFile(previewFile.path);
      final count = doc.pagesCount;
      await doc.close();

      if (mounted) {
        setState(() {
          _compiledPdfFile = previewFile;
          _totalPages = count;
          _isCompiling = false;
        });
      }
    } catch (e) {
      debugPrint("Error compiling realtime PDF preview: $e");
      if (mounted) {
        setState(() {
          _isCompiling = false;
          _compileError = e.toString();
        });
        Fluttertoast.showToast(msg: "Error compiling preview: $e");
      }
    }
  }

  // --- ACTIONS: EXPORT & SHARE ---

  Future<void> _exportPdf() async {
    if (_paths.isEmpty) {
      Fluttertoast.showToast(msg: "No pages to export");
      return;
    }

    final savedPdf = await ImageToPdfHelper.exportImagesToPdfDialog(
      context,
      imagePaths: _paths,
      openReaderOnSuccess: true,
    );

    if (savedPdf != null && mounted) {
      widget.onSavePdf?.call(_paths);
    }
  }

  void _sharePreviewPdf() {
    if (_compiledPdfFile == null || !_compiledPdfFile!.existsSync()) {
      Fluttertoast.showToast(msg: "PDF preview is still generating");
      return;
    }

    SharePlus.instance.share(
      ShareParams(
        files: [XFile(_compiledPdfFile!.path)],
        text: "Document_${_paths.length}Pages.pdf",
      ),
    );
  }

  void _deletePage(int index) {
    if (index >= 0 && index < _paths.length) {
      setState(() {
        _paths.removeAt(index);
      });
      _compilePdf();
      Fluttertoast.showToast(msg: "Page removed from PDF");
    }
  }

  // --- BUILD UI ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.pop(context, _paths);
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF101014) : const Color(0xFFE5E7EB),
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  // Top Navigation Bar
                  _buildTopBar(isDark, theme),

                  // Realtime PDF Viewport
                  Expanded(
                    child: _isCompiling
                        ? _buildCompilingState(isDark)
                        : _compileError != null
                            ? _buildErrorState(isDark)
                            : _paths.isEmpty
                                ? _buildEmptyState(isDark)
                                : _buildPdfPagesViewer(isDark, theme),
                  ),

                  // Bottom Docked Export Bar
                  _buildBottomExportBar(isDark, theme),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(bool isDark, ThemeData theme) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141418) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white10 : Colors.black12,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Back Button
          InkWell(
            onTap: () => Navigator.pop(context, _paths),
            borderRadius: allradius(20.r),
            child: Container(
              width: 38.r,
              height: 38.r,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 18.sp,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ),
          Gap(12.w),

          // Title & Status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      "PDF Preview",
                      style: GoogleFonts.outfit(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Gap(8.w),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 2.h,
                      ),
                      decoration: BoxDecoration(
                        color: royalblue.withValues(alpha: 0.15),
                        borderRadius: allradius(10.r),
                        border: Border.all(
                          color: royalblue.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        "Realtime",
                        style: GoogleFonts.outfit(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.bold,
                          color: royalblue,
                        ),
                      ),
                    ),
                  ],
                ),
                Gap(2.h),
                Text(
                  _paths.isEmpty
                      ? "No pages"
                      : "${_paths.length} page${_paths.length > 1 ? 's' : ''} • Exact render",
                  style: GoogleFonts.instrumentSans(
                    fontSize: 12.sp,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),

          // Share Button
          if (_compiledPdfFile != null)
            IconButton(
              icon: Icon(
                Icons.share_rounded,
                size: 20.sp,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
              tooltip: "Share PDF Preview",
              onPressed: _sharePreviewPdf,
            ),
        ],
      ),
    );
  }

  Widget _buildCompilingState(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(20.r),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E24) : Colors.white,
              borderRadius: allradius(20.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const CircularProgressIndicator(color: royalblue),
          ),
          Gap(18.h),
          Text(
            "Compiling Realtime PDF...",
            style: GoogleFonts.outfit(
              fontSize: 17.sp,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          Gap(4.h),
          Text(
            "Rendering true document canvas and margins",
            style: GoogleFonts.instrumentSans(
              fontSize: 13.sp,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(bool isDark) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.r),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 48.r, color: Colors.redAccent),
            Gap(12.h),
            Text(
              "Compilation Failed",
              style: GoogleFonts.outfit(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            Gap(6.h),
            Text(
              _compileError ?? "An error occurred while compiling the PDF",
              textAlign: TextAlign.center,
              style: GoogleFonts.instrumentSans(
                fontSize: 13.sp,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            Gap(16.h),
            ElevatedButton(
              onPressed: _compilePdf,
              style: ElevatedButton.styleFrom(
                backgroundColor: royalblue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: allradius(12.r)),
              ),
              child: const Text("Retry Compilation"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.picture_as_pdf_outlined,
            size: 52.r,
            color: isDark ? Colors.white24 : Colors.black26,
          ),
          Gap(12.h),
          Text(
            "No Pages in Document",
            style: GoogleFonts.outfit(
              fontSize: 17.sp,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          Gap(4.h),
          Text(
            "Return to select photos for your PDF",
            style: GoogleFonts.instrumentSans(
              fontSize: 13.sp,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPdfPagesViewer(bool isDark, ThemeData theme) {
    if (_compiledPdfFile == null || _totalPages == 0) {
      return const SizedBox.shrink();
    }

    return InteractiveViewer(
      minScale: 0.6,
      maxScale: 3.5,
      boundaryMargin: EdgeInsets.all(20.r),
      child: ListView.builder(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 18.h),
        itemCount: _totalPages,
        itemBuilder: (context, index) {
          final pageNumber = index + 1;

          return Container(
            margin: EdgeInsets.only(bottom: 24.h),
            child: Column(
              children: [
                // Real PDF Page Sheet
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.6 : 0.22,
                        ),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4.r),
                    child: Stack(
                      children: [
                        // PDF Page Bitmap Render
                        FutureBuilder<Uint8List?>(
                          future: PdfPageImageRenderer.renderPageBytes(
                            pdfPath: _compiledPdfFile!.path,
                            pageNumber: pageNumber,
                            scale: 1.5,
                          ),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                    ConnectionState.done &&
                                snapshot.hasData &&
                                snapshot.data != null) {
                              return Image.memory(
                                snapshot.data!,
                                fit: BoxFit.contain,
                                width: double.infinity,
                              );
                            }
                            return Container(
                              height: 380.h,
                              color: Colors.white,
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: royalblue,
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          },
                        ),

                        // Page Delete action button (top-right of page)
                        Positioned(
                          top: 8.r,
                          right: 8.r,
                          child: GestureDetector(
                            onTap: () => _deletePage(index),
                            child: Container(
                              padding: EdgeInsets.all(6.r),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.65),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  width: 1,
                                ),
                              ),
                              child: Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                                size: 14.sp,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Gap(8.h),

                // Page Number Tag
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 3.h,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : Colors.black.withValues(alpha: 0.08),
                    borderRadius: allradius(12.r),
                  ),
                  child: Text(
                    "Page $pageNumber of $_totalPages",
                    style: GoogleFonts.outfit(
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomExportBar(bool isDark, ThemeData theme) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141418) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white10 : Colors.black12,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: InkWell(
          onTap: _paths.isEmpty || _isCompiling ? null : _exportPdf,
          borderRadius: allradius(16.r),
          child: Container(
            width: double.infinity,
            height: 50.h,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.primary.withValues(alpha: 0.85),
                ],
              ),
              borderRadius: allradius(16.r),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.picture_as_pdf_rounded,
                  color: Colors.white,
                  size: 20.sp,
                ),
                Gap(10.w),
                Text(
                  _paths.isNotEmpty
                      ? "Export PDF (${_paths.length} Pages)"
                      : "Export PDF",
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
