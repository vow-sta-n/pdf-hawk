/*
 * PDF Hawk - Modern PDF Reader, Writer, Editor & Scanner
 * Copyright (C) 2026 Van Stan / Novaturients
 *
 * This software is licensed under the PolyForm Noncommercial License 1.0.0.
 * You may obtain a copy of the License at https://polyformproject.org/licenses/noncommercial/1.0.0
 */

import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pdfx/pdfx.dart' as pdfx;

/// High-performance on-demand PDF page rendering engine with synchronized queue and LRU memory caching.
class PdfPageImageRenderer {
  // LRU cache for rendered page bitmaps: max 60 entries in RAM
  static const int _maxCacheEntries = 60;
  static final LinkedHashMap<String, Uint8List> _lruCache =
      LinkedHashMap<String, Uint8List>();

  // Cached open PdfDocument handles to avoid reopening files repeatedly
  static final Map<String, pdfx.PdfDocument> _openDocuments = {};

  // Sequential render lock to prevent Android PdfRenderer concurrent page collision exceptions
  static Future<void> _renderLock = Future.value();

  static String _getCacheKey(String path, int page, double scale) =>
      "${path}_${page}_${scale.toStringAsFixed(1)}";

  /// Gets an existing open PdfDocument or opens a new one
  static Future<pdfx.PdfDocument> getOrOpenDocument(String filePath) async {
    if (_openDocuments.containsKey(filePath)) {
      return _openDocuments[filePath]!;
    }
    final doc = await pdfx.PdfDocument.openFile(filePath);
    _openDocuments[filePath] = doc;
    return doc;
  }

  /// Closes and cleans up cached document handles
  static Future<void> closeDocument(String filePath) async {
    if (_openDocuments.containsKey(filePath)) {
      final doc = _openDocuments.remove(filePath);
      await doc?.close();
    }
  }

  /// Clears in-memory page texture cache
  static void clearMemoryCache() {
    _lruCache.clear();
  }

  /// Renders a single PDF page to Uint8List bytes on demand with synchronized queue and LRU caching
  static Future<Uint8List?> renderPageBytes({
    required String pdfPath,
    required int pageNumber,
    double scale = 2.0,
  }) async {
    final key = _getCacheKey(pdfPath, pageNumber, scale);

    // Instant Cache Hit
    if (_lruCache.containsKey(key)) {
      final bytes = _lruCache.remove(key)!;
      _lruCache[key] = bytes; // Move to most recently used
      return bytes;
    }

    // Synchronize rendering sequentially through async queue to guarantee thread-safety on Android
    final completer = Completer<Uint8List?>();

    _renderLock = _renderLock.then((_) async {
      try {
        // Double check cache in case previous queued task already rendered this page
        if (_lruCache.containsKey(key)) {
          final bytes = _lruCache.remove(key)!;
          _lruCache[key] = bytes;
          completer.complete(bytes);
          return;
        }

        final doc = await getOrOpenDocument(pdfPath);
        if (pageNumber < 1 || pageNumber > doc.pagesCount) {
          completer.complete(null);
          return;
        }

        final page = await doc.getPage(pageNumber);
        final rendered = await page.render(
          width: page.width * scale,
          height: page.height * scale,
          format: pdfx.PdfPageImageFormat.jpeg,
          quality: 92,
          backgroundColor: '#FFFFFF',
        );
        await page.close();

        if (rendered != null) {
          // Enforce LRU capacity
          if (_lruCache.length >= _maxCacheEntries) {
            _lruCache.remove(_lruCache.keys.first); // Remove oldest
          }
          _lruCache[key] = rendered.bytes;
          completer.complete(rendered.bytes);
        } else {
          completer.complete(null);
        }
      } catch (e) {
        debugPrint(
          "Error rendering PDF page on demand ($pdfPath:$pageNumber): $e",
        );
        completer.complete(null);
      }
    });

    return completer.future;
  }
}

/// Widget that lazily renders and displays a PDF page on-demand with smooth placeholder
class PdfPageImageWidget extends StatefulWidget {
  final File pdfFile;
  final int pageNumber;
  final BoxFit fit;
  final double scale;
  final double? width;
  final double? height;

  const PdfPageImageWidget({
    super.key,
    required this.pdfFile,
    required this.pageNumber,
    this.fit = BoxFit.contain,
    this.scale = 2.0,
    this.width,
    this.height,
  });

  @override
  State<PdfPageImageWidget> createState() => _PdfPageImageWidgetState();
}

class _PdfPageImageWidgetState extends State<PdfPageImageWidget> {
  Uint8List? _imageBytes;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadPageImage();
  }

  @override
  void didUpdateWidget(covariant PdfPageImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pdfFile.path != widget.pdfFile.path ||
        oldWidget.pageNumber != widget.pageNumber ||
        oldWidget.scale != widget.scale) {
      _loadPageImage();
    }
  }

  Future<void> _loadPageImage() async {
    final key = PdfPageImageRenderer._getCacheKey(
      widget.pdfFile.path,
      widget.pageNumber,
      widget.scale,
    );

    if (PdfPageImageRenderer._lruCache.containsKey(key)) {
      if (mounted) {
        setState(() {
          _imageBytes = PdfPageImageRenderer._lruCache[key];
          _hasError = false;
        });
      }
      return;
    }

    var bytes = await PdfPageImageRenderer.renderPageBytes(
      pdfPath: widget.pdfFile.path,
      pageNumber: widget.pageNumber,
      scale: widget.scale,
    );

    // Quick auto-retry once if initial doc handle was busy
    if (bytes == null && mounted) {
      await Future.delayed(const Duration(milliseconds: 60));
      if (!mounted) return;
      bytes = await PdfPageImageRenderer.renderPageBytes(
        pdfPath: widget.pdfFile.path,
        pageNumber: widget.pageNumber,
        scale: widget.scale,
      );
    }

    if (!mounted) return;

    if (bytes != null) {
      setState(() {
        _imageBytes = bytes;
        _hasError = false;
      });
    } else if (_imageBytes == null) {
      setState(() {
        _hasError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_imageBytes != null) {
      return Image.memory(
        _imageBytes!,
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
        gaplessPlayback: true,
        filterQuality: FilterQuality.high,
        errorBuilder: (context, error, stackTrace) => _buildErrorWidget(),
      );
    }

    if (_hasError) {
      return _buildErrorWidget();
    }

    return _buildLoadingPlaceholder();
  }

  Widget _buildLoadingPlaceholder() {
    return Container(
      width: widget.width,
      height: widget.height,
      color: Colors.white,
      child: Center(
        child: SizedBox(
          width: 24.r,
          height: 24.r,
          child: const CircularProgressIndicator(
            strokeWidth: 2.0,
            color: Colors.black26,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      width: widget.width,
      height: widget.height,
      color: Colors.white,
      child: const Center(
        child: Icon(
          Icons.picture_as_pdf_rounded,
          color: Colors.grey,
          size: 32,
        ),
      ),
    );
  }
}
