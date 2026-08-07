import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:file_picker/file_picker.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdfhawk/interface/pages/pdf_reader_page.dart';
import 'package:pdfhawk/logic/helpers/pdf_helper.dart';
import 'package:pdfx/pdfx.dart' as pdfx;

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

  Future<void> _executeMerge() async {
    if (_files.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select at least 2 PDF files to merge."),
          backgroundColor: Colors.orange,
        ),
      );
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
          TextButton.icon(
            onPressed: _pickMorePdfs,
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text("Add More"),
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
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                color: isDark ? const Color(0xFF161616) : Colors.white,
                child: Row(
                  children: [
                    Icon(
                      Icons.drag_indicator_rounded,
                      size: 20.r,
                      color: theme.colorScheme.primary,
                    ),
                    Gap(8.w),
                    Expanded(
                      child: Text(
                        "${_files.length} PDFs selected • Long-press or drag to reorder merge sequence",
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

              // Reorderable List of Selected PDF Files
              Expanded(
                child: ReorderableListView.builder(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 12.h,
                  ),
                  itemCount: _files.length,
                  // ignore: deprecated_member_use
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) {
                        newIndex -= 1;
                      }
                      final item = _files.removeAt(oldIndex);
                      _files.insert(newIndex, item);
                    });
                  },
                  itemBuilder: (context, index) {
                    final file = _files[index];
                    final fileName = file.path.split('/').last;
                    final pageCount = _pageCounts[file.path];
                    final thumb = _thumbnails[file.path];
                    final fileSizeMb = (file.lengthSync() / (1024 * 1024))
                        .toStringAsFixed(1);

                    return Card(
                      key: ValueKey(file.path),
                      elevation: 2,
                      margin: EdgeInsets.only(bottom: 12.h),
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.r),
                        side: BorderSide(
                          color: isDark ? Colors.white10 : Colors.black12,
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(12.r),
                        child: Row(
                          children: [
                            // Sequence Number Avatar Badge
                            CircleAvatar(
                              radius: 14.r,
                              backgroundColor: theme.colorScheme.primary,
                              child: Text(
                                "${index + 1}",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Gap(12.w),

                            // PDF Thumbnail
                            Container(
                              width: 48.w,
                              height: 60.h,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.grey.shade900
                                    : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                              child: thumb != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8.r),
                                      child: Image.memory(
                                        thumb,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : Center(
                                      child: Icon(
                                        Icons.picture_as_pdf_rounded,
                                        color: theme.colorScheme.primary,
                                        size: 24.r,
                                      ),
                                    ),
                            ),
                            Gap(12.w),

                            // File Name & Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
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

                            // Delete Action Button
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.redAccent,
                              ),
                              onPressed: () {
                                setState(() {
                                  _files.removeAt(index);
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
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
                    onPressed: _isMerging ? null : _executeMerge,
                    icon: const Icon(
                      Icons.merge_type_rounded,
                      color: Colors.white,
                    ),
                    label: Text(
                      "Merge ${_files.length} PDFs",
                      style: GoogleFonts.outfit(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.r),
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
}
