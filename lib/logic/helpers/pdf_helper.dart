/*
 * PDF Hawk - Modern PDF Reader, Writer, Editor & Scanner
 * Copyright (C) 2026 Van Stan / Novaturients
 *
 * This software is licensed under the PolyForm Noncommercial License 1.0.0.
 * You may obtain a copy of the License at https://polyformproject.org/licenses/noncommercial/1.0.0
 */

// ignore_for_file: implementation_imports

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdfhawk/data/class/editor_overlay_item.dart';
import 'package:pdfhawk/data/res/enum.dart';
import 'package:pdfhawk/interface/widgets/pdf_page_renderer.dart';
import 'package:pdfhawk/logic/services/storage_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:saf/src/storage_access_framework/api.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf_pdf;

/// Models for PDF drawing paths
class DrawingPath {
  List<Offset> points;
  Color color;
  double strokeWidth;
  final bool isHighlighter;

  DrawingPath({
    required this.points,
    required this.color,
    required this.strokeWidth,
    required this.isHighlighter,
  });

  Rect getBounds({double padding = 8.0}) {
    if (points.isEmpty) return Rect.zero;
    double minX = points.first.dx, maxX = points.first.dx;
    double minY = points.first.dy, maxY = points.first.dy;
    for (final p in points) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }
    return Rect.fromLTRB(
      minX - padding,
      minY - padding,
      maxX + padding,
      maxY + padding,
    );
  }

  bool hitTest(Offset tapPos, {double threshold = 20.0}) {
    if (points.isEmpty) return false;
    final bounds = getBounds(padding: threshold);
    if (!bounds.contains(tapPos)) return false;

    for (int i = 0; i < points.length; i++) {
      if ((points[i] - tapPos).distance <= threshold) return true;
      if (i > 0) {
        final d = _distToSegment(tapPos, points[i - 1], points[i]);
        if (d <= threshold) return true;
      }
    }
    return false;
  }

  static double _distToSegment(Offset p, Offset v, Offset w) {
    final l2 = (v - w).distanceSquared;
    if (l2 == 0) return (p - v).distance;
    final t = (((p.dx - v.dx) * (w.dx - v.dx) + (p.dy - v.dy) * (w.dy - v.dy)) /
            l2)
        .clamp(0.0, 1.0);
    final projection =
        Offset(v.dx + t * (w.dx - v.dx), v.dy + t * (w.dy - v.dy));
    return (p - projection).distance;
  }

  void translate(Offset delta) {
    points = points.map((p) => p + delta).toList();
  }

  void scaleFromBounds(Rect oldBounds, Rect newBounds) {
    if (oldBounds.width == 0 || oldBounds.height == 0) return;
    points = points.map((p) {
      final normalizedX = (p.dx - oldBounds.left) / oldBounds.width;
      final normalizedY = (p.dy - oldBounds.top) / oldBounds.height;
      return Offset(
        newBounds.left + normalizedX * newBounds.width,
        newBounds.top + normalizedY * newBounds.height,
      );
    }).toList();
  }

  DrawingPath clone() => DrawingPath(
        points: List.from(points),
        color: color,
        strokeWidth: strokeWidth,
        isHighlighter: isHighlighter,
      );

  Map<String, dynamic> toJson() => {
    'points': points.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
    'color': color.toARGB32(),
    'strokeWidth': strokeWidth,
    'isHighlighter': isHighlighter,
  };

  factory DrawingPath.fromJson(Map<String, dynamic> json) {
    final pts = (json['points'] as List)
        .map(
          (p) => Offset((p['x'] as num).toDouble(), (p['y'] as num).toDouble()),
        )
        .toList();
    return DrawingPath(
      points: pts,
      color: Color(json['color'] as int),
      strokeWidth: (json['strokeWidth'] as num).toDouble(),
      isHighlighter: json['isHighlighter'] as bool,
    );
  }
}

/// Model representing a word inside an extracted PDF text line
class PdfTextWordModel {
  final String text;
  final Rect bounds;

  const PdfTextWordModel({
    required this.text,
    required this.bounds,
  });
}

/// Model representing an extracted line of text from a PDF page with its geometric bounding box
class PdfTextLineModel {
  final String text;
  final Rect bounds;
  final double fontSize;
  final int pageNumber;
  final List<PdfTextWordModel> words;

