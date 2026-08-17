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
import 'package:pdfhawk/interface/widgets/pdf_page_renderer.dart';
import 'package:pdfhawk/logic/services/storage_service.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:pdf/pdf.dart' as pwa;
import 'package:pdf/widgets.dart' as pw;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:saf/src/storage_access_framework/api.dart';

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
    required this.width,
    required this.height,
  }) : id = id ?? UniqueKey().toString();
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

  /// Exports an Edit Session to a new PDF and saves it locally and optionally to SAF default folder
  static Future<File> saveSession({
    required PdfEditSession session,
    String? safDirectoryUri,
    String? outputName,
  }) async {
    final doc = pw.Document();

    for (final pageModel in session.pages) {
      // 1. Get background image bytes
      List<int> bgImageBytes;
      if (pageModel.newImageFilePath != null) {
        bgImageBytes = await File(pageModel.newImageFilePath!).readAsBytes();
      } else if (pageModel.cachedImagePath != null &&
          File(pageModel.cachedImagePath!).existsSync()) {
        bgImageBytes = await File(pageModel.cachedImagePath!).readAsBytes();
      } else if (pageModel.originalPageIndex != null) {
        // Render on demand if exporting
        final sourceFile = pageModel.sourcePdfFile ?? session.originalFile;
        final bytes = await PdfPageImageRenderer.renderPageBytes(
          pdfPath: sourceFile.path,
          pageNumber: pageModel.originalPageIndex!,
          scale: 1.5,
        );
        bgImageBytes = bytes != null ? List<int>.from(bytes) : [];
      } else {
        // Create white blank page bytes
        bgImageBytes = []; // we will draw a white background rectangle instead
      }

      final pageFormat = pwa.PdfPageFormat(pageModel.width, pageModel.height);

      doc.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: pw.EdgeInsets.zero,
          build: (context) {
            return pw.Stack(
              children: [
                // Background Page Image or blank white page
                if (bgImageBytes.isNotEmpty)
                  pw.Positioned.fill(
                    child: pw.Image(
                      pw.MemoryImage(Uint8List.fromList(bgImageBytes)),
                      fit: pw.BoxFit.fill,
                    ),
                  )
                else
                  pw.Positioned.fill(
                    child: pw.Container(color: pwa.PdfColors.white),
                  ),

                // Draw Vector Annotations on Top
                if (pageModel.drawings.isNotEmpty)
                  pw.Positioned.fill(
                    child: pw.CustomPaint(
                      painter: (canvas, size) {
                        for (final drawing in pageModel.drawings) {
                          if (drawing.points.isEmpty) continue;

                          // Setup drawing style
                          final pdfColor = pwa.PdfColor(
                            drawing.color.r,
                            drawing.color.g,
                            drawing.color.b,
                            drawing.isHighlighter ? 0.4 : 1.0,
                          );

                          canvas
                            ..setStrokeColor(pdfColor)
                            ..setLineWidth(drawing.strokeWidth)
                            ..setLineCap(pwa.PdfLineCap.round)
                            ..setLineJoin(pwa.PdfLineJoin.round);

                          // In PDF graphics, Y origin is bottom-left, Flutter is top-left
                          final startPoint = drawing.points.first;
                          canvas.moveTo(
                            startPoint.dx,
                            pageModel.height - startPoint.dy,
                          );

                          for (int i = 1; i < drawing.points.length; i++) {
                            final pt = drawing.points[i];
                            canvas.lineTo(pt.dx, pageModel.height - pt.dy);
                          }

                          canvas.strokePath();
                        }
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      );
    }

    final docBytes = await doc.save();

    // 2. Save locally to PDFHawk storage folder
    final name =
        outputName ??
        'edited_${session.originalFile.path.split('/').last.replaceAll('.pdf', '')}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final localOutputFile = await StorageService.saveExportedFile(
      fileName: name,
      bytes: docBytes,
    );

    // 3. Save to Storage Access Framework (SAF) folder on Android
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

  /// Merges multiple PDF files into a single PDF
  static Future<File> mergePdfs({
    required List<File> pdfFiles,
    String? safDirectoryUri,
    String? outputName,
  }) async {
    final doc = pw.Document();

    for (final file in pdfFiles) {
      final document = await pdfx.PdfDocument.openFile(file.path);
      for (int i = 0; i < document.pagesCount; i++) {
        final page = await document.getPage(i + 1);

        // Render each page as high-res PNG
        final rendered = await page.render(
          width: page.width * 1.5,
          height: page.height * 1.5,
          format: pdfx.PdfPageImageFormat.png,
        );

        if (rendered != null) {
          doc.addPage(
            pw.Page(
              pageFormat: pwa.PdfPageFormat(
                page.width.toDouble(),
                page.height.toDouble(),
              ),
              margin: pw.EdgeInsets.zero,
              build: (_) =>
                  pw.Image(pw.MemoryImage(rendered.bytes), fit: pw.BoxFit.fill),
            ),
          );
        }

        await page.close();
      }
      await document.close();
    }

    final docBytes = await doc.save();

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
  }

  /// Splits a PDF file into multiple PDF files based on specified page ranges (1-based [startPage, endPage]).
  static Future<List<File>> splitPdf({
    required File pdfFile,
    required List<List<int>> ranges,
    String? safDirectoryUri,
  }) async {
    final document = await pdfx.PdfDocument.openFile(pdfFile.path);
    final List<File> outputFiles = [];
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final baseName = pdfFile.path.split('/').last.replaceAll('.pdf', '');

    for (int partIdx = 0; partIdx < ranges.length; partIdx++) {
      final range = ranges[partIdx];
      final startPage = range[0];
      final endPage = range[1];

      final doc = pw.Document();

      for (int p = startPage; p <= endPage; p++) {
        if (p >= 1 && p <= document.pagesCount) {
          final page = await document.getPage(p);
          final rendered = await page.render(
            width: page.width * 1.5,
            height: page.height * 1.5,
            format: pdfx.PdfPageImageFormat.png,
          );
          await page.close();

          if (rendered != null) {
            doc.addPage(
              pw.Page(
                pageFormat: pwa.PdfPageFormat(
                  page.width.toDouble(),
                  page.height.toDouble(),
                ),
                margin: pw.EdgeInsets.zero,
                build: (_) => pw.Image(
                  pw.MemoryImage(rendered.bytes),
                  fit: pw.BoxFit.fill,
                ),
              ),
            );
          }
        }
      }

      final docBytes = await doc.save();
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

    await document.close();

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
