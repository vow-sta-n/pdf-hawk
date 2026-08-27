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
import 'package:pdfhawk/data/res/constants.dart';
import 'package:pdfx/pdfx.dart' as pdfx;

class PdfThumbnailWidget extends StatefulWidget {
  final String filePath;
  final double width;
  final double height;
  final double borderRadius;

  const PdfThumbnailWidget({
    super.key,
    required this.filePath,
    this.width = 38,
    this.height = 48,
    this.borderRadius = 6,
  });

  @override
  State<PdfThumbnailWidget> createState() => _PdfThumbnailWidgetState();
}

class _PdfThumbnailWidgetState extends State<PdfThumbnailWidget> {
  static final Map<String, Uint8List> _thumbnailCache = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  @override
  void didUpdateWidget(covariant PdfThumbnailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath) {
      _loadThumbnail();
    }
  }

  Future<void> _loadThumbnail() async {
    if (_thumbnailCache.containsKey(widget.filePath)) return;
    if (_isLoading) return;

    _isLoading = true;
    try {
      final file = File(widget.filePath);
      if (!file.existsSync()) {
        _isLoading = false;
        return;
      }

      final doc = await pdfx.PdfDocument.openFile(widget.filePath);
      if (doc.pagesCount > 0) {
        final page = await doc.getPage(1);
        final rendered = await page.render(
          width: widget.width * 2.5,
          height: widget.height * 2.5,
          format: pdfx.PdfPageImageFormat.jpeg,
          quality: 85,
          backgroundColor: '#FFFFFF',
        );
        await page.close();
        if (rendered != null && mounted) {
          _thumbnailCache[widget.filePath] = rendered.bytes;
          setState(() {});
        }
      }
      await doc.close();
    } catch (_) {
      // Fallback gracefully to icon placeholder
    } finally {
      if (mounted) {
        _isLoading = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _thumbnailCache[widget.filePath];
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (bytes != null) {
      return Container(
        width: widget.width.w,
        height: widget.height.h,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: allradius(widget.borderRadius.r),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.12),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.15),
              blurRadius: 4,
              offset: const Offset(0, 1.5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: allradius(widget.borderRadius.r),
          child: Image.memory(
            bytes,
            fit: BoxFit.cover,
            gaplessPlayback: true,
          ),
        ),
      );
    }

    // Default Document Placeholder while loading or on error
    return Container(
      width: widget.width.w,
      height: widget.height.h,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: allradius(widget.borderRadius.r),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
          width: 0.8,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.picture_as_pdf_rounded,
          color: theme.colorScheme.primary,
          size: (widget.width * 0.55).r,
        ),
      ),
    );
  }
}