  const PdfTextLineModel({
    required this.text,
    required this.bounds,
    this.fontSize = 12.0,
    required this.pageNumber,
    this.words = const [],
  });
}

/// Model for a PDF page in our edit session
class PdfPageModel {
  /// Unique ID for key matching in reorderable UI grids
  final String id;

  /// Index in the original PDF file (1-based), null if it is a new blank or image page
  int? originalPageIndex;

  /// Original PDF File if this page comes from a specific PDF document
  File? sourcePdfFile;

  /// Cached image file path of the page's original content (for rendering in UI if modified)
  String? cachedImagePath;

  /// If this page was added from an image
  String? newImageFilePath;

  /// User annotations/markings drawn on this page
  List<DrawingPath> drawings;

  /// User image & shape overlays placed on this page
  List<EditorOverlayItem> overlays;

  /// Dimensions of the page in PDF points (72 points/inch, e.g. 595 x 842 for A4)
  double width;
  double height;

  PdfPageModel({
    String? id,
    this.originalPageIndex,
    this.sourcePdfFile,
    this.cachedImagePath,
    this.newImageFilePath,
    required this.drawings,
    List<EditorOverlayItem>? overlays,
    required this.width,
    required this.height,
  })  : id = id ?? UniqueKey().toString(),
        overlays = overlays ?? [];
}

/// Managing session for editing a PDF file
class PdfEditSession {
  final File originalFile;
  final List<PdfPageModel> pages;

  PdfEditSession({required this.originalFile, required this.pages});
}

class PdfHelper {
  // In-memory cache for extracted text lines per PDF page key: "${filePath}_${pageNumber}"
  static final Map<String, List<PdfTextLineModel>> _textLinesCache = {};

  /// Clears text lines cache
  static void clearTextLinesCache() {
    _textLinesCache.clear();
  }

  /// Extracts text lines with bounding boxes for a specific page (1-based pageNumber)
  static Future<List<PdfTextLineModel>> extractPageTextLines({
    required File pdfFile,
    required int pageNumber,
  }) async {
    final cacheKey = "${pdfFile.path}_$pageNumber";
    if (_textLinesCache.containsKey(cacheKey)) {
      return _textLinesCache[cacheKey]!;
    }

    if (!pdfFile.existsSync()) return [];

    try {
      final bytes = await pdfFile.readAsBytes();
      final document = sf_pdf.PdfDocument(inputBytes: bytes);

      final pageIndex = pageNumber - 1;
      if (pageIndex < 0 || pageIndex >= document.pages.count) {
        document.dispose();
        return [];
      }

      final extractor = sf_pdf.PdfTextExtractor(document);
      final textLines = extractor.extractTextLines(
        startPageIndex: pageIndex,
        endPageIndex: pageIndex,
      );

      final List<PdfTextLineModel> result = [];
      for (final line in textLines) {
        final words = <PdfTextWordModel>[];
        if (line.wordCollection.isNotEmpty) {
          for (final w in line.wordCollection) {
            words.add(
              PdfTextWordModel(
                text: w.text,
                bounds: w.bounds,
              ),
            );
          }
        }

        result.add(
          PdfTextLineModel(
            text: line.text,
            bounds: line.bounds,
            fontSize: line.fontSize > 0
                ? line.fontSize
                : (line.bounds.height > 0 ? line.bounds.height * 0.8 : 12.0),
            pageNumber: pageNumber,
            words: words,
          ),
        );
      }

      document.dispose();
      _textLinesCache[cacheKey] = result;
      return result;
    } catch (e) {
      debugPrint("Error extracting text lines from page $pageNumber: $e");
      return [];
    }
  }

  /// Extracts plain text from a specific page (1-based) or the entire document
  static Future<String> extractTextContent({
    required File pdfFile,
    int? pageNumber,
  }) async {
    if (!pdfFile.existsSync()) return "";

    try {
      final bytes = await pdfFile.readAsBytes();
      final document = sf_pdf.PdfDocument(inputBytes: bytes);
      final extractor = sf_pdf.PdfTextExtractor(document);

      String extractedText = "";
      if (pageNumber != null) {
        final pageIndex = pageNumber - 1;
        if (pageIndex >= 0 && pageIndex < document.pages.count) {
          extractedText = extractor.extractText(
            startPageIndex: pageIndex,
            endPageIndex: pageIndex,
          );
        }
      } else {
        extractedText = extractor.extractText();
      }

      document.dispose();
      return extractedText.trim();
    } catch (e) {
      debugPrint("Error extracting text content from PDF: $e");
      return "";
    }
  }

