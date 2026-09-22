/*
 * PDF Hawk - Modern PDF Reader, Writer, Editor & Scanner
 * Copyright (C) 2026 Van Stan / Novaturients
 *
 * This software is licensed under the PolyForm Noncommercial License 1.0.0.
 * You may obtain a copy of the License at https://polyformproject.org/licenses/noncommercial/1.0.0
 */

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:pdfhawk/data/res/constants.dart';
import 'package:pdfhawk/data/res/theme.dart';
import 'package:pdfhawk/interface/pages/PDFTools/images_editor_page.dart';
import 'package:pdfhawk/interface/pages/FileViewers/pdf_reader_page.dart';
import 'package:pdfhawk/logic/helpers/document_converter.dart';
import 'package:share_plus/share_plus.dart';

class ImageViewerPage extends StatefulWidget {
  final File imageFile;

  const ImageViewerPage({super.key, required this.imageFile});

  @override
  State<ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<ImageViewerPage>
    with SingleTickerProviderStateMixin {
  late File _currentFile;
  final TransformationController _transformationController =
      TransformationController();
  TapDownDetails? _doubleTapDetails;
  bool _showChrome = true;
  bool _isConverting = false;

  late AnimationController _animationController;
  Animation<Matrix4>? _zoomAnimation;

  @override
  void initState() {
    super.initState();
    _currentFile = widget.imageFile;
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )..addListener(() {
        if (_zoomAnimation != null) {
          _transformationController.value = _zoomAnimation!.value;
        }
      });
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _toggleChrome() {
    setState(() {
      _showChrome = !_showChrome;
    });
  }

  void _handleDoubleTapDown(TapDownDetails details) {
    _doubleTapDetails = details;
  }

  void _handleDoubleTap() {
    final position = _doubleTapDetails?.localPosition ?? Offset.zero;
    final currentScale = _transformationController.value.getMaxScaleOnAxis();

    final Matrix4 target;
    if (currentScale > 1.2) {
      // Reset to 1.0
      target = Matrix4.identity();
    } else {
      // Zoom in 2.5x centered at tap point
      const zoomScale = 2.5;
      final x = -position.dx * (zoomScale - 1);
      final y = -position.dy * (zoomScale - 1);
      target = Matrix4.diagonal3Values(zoomScale, zoomScale, 1.0)
        ..setTranslationRaw(x, y, 0.0);
    }

    _zoomAnimation = Matrix4Tween(
      begin: _transformationController.value,
      end: target,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );
    _animationController.forward(from: 0);
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) {
      return "${(bytes / 1024).toStringAsFixed(1)} KB";
    }
    return "${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB";
  }

  Future<void> _convertToPdf() async {
    if (_isConverting) return;
    setState(() => _isConverting = true);

    try {
      final pdfFile = await DocumentConverter.convertToPreviewPdf(_currentFile);
      if (!mounted) return;
      setState(() => _isConverting = false);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PDFReaderPage(pdfFile: pdfFile),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isConverting = false);
      Fluttertoast.showToast(msg: "Error converting image to PDF: $e");
    }
  }

  void _shareImage() {
    SharePlus.instance.share(
      ShareParams(
        files: [XFile(_currentFile.path)],
        text: p.basename(_currentFile.path),
      ),
    );
  }

  void _openEditor() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImagesEditorPage(
          imagePath: _currentFile.path,
          onSave: (updatedPath) {
            setState(() {
              _currentFile = File(updatedPath);
            });
            PaintingBinding.instance.imageCache.evict(FileImage(_currentFile));
          },
        ),
      ),
    );
  }

  void _showImageDetails() {
    final fileName = p.basename(_currentFile.path);
    final ext = p.extension(_currentFile.path).toUpperCase().replaceAll('.', '');
    final sizeStr = _currentFile.existsSync()
        ? _formatFileSize(_currentFile.lengthSync())
        : "Unknown";
    final modDate = _currentFile.existsSync()
        ? DateFormat("MMM dd, yyyy • hh:mm a")
            .format(_currentFile.lastModifiedSync())
        : "Unknown";

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        shape: RoundedRectangleBorder(borderRadius: allradius(16.r)),
        title: Row(
          children: [
            const Icon(Icons.image_outlined, color: Colors.tealAccent),
            Gap(10.w),
            Expanded(
              child: Text(
                fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow("Format", ext),
            _buildDetailRow("File Size", sizeStr),
            _buildDetailRow("Modified", modDate),
            _buildDetailRow("Path", _currentFile.path, isPath: true),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Close", style: TextStyle(color: royalblue)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isPath = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.instrumentSans(
              fontSize: 11.sp,
              color: Colors.grey.shade400,
            ),
          ),
          Gap(2.h),
          Text(
            value,
            maxLines: isPath ? 3 : 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.instrumentSans(
              fontSize: 12.5.sp,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fileName = p.basename(_currentFile.path);
    final sizeText = _currentFile.existsSync()
        ? _formatFileSize(_currentFile.lengthSync())
        : "";

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Interactive Image Content
            GestureDetector(
              onTap: _toggleChrome,
              onDoubleTapDown: _handleDoubleTapDown,
              onDoubleTap: _handleDoubleTap,
              child: Container(
                color: Colors.black,
                width: double.infinity,
                height: double.infinity,
                child: Center(
                  child: InteractiveViewer(
                    transformationController: _transformationController,
                    minScale: 0.5,
                    maxScale: 5.0,
                    child: _currentFile.existsSync()
                        ? Image.file(
                            _currentFile,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.broken_image_rounded,
                                  size: 64.r,
                                  color: Colors.grey.shade600,
                                ),
                                Gap(12.h),
                                Text(
                                  "Failed to render image",
                                  style: GoogleFonts.outfit(
                                    color: Colors.grey.shade400,
                                    fontSize: 14.sp,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Text(
                            "Image file no longer exists",
                            style: GoogleFonts.outfit(
                              color: Colors.grey.shade400,
                              fontSize: 14.sp,
                            ),
                          ),
                  ),
                ),
              ),
            ),

            // Top Floating App Bar
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              top: _showChrome ? 0 : -100.h,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 8.h,
                  bottom: 12.h,
                  left: 12.w,
                  right: 12.w,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.85),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Gap(6.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            fileName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          if (sizeText.isNotEmpty)
                            Text(
                              sizeText,
                              style: GoogleFonts.instrumentSans(
                                fontSize: 11.sp,
                                color: Colors.white70,
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.info_outline, color: Colors.white),
                      onPressed: _showImageDetails,
                    ),
                    IconButton(
                      icon: const Icon(Icons.share_rounded, color: Colors.white),
                      onPressed: _shareImage,
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Action Bar
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              bottom: _showChrome ? 0 : -100.h,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).padding.bottom + 12.h,
                  top: 14.h,
                  left: 20.w,
                  right: 20.w,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.9),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildActionButton(
                      icon: Icons.picture_as_pdf_rounded,
                      label: "To PDF",
                      onTap: _convertToPdf,
                      isLoading: _isConverting,
                    ),
                    _buildActionButton(
                      icon: Icons.edit_rounded,
                      label: "Edit",
                      onTap: _openEditor,
                    ),
                    _buildActionButton(
                      icon: Icons.share_rounded,
                      label: "Share",
                      onTap: _shareImage,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: allradius(12.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: allradius(12.r),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              SizedBox(
                width: 16.r,
                height: 16.r,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            else
              Icon(icon, size: 18.r, color: Colors.white),
            Gap(8.w),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
