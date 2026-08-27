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
  /// Loads a PDF file metadata instantly (<50ms) and initializes an on-demand Edit Session
  static Future<PdfEditSession> startEditSession(File pdfFile) async {
    final pages = <PdfPageModel>[];
    final document = await PdfPageImageRenderer.getOrOpenDocument(pdfFile.path);

    double defaultWidth = 595.0; // A4 standard width
    double defaultHeight = 842.0; // A4 standard height

    if (document.pagesCount > 0) {
      try {
        final firstPage = await document.getPage(1);
        defaultWidth = firstPage.width.toDouble();
        defaultHeight = firstPage.height.toDouble();
        await firstPage.close();
      } catch (e) {
        debugPrint("Could not read initial page dimensions: $e");
      }
    }

    // Instantly generate lightweight page models for all pages without any upfront rasterization or disk I/O!
    for (int i = 0; i < document.pagesCount; i++) {
      pages.add(
        PdfPageModel(
          originalPageIndex: i + 1,
          sourcePdfFile: pdfFile,
          cachedImagePath: null,
          drawings: [],
          width: defaultWidth,
          height: defaultHeight,
        ),
      );
    }

    return PdfEditSession(originalFile: pdfFile, pages: pages);
  }

  /// Exports an Edit Session to a new PDF natively without rasterizing unmodified pages
  static Future<File> saveSession({
    required PdfEditSession session,
    String? safDirectoryUri,
    String? outputName,
  }) async {
    final targetDoc = sf_pdf.PdfDocument();
    final Map<String, sf_pdf.PdfDocument> openedSourceDocs = {};

    try {
      for (final pageModel in session.pages) {
        if (pageModel.newImageFilePath != null &&
            File(pageModel.newImageFilePath!).existsSync()) {
          // 1. Page added from a new image
          final imgBytes =
              await File(pageModel.newImageFilePath!).readAsBytes();
          final bitmap = sf_pdf.PdfBitmap(imgBytes);
          final page = targetDoc.pages.add();
          page.graphics.drawImage(
            bitmap,
            Rect.fromLTWH(
              0,
              0,
              page.getClientSize().width,
              page.getClientSize().height,
            ),
          );
        } else if (pageModel.cachedImagePath != null &&
            File(pageModel.cachedImagePath!).existsSync()) {
          // 2. Page modified / cropped / edited as an image
          final imgBytes =
              await File(pageModel.cachedImagePath!).readAsBytes();
          final bitmap = sf_pdf.PdfBitmap(imgBytes);
          final page = targetDoc.pages.add();
          page.graphics.drawImage(
            bitmap,
            Rect.fromLTWH(
              0,
              0,
              page.getClientSize().width,
              page.getClientSize().height,
            ),
          );
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
            final newPage = targetDoc.pages.add();
            newPage.graphics.drawPdfTemplate(
              template,
              Offset.zero,
              Size(newPage.getClientSize().width, newPage.getClientSize().height),
            );

            // If there are vector drawing paths added in PDF Reader annotations:
            if (pageModel.drawings.isNotEmpty) {
              for (final drawing in pageModel.drawings) {
                if (drawing.points.isEmpty) continue;
                final pen = sf_pdf.PdfPen(
                  sf_pdf.PdfColor(
                    (drawing.color.r * 255).round().clamp(0, 255),
                    (drawing.color.g * 255).round().clamp(0, 255),
                    (drawing.color.b * 255).round().clamp(0, 255),
                    drawing.isHighlighter ? 100 : 255,
                  ),
                  width: drawing.strokeWidth,
                );
                pen.lineCap = sf_pdf.PdfLineCap.round;
                pen.lineJoin = sf_pdf.PdfLineJoin.round;

                for (int i = 0; i < drawing.points.length - 1; i++) {
                  newPage.graphics.drawLine(
                    pen,
                    drawing.points[i],
                    drawing.points[i + 1],
                  );
                }
              }
            }

            // Draw image and shape overlays
            _drawOverlaysOnPdfPage(newPage, pageModel.overlays);
          } else {
            targetDoc.pages.add();
          }
        } else {
          // 4. Blank page
          targetDoc.pages.add();
        }
      }

      final docBytes = Uint8List.fromList(targetDoc.saveSync());

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
    } finally {
      for (final doc in openedSourceDocs.values) {
        doc.dispose();
      }
      targetDoc.dispose();
    }
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
        final pen = sf_pdf.PdfPen(
          sf_pdf.PdfColor(
            (overlay.strokeColor.r * 255).round().clamp(0, 255),
            (overlay.strokeColor.g * 255).round().clamp(0, 255),
            (overlay.strokeColor.b * 255).round().clamp(0, 255),
            (overlay.opacity * 255).round().clamp(0, 255),
          ),
          width: overlay.strokeWidth,
        );
        final brush = overlay.isFilled && overlay.fillColor != Colors.transparent
            ? sf_pdf.PdfSolidBrush(
                sf_pdf.PdfColor(
                  (overlay.fillColor.r * 255).round().clamp(0, 255),
                  (overlay.fillColor.g * 255).round().clamp(0, 255),
                  (overlay.fillColor.b * 255).round().clamp(0, 255),
                  (overlay.opacity * 255).round().clamp(0, 255),
                ),
              )
            : null;

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
      }
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
  }) async {
    final fileBytes = await pdfFile.readAsBytes();
    final sourceDoc = sf_pdf.PdfDocument(inputBytes: fileBytes);
    final List<File> outputFiles = [];
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final baseName = pdfFile.path.split('/').last.replaceAll('.pdf', '');

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
}