  /// Loads a PDF file metadata instantly (<50ms) and initializes an on-demand Edit Session
  static Future<PdfEditSession> startEditSession(File pdfFile) async {
    final pages = <PdfPageModel>[];
    final document = await PdfPageImageRenderer.getOrOpenDocument(pdfFile.path);

    double defaultWidth = 595.0; // A4 standard fallback width
    double defaultHeight = 842.0; // A4 standard fallback height

    // Instantly generate lightweight page models for all pages with each page's true dimensions
    for (int i = 0; i < document.pagesCount; i++) {
      double pageWidth = defaultWidth;
      double pageHeight = defaultHeight;
      try {
        final page = await document.getPage(i + 1);
        pageWidth = page.width.toDouble();
        pageHeight = page.height.toDouble();
        await page.close();
      } catch (e) {
        debugPrint("Could not read page ${i + 1} dimensions: $e");
      }

      pages.add(
        PdfPageModel(
          originalPageIndex: i + 1,
          sourcePdfFile: pdfFile,
          cachedImagePath: null,
          drawings: [],
          width: pageWidth,
          height: pageHeight,
        ),
      );
    }

    return PdfEditSession(originalFile: pdfFile, pages: pages);
  }

  /// Compiles an Edit Session into raw PDF bytes in memory natively
  static Future<Uint8List> compileSessionBytes({
    required PdfEditSession session,
  }) async {
    final targetDoc = sf_pdf.PdfDocument();
    targetDoc.pageSettings.margins.all = 0;
    final Map<String, sf_pdf.PdfDocument> openedSourceDocs = {};

    try {
      for (final pageModel in session.pages) {
        if (pageModel.newImageFilePath != null &&
            File(pageModel.newImageFilePath!).existsSync()) {
          // 1. Page added from a new image
          final imgBytes =
              await File(pageModel.newImageFilePath!).readAsBytes();
          final bitmap = sf_pdf.PdfBitmap(imgBytes);
          targetDoc.pageSettings.size = Size(
            pageModel.width > 0 ? pageModel.width : bitmap.width.toDouble(),
            pageModel.height > 0 ? pageModel.height : bitmap.height.toDouble(),
          );
          final newPage = targetDoc.pages.add();
          newPage.graphics.drawImage(
            bitmap,
            Rect.fromLTWH(
              0,
              0,
              newPage.getClientSize().width,
              newPage.getClientSize().height,
            ),
          );
          _drawDrawingsOnPdfPage(
            newPage,
            pageModel.drawings,
            modelWidth: pageModel.width,
            modelHeight: pageModel.height,
          );
          _drawOverlaysOnPdfPage(newPage, pageModel.overlays);
        } else if (pageModel.cachedImagePath != null &&
            File(pageModel.cachedImagePath!).existsSync()) {
          // 2. Page modified / cropped / edited as an image
          final imgBytes =
              await File(pageModel.cachedImagePath!).readAsBytes();
          final bitmap = sf_pdf.PdfBitmap(imgBytes);
          targetDoc.pageSettings.size = Size(
            pageModel.width > 0 ? pageModel.width : bitmap.width.toDouble(),
            pageModel.height > 0 ? pageModel.height : bitmap.height.toDouble(),
          );
          final newPage = targetDoc.pages.add();
          newPage.graphics.drawImage(
            bitmap,
            Rect.fromLTWH(
              0,
              0,
              newPage.getClientSize().width,
              newPage.getClientSize().height,
            ),
          );
          _drawDrawingsOnPdfPage(
            newPage,
            pageModel.drawings,
            modelWidth: pageModel.width,
            modelHeight: pageModel.height,
          );
          _drawOverlaysOnPdfPage(newPage, pageModel.overlays);
        } else if (pageModel.originalPageIndex != null) {
          // 3. Untouched original PDF page: Native stream import without rasterization!
          final sourceFile = pageModel.sourcePdfFile ?? session.originalFile;
          sf_pdf.PdfDocument? sourceDoc = openedSourceDocs[sourceFile.path];
          if (sourceDoc == null) {
            final sourceBytes = await sourceFile.readAsBytes();
            sourceDoc = sf_pdf.PdfDocument(inputBytes: sourceBytes);
            openedSourceDocs[sourceFile.path] = sourceDoc;
          }

          final pageIndex = pageModel.originalPageIndex! - 1;
          if (pageIndex >= 0 && pageIndex < sourceDoc.pages.count) {
            final sourcePage = sourceDoc.pages[pageIndex];
            final template = sourcePage.createTemplate();
            targetDoc.pageSettings.size = Size(
              sourcePage.size.width > 0 ? sourcePage.size.width : pageModel.width,
              sourcePage.size.height > 0 ? sourcePage.size.height : pageModel.height,
            );
            final newPage = targetDoc.pages.add();
            newPage.graphics.drawPdfTemplate(
              template,
              Offset.zero,
              Size(newPage.getClientSize().width, newPage.getClientSize().height),
            );

            // Draw vector drawing paths and highlighter annotations
            _drawDrawingsOnPdfPage(
              newPage,
              pageModel.drawings,
              modelWidth: pageModel.width,
              modelHeight: pageModel.height,
            );

            // Draw image, shape, and text overlays
            _drawOverlaysOnPdfPage(newPage, pageModel.overlays);
          } else {
            targetDoc.pages.add();
          }
        } else {
          // 4. Blank page
          targetDoc.pageSettings.size = Size(
            pageModel.width > 0 ? pageModel.width : 595.0,
            pageModel.height > 0 ? pageModel.height : 842.0,
          );
          final newPage = targetDoc.pages.add();
          _drawDrawingsOnPdfPage(
            newPage,
            pageModel.drawings,
            modelWidth: pageModel.width,
            modelHeight: pageModel.height,
          );
          _drawOverlaysOnPdfPage(newPage, pageModel.overlays);
        }
      }

      return Uint8List.fromList(targetDoc.saveSync());
    } finally {
      for (final doc in openedSourceDocs.values) {
        doc.dispose();
      }
      targetDoc.dispose();
    }
  }

