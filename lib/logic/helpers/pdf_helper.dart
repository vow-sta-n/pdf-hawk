// ignore_for_file: implementation_imports

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:pdf/pdf.dart' as pwa;
import 'package:pdf/widgets.dart' as pw;
import 'package:saf/src/storage_access_framework/api.dart';

/// Models for PDF drawing paths
class DrawingPath {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;
  final bool isHighlighter;

  DrawingPath({
    required this.points,
    required this.color,
    required this.strokeWidth,
    required this.isHighlighter,
  });

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

  /// Cached image file path of the page's original content (for rendering in UI)
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
  /// Loads a PDF file and initializes an Edit Session by rendering pages as cached PNGs
  static Future<PdfEditSession> startEditSession(File pdfFile) async {
    final pages = <PdfPageModel>[];
    final document = await pdfx.PdfDocument.openFile(pdfFile.path);
    final tempDir = await getTemporaryDirectory();

    for (int i = 0; i < document.pagesCount; i++) {
      final page = await document.getPage(i + 1);

      // Render page to high-res image (scale up to 1.5x width/height) for visual clarity
      final rendered = await page.render(
        width: page.width * 1.5,
        height: page.height * 1.5,
        format: pdfx.PdfPageImageFormat.png,
      );

      final cachedFile = File(
        '${tempDir.path}/page_${i + 1}_${DateTime.now().microsecondsSinceEpoch}.png',
      );
      if (rendered != null) {
        await cachedFile.writeAsBytes(rendered.bytes);
      }

      pages.add(
        PdfPageModel(
          originalPageIndex: i + 1,
          cachedImagePath: cachedFile.path,
          drawings: [],
          width: page.width.toDouble(),
          height: page.height.toDouble(),
        ),
      );

      await page.close();
    }

    await document.close();
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
      } else if (pageModel.cachedImagePath != null) {
        bgImageBytes = await File(pageModel.cachedImagePath!).readAsBytes();
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

    // 2. Save locally
    final appDocsDir = await getApplicationDocumentsDirectory();
    final name =
        outputName ??
        'edited_${session.originalFile.path.split('/').last.replaceAll('.pdf', '')}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final localOutputFile = File('${appDocsDir.path}/$name');
    await localOutputFile.writeAsBytes(docBytes);

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

    // Save locally
    final appDocsDir = await getApplicationDocumentsDirectory();
    final name =
        outputName ?? 'merged_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final localOutputFile = File('${appDocsDir.path}/$name');
    await localOutputFile.writeAsBytes(docBytes);

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
}
