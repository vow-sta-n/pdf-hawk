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

/// Token to cancel pending out-of-view render requests
class PdfPageRenderCancelToken {
  bool isCancelled = false;
  void cancel() {
    isCancelled = true;
  }
}

class _RenderTask {
  final String key;
  final String pdfPath;
  final int pageNumber;
  final double scale;
  final Completer<Uint8List?> completer;
  final PdfPageRenderCancelToken? cancelToken;

  _RenderTask({
    required this.key,
    required this.pdfPath,
    required this.pageNumber,
    required this.scale,
    required this.completer,
    this.cancelToken,
  });

  bool get isCancelled => cancelToken?.isCancelled ?? false;
}

/// High-performance on-demand PDF page rendering engine with prioritized LIFO queue,
/// out-of-view cancellation, and expanded LRU memory caching.
class PdfPageImageRenderer {
  // LRU cache for rendered page bitmaps: up to 180 entries in RAM (~10-15MB at thumbnail scale)
  static const int _maxCacheEntries = 180;
  static final LinkedHashMap<String, Uint8List> _lruCache =
      LinkedHashMap<String, Uint8List>();

  // Cached open PdfDocument handles to avoid reopening files repeatedly
  static final Map<String, pdfx.PdfDocument> _openDocuments = {};

  // Pending prioritized render tasks (LIFO priority for on-screen visible items)
  static final List<_RenderTask> _pendingQueue = [];
  static bool _isProcessingQueue = false;

  static String _getCacheKey(String path, int page, double scale) =>
      "${path}_${page}_${scale.toStringAsFixed(2)}";

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
    _pendingQueue.clear();
  }

  /// Checks if a page is already cached in memory
  static bool hasCachedImage(String pdfPath, int pageNumber, double scale) {
    final key = _getCacheKey(pdfPath, pageNumber, scale);
    return _lruCache.containsKey(key);
  }

  /// Returns cached bytes immediately if available
  static Uint8List? getCachedImage(
    String pdfPath,
    int pageNumber,
    double scale,
  ) {
    final key = _getCacheKey(pdfPath, pageNumber, scale);
    if (_lruCache.containsKey(key)) {
      final bytes = _lruCache.remove(key)!;
      _lruCache[key] = bytes;
      return bytes;
    }
    return null;
  }

  /// Renders a single PDF page to Uint8List bytes on demand with prioritized queue and cancellation
  static Future<Uint8List?> renderPageBytes({
    required String pdfPath,
    required int pageNumber,
    double scale = 0.35,
    PdfPageRenderCancelToken? cancelToken,
  }) {
    final key = _getCacheKey(pdfPath, pageNumber, scale);

    // Instant Cache Hit
    if (_lruCache.containsKey(key)) {
      final bytes = _lruCache.remove(key)!;
      _lruCache[key] = bytes; // Move to most recently used
      return Future.value(bytes);
    }

    if (cancelToken?.isCancelled ?? false) {
      return Future.value(null);
    }

    final completer = Completer<Uint8List?>();
    final task = _RenderTask(
      key: key,
      pdfPath: pdfPath,
      pageNumber: pageNumber,
      scale: scale,
      completer: completer,
      cancelToken: cancelToken,
    );

    // Enqueue task for execution (LIFO for visible viewport priority)
    _pendingQueue.add(task);
    _processQueue();

    return completer.future;
  }

  static void _processQueue() async {
    if (_isProcessingQueue) return;
    _isProcessingQueue = true;

    while (_pendingQueue.isNotEmpty) {
      // Pick the most recently added task (LIFO: prioritizes current visible viewport items)
      final task = _pendingQueue.removeLast();

      if (task.isCancelled) {
        if (!task.completer.isCompleted) {
          task.completer.complete(null);
        }
        continue;
      }

      // Check cache in case an earlier task already rendered this page
      if (_lruCache.containsKey(task.key)) {
        final cached = _lruCache.remove(task.key)!;
        _lruCache[task.key] = cached;
        if (!task.completer.isCompleted) {
          task.completer.complete(cached);
        }
        continue;
      }

      try {
        final doc = await getOrOpenDocument(task.pdfPath);
        if (task.isCancelled) {
          if (!task.completer.isCompleted) {
            task.completer.complete(null);
          }
          continue;
        }

        if (task.pageNumber < 1 || task.pageNumber > doc.pagesCount) {
          if (!task.completer.isCompleted) {
            task.completer.complete(null);
          }
          continue;
        }

        final page = await doc.getPage(task.pageNumber);
        if (task.isCancelled) {
          await page.close();
          if (!task.completer.isCompleted) {
            task.completer.complete(null);
          }
          continue;
        }

        final rendered = await page.render(
          width: page.width * task.scale,
          height: page.height * task.scale,
          format: pdfx.PdfPageImageFormat.jpeg,
          quality: 85,
          backgroundColor: '#FFFFFF',
        );
        await page.close();

        if (rendered != null) {
          // Enforce LRU capacity
          if (_lruCache.length >= _maxCacheEntries) {
            _lruCache.remove(_lruCache.keys.first);
          }
          _lruCache[task.key] = rendered.bytes;
          if (!task.completer.isCompleted) {
            task.completer.complete(rendered.bytes);
          }
        } else {
          if (!task.completer.isCompleted) {
            task.completer.complete(null);
          }
        }
      } catch (e) {
        debugPrint(
          "Error rendering PDF page (${task.pdfPath}:${task.pageNumber}): $e",
        );
        if (!task.completer.isCompleted) {
          task.completer.complete(null);
        }
      }
    }

    _isProcessingQueue = false;
  }
}

/// Widget that lazily renders and displays a PDF page on-demand with cancellation of out-of-view requests
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
    this.scale = 0.35,
    this.width,
    this.height,
  });

  @override
  State<PdfPageImageWidget> createState() => _PdfPageImageWidgetState();
}

class _PdfPageImageWidgetState extends State<PdfPageImageWidget> {
  Uint8List? _imageBytes;
  bool _hasError = false;
  PdfPageRenderCancelToken? _cancelToken;

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
      _cancelToken?.cancel();
      _loadPageImage();
    }
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
    super.dispose();
  }

  Future<void> _loadPageImage() async {
    // 1. Fast synchronous check from LRU cache
    final cached = PdfPageImageRenderer.getCachedImage(
      widget.pdfFile.path,
      widget.pageNumber,
      widget.scale,
    );

    if (cached != null) {
      if (mounted) {
        setState(() {
          _imageBytes = cached;
          _hasError = false;
        });
      }
      return;
    }

    // 2. Asynchronously request render with cancellation token
    final token = PdfPageRenderCancelToken();
    _cancelToken = token;

    final bytes = await PdfPageImageRenderer.renderPageBytes(
      pdfPath: widget.pdfFile.path,
      pageNumber: widget.pageNumber,
      scale: widget.scale,
      cancelToken: token,
    );

    if (!mounted || token.isCancelled) return;

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
        filterQuality: FilterQuality.medium,
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
          width: 18.r,
          height: 18.r,
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
        child: Icon(Icons.picture_as_pdf_rounded, color: Colors.grey, size: 28),
      ),
    );
  }
}