  /// Draws freehand pen and highlighter drawings onto a PDF page with correct transparency and coordinate scaling
  static void _drawDrawingsOnPdfPage(
    sf_pdf.PdfPage newPage,
    List<DrawingPath> drawings, {
    double? modelWidth,
    double? modelHeight,
  }) {
    if (drawings.isEmpty) return;

    final clientW = newPage.getClientSize().width;
    final clientH = newPage.getClientSize().height;
    final scaleX = (modelWidth != null && modelWidth > 0) ? clientW / modelWidth : 1.0;
    final scaleY = (modelHeight != null && modelHeight > 0) ? clientH / modelHeight : 1.0;
    final avgScale = (scaleX + scaleY) / 2.0;

    for (final drawing in drawings) {
      if (drawing.points.isEmpty) continue;

      final penColor = sf_pdf.PdfColor(
        (drawing.color.r * 255).round().clamp(0, 255),
        (drawing.color.g * 255).round().clamp(0, 255),
        (drawing.color.b * 255).round().clamp(0, 255),
      );

      final pen = sf_pdf.PdfPen(
        penColor,
        width: drawing.strokeWidth * avgScale,
      );
      pen.lineCap = sf_pdf.PdfLineCap.round;
      pen.lineJoin = sf_pdf.PdfLineJoin.round;

      newPage.graphics.save();

      if (drawing.isHighlighter) {
        // Highlighters are semi-transparent (40% opacity matching the canvas preview)
        newPage.graphics.setTransparency(0.4);
      }

      if (drawing.points.length == 1) {
        final brush = sf_pdf.PdfSolidBrush(penColor);
        final pt = Offset(
          drawing.points.first.dx * scaleX,
          drawing.points.first.dy * scaleY,
        );
        final radius = ((drawing.strokeWidth * avgScale) / 2).clamp(1.5, 50.0);
        newPage.graphics.drawEllipse(
          Rect.fromCircle(center: pt, radius: radius),
          brush: brush,
        );
      } else {
        final path = sf_pdf.PdfPath();
        for (int i = 0; i < drawing.points.length - 1; i++) {
          path.addLine(
            Offset(drawing.points[i].dx * scaleX, drawing.points[i].dy * scaleY),
            Offset(drawing.points[i + 1].dx * scaleX, drawing.points[i + 1].dy * scaleY),
          );
        }
        newPage.graphics.drawPath(path, pen: pen);
      }

      newPage.graphics.restore();
    }
  }

  /// Exports an Edit Session to a new PDF file natively
  static Future<File> saveSession({
    required PdfEditSession session,
    String? safDirectoryUri,
    String? outputName,
  }) async {
    final docBytes = await compileSessionBytes(session: session);

    // Save locally to PDFHawk storage folder
    final name =
        outputName ??
        'edited_${session.originalFile.path.split('/').last.replaceAll('.pdf', '')}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final localOutputFile = await StorageService.saveExportedFile(
      fileName: name,
      bytes: docBytes,
    );

    // Save to Storage Access Framework (SAF) folder on Android
    if (safDirectoryUri != null) {
      try {
        final treeUri = Uri.parse(
          makeUriString(path: safDirectoryUri, isTreeUri: true),
        );
        await createFileAsBytes(
          treeUri,
          mimeType: 'application/pdf',
          displayName: name,
          content: docBytes,
        );
      } catch (e) {
        debugPrint("Failed to write to SAF directory: $e");
      }
    }

    return localOutputFile;
  }

  static void _drawOverlaysOnPdfPage(
    sf_pdf.PdfPage newPage,
    List<EditorOverlayItem> overlays,
  ) {
    if (overlays.isEmpty) return;
    final pageW = newPage.getClientSize().width;
    final pageH = newPage.getClientSize().height;

    for (final overlay in overlays) {
      final itemW = overlay.width * pageW;
      final itemH = overlay.height * pageH;
      final itemLeft = (overlay.position.dx * pageW) - (itemW / 2);
      final itemTop = (overlay.position.dy * pageH) - (itemH / 2);
      final rect = Rect.fromLTWH(itemLeft, itemTop, itemW, itemH);

      newPage.graphics.save();
      if (overlay.opacity < 1.0) {
        newPage.graphics.setTransparency(overlay.opacity.clamp(0.0, 1.0));
      }

      if (overlay.type == ElementType.image && overlay.imagePath != null) {
        final imgFile = File(overlay.imagePath!);
        if (imgFile.existsSync()) {
          try {
            final imgBytes = imgFile.readAsBytesSync();
            final pdfImage = sf_pdf.PdfBitmap(imgBytes);
            newPage.graphics.drawImage(pdfImage, rect);
          } catch (e) {
            debugPrint("Error drawing overlay image to PDF: $e");
          }
        }
      } else if (overlay.type == ElementType.shape) {
        final strokePdfColor = sf_pdf.PdfColor(
          (overlay.strokeColor.r * 255).round().clamp(0, 255),
          (overlay.strokeColor.g * 255).round().clamp(0, 255),
          (overlay.strokeColor.b * 255).round().clamp(0, 255),
        );
        final pen = sf_pdf.PdfPen(
          strokePdfColor,
          width: overlay.strokeWidth,
        );

        sf_pdf.PdfBrush? brush;
        if (overlay.isFilled && overlay.fillColor != Colors.transparent) {
          final fillPdfColor = sf_pdf.PdfColor(
            (overlay.fillColor.r * 255).round().clamp(0, 255),
            (overlay.fillColor.g * 255).round().clamp(0, 255),
            (overlay.fillColor.b * 255).round().clamp(0, 255),
          );
          brush = sf_pdf.PdfSolidBrush(fillPdfColor);
        }

        if (overlay.shapeType == ShapeType.circle ||
            overlay.shapeType == ShapeType.oval) {
          newPage.graphics.drawEllipse(
            rect,
            pen: pen,
            brush: brush,
          );
        } else if (overlay.shapeType == ShapeType.line) {
          newPage.graphics.drawLine(
            pen,
            Offset(itemLeft, itemTop + itemH / 2),
            Offset(itemLeft + itemW, itemTop + itemH / 2),
          );
        } else {
          newPage.graphics.drawRectangle(
            pen: pen,
            brush: brush,
            bounds: rect,
          );
        }
      } else if (overlay.type == ElementType.text && overlay.text.isNotEmpty) {
        final textPdfColor = sf_pdf.PdfColor(
          (overlay.textColor.r * 255).round().clamp(0, 255),
          (overlay.textColor.g * 255).round().clamp(0, 255),
          (overlay.textColor.b * 255).round().clamp(0, 255),
        );
        final fontStyle = overlay.isBold
            ? sf_pdf.PdfFontStyle.bold
            : overlay.isItalic
                ? sf_pdf.PdfFontStyle.italic
                : sf_pdf.PdfFontStyle.regular;
        final font = sf_pdf.PdfStandardFont(
          sf_pdf.PdfFontFamily.helvetica,
          overlay.fontSize > 0 ? overlay.fontSize : 14.0,
          style: fontStyle,
        );
        final brush = sf_pdf.PdfSolidBrush(textPdfColor);

        if (overlay.backgroundColor != null &&
            overlay.backgroundColor != Colors.transparent) {
          final bgPdfColor = sf_pdf.PdfColor(
            (overlay.backgroundColor!.r * 255).round().clamp(0, 255),
            (overlay.backgroundColor!.g * 255).round().clamp(0, 255),
            (overlay.backgroundColor!.b * 255).round().clamp(0, 255),
          );
          newPage.graphics.drawRectangle(
            brush: sf_pdf.PdfSolidBrush(bgPdfColor),
            bounds: rect,
          );
        }

        newPage.graphics.drawString(
          overlay.text,
          font,
          brush: brush,
          bounds: rect,
          format: sf_pdf.PdfStringFormat(
            alignment: sf_pdf.PdfTextAlignment.center,
            lineAlignment: sf_pdf.PdfVerticalAlignment.middle,
          ),
        );
      }
      newPage.graphics.restore();
    }
  }

  /// Merges multiple PDF files natively into a single PDF without rasterization
  static Future<File> mergePdfs({
    required List<File> pdfFiles,
    String? safDirectoryUri,
    String? outputName,
  }) async {
    final targetDoc = sf_pdf.PdfDocument();

    try {
      for (final file in pdfFiles) {
        if (!file.existsSync()) continue;
        final fileBytes = await file.readAsBytes();
        final sourceDoc = sf_pdf.PdfDocument(inputBytes: fileBytes);
        for (int i = 0; i < sourceDoc.pages.count; i++) {
          final template = sourceDoc.pages[i].createTemplate();
          final newPage = targetDoc.pages.add();
          newPage.graphics.drawPdfTemplate(
            template,
            Offset.zero,
            Size(newPage.getClientSize().width, newPage.getClientSize().height),
          );
        }
        sourceDoc.dispose();
      }

      final docBytes = Uint8List.fromList(targetDoc.saveSync());

      // Save locally to PDFHawk storage folder
      final name =
          outputName ?? 'merged_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final localOutputFile = await StorageService.saveExportedFile(
        fileName: name,
        bytes: docBytes,
      );

      // Save to SAF directory
      if (safDirectoryUri != null) {
        try {
          final treeUri = Uri.parse(
            makeUriString(path: safDirectoryUri, isTreeUri: true),
          );
          await createFileAsBytes(
            treeUri,
            mimeType: 'application/pdf',
            displayName: name,
            content: docBytes,
          );
        } catch (e) {
          debugPrint("Failed to write merged PDF to SAF: $e");
        }
      }

      return localOutputFile;
    } finally {
      targetDoc.dispose();
    }
  }

  /// Splits a PDF file into multiple PDF files natively without rasterization
  static Future<List<File>> splitPdf({
    required File pdfFile,
    required List<List<int>> ranges,
    String? safDirectoryUri,
    String? baseFileName,
  }) async {
    final fileBytes = await pdfFile.readAsBytes();
    final sourceDoc = sf_pdf.PdfDocument(inputBytes: fileBytes);
    final List<File> outputFiles = [];
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fallbackBaseName = pdfFile.path
        .split('/')
        .last
        .replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
    final baseName =
        (baseFileName != null && baseFileName.trim().isNotEmpty)
            ? baseFileName.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
            : fallbackBaseName;

    try {
      for (int partIdx = 0; partIdx < ranges.length; partIdx++) {
        final range = ranges[partIdx];
        final startPage = range[0];
        final endPage = range[1];

        final targetDoc = sf_pdf.PdfDocument();

        for (int p = startPage; p <= endPage; p++) {
          final pageIndex = p - 1;
          if (pageIndex >= 0 && pageIndex < sourceDoc.pages.count) {
            final template = sourceDoc.pages[pageIndex].createTemplate();
            final newPage = targetDoc.pages.add();
            newPage.graphics.drawPdfTemplate(
              template,
              Offset.zero,
              Size(newPage.getClientSize().width, newPage.getClientSize().height),
            );
          }
        }

        final docBytes = Uint8List.fromList(targetDoc.saveSync());
        targetDoc.dispose();

        final name = "${baseName}_Part_${partIdx + 1}_$timestamp.pdf";
        final localOutputFile = await StorageService.saveExportedFile(
          fileName: name,
          bytes: docBytes,
        );

        if (safDirectoryUri != null) {
          try {
            final treeUri = Uri.parse(
              makeUriString(path: safDirectoryUri, isTreeUri: true),
            );
            await createFileAsBytes(
              treeUri,
              mimeType: 'application/pdf',
              displayName: name,
              content: docBytes,
            );
          } catch (e) {
            debugPrint("Failed to write split PDF to SAF: $e");
          }
        }

        outputFiles.add(localOutputFile);
      }
    } finally {
      sourceDoc.dispose();
    }

    // Add split files to Hive recent files list
    try {
      final box = Hive.box('pdfhawk_box');
      List<String> recentList = List<String>.from(
        box.get('recent_files') ?? [],
      );
      for (final f in outputFiles) {
        recentList.remove(f.path);
        recentList.insert(0, f.path);
      }
      if (recentList.length > 50) {
        recentList = recentList.sublist(0, 50);
      }
      await box.put('recent_files', recentList);
    } catch (_) {}

    return outputFiles;
  }

  /// Compresses a PDF or Image file according to the desired quality percentage (1-100).
  /// Returns the compressed output File.
  static Future<File?> compressPdfOrImageFile({
    required File inputFile,
    int quality = 60,
    String? safDirectoryUri,
  }) async {
    if (!inputFile.existsSync()) return null;

    final path = inputFile.path.toLowerCase();
    final isPdf = path.endsWith('.pdf');
    final isImage = path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.png') ||
        path.endsWith('.webp');

    if (!isPdf && !isImage) return null;

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final baseName = inputFile.path.split('/').last.replaceAll(RegExp(r'\.[^.]+$'), '');

    if (isPdf) {
      final inputBytes = await inputFile.readAsBytes();
      final sf_pdf.PdfDocument document = sf_pdf.PdfDocument(inputBytes: inputBytes);
      document.compressionLevel = sf_pdf.PdfCompressionLevel.best;

      final List<int> compressedBytes = await document.save();
      document.dispose();

      final outName = "compressed_${baseName}_$timestamp.pdf";
      final outputFile = await StorageService.saveExportedFile(
        fileName: outName,
        bytes: Uint8List.fromList(compressedBytes),
      );

      if (safDirectoryUri != null) {
        try {
          final treeUri = Uri.parse(makeUriString(path: safDirectoryUri, isTreeUri: true));
          await createFileAsBytes(
            treeUri,
            mimeType: 'application/pdf',
            displayName: outName,
            content: Uint8List.fromList(compressedBytes),
          );
        } catch (e) {
          debugPrint("Failed to save compressed PDF to SAF: $e");
        }
      }

      try {
        final box = Hive.box('pdfhawk_box');
        List<String> recentList = List<String>.from(box.get('recent_files') ?? []);
        recentList.remove(outputFile.path);
        recentList.insert(0, outputFile.path);
        if (recentList.length > 50) recentList = recentList.sublist(0, 50);
        await box.put('recent_files', recentList);
      } catch (_) {}

      return outputFile;
    } else {
      final imageBytes = await inputFile.readAsBytes();
      final decodedImage = img.decodeImage(imageBytes);
      if (decodedImage == null) return null;

      final compressedBytes = img.encodeJpg(decodedImage, quality: quality);
      final ext = path.endsWith('.png') || path.endsWith('.webp') ? 'jpg' : path.split('.').last;
      final outName = "compressed_${baseName}_$timestamp.$ext";

      final outputFile = await StorageService.saveExportedFile(
        fileName: outName,
        bytes: Uint8List.fromList(compressedBytes),
      );

      return outputFile;
    }
  }
}
