/*
 * PDF Hawk - Modern PDF Reader, Writer, Editor & Scanner
 * Copyright (C) 2026 Van Stan / Novaturients
 *
 * This software is licensed under the PolyForm Noncommercial License 1.0.0.
 * You may obtain a copy of the License at https://polyformproject.org/licenses/noncommercial/1.0.0
 */

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdfhawk/logic/helpers/pdf_helper.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf_pdf;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('PDF Text Selection & Highlight Overlay Tests', () {
    late Directory tempDir;
    late File samplePdfFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('pdf_selection_test_');
      samplePdfFile = File('${tempDir.path}/text_doc.pdf');

      final document = sf_pdf.PdfDocument();
      final page = document.pages.add();
      final font = sf_pdf.PdfStandardFont(sf_pdf.PdfFontFamily.helvetica, 14);
      page.graphics.drawString(
        'Flutter Selectable Text Hawk',
        font,
        bounds: const Rect.fromLTWH(50, 80, 400, 50),
      );
      final bytes = document.saveSync();
      document.dispose();
      await samplePdfFile.writeAsBytes(bytes);
    });

    tearDown(() async {
      PdfHelper.clearTextLinesCache();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('PdfTextLineModel correctly identifies word hits at coordinates', () async {
      final lines = await PdfHelper.extractPageTextLines(pdfFile: samplePdfFile, pageNumber: 1);
      expect(lines.isNotEmpty, true);

      final firstLine = lines.first;
      expect(firstLine.words.isNotEmpty, true);

      // Hit-test on the first word 'Flutter'
      final targetWord = firstLine.words.first;
      final touchPos = targetWord.bounds.center;

      PdfTextWordModel? hitWord;
      for (final line in lines) {
        for (final word in line.words) {
          if (word.bounds.inflate(4.0).contains(touchPos)) {
            hitWord = word;
            break;
          }
        }
        if (hitWord != null) break;
      }

      expect(hitWord, isNotNull);
      expect(hitWord!.text, 'Flutter');
    });

    test('DrawingPath highlighter creation from text bounds generates valid stroke', () {
      const textBounds = Rect.fromLTWH(50, 100, 200, 16);
      final strokeY = textBounds.center.dy;
      final highlighter = DrawingPath(
        points: [
          Offset(textBounds.left, strokeY),
          Offset(textBounds.right, strokeY),
        ],
        color: const Color(0xFFFFEB3B).withValues(alpha: 0.5),
        strokeWidth: textBounds.height,
        isHighlighter: true,
      );

      expect(highlighter.isHighlighter, true);
      expect(highlighter.points.length, 2);
      expect(highlighter.strokeWidth, 16.0);
      expect(highlighter.points.first, const Offset(50, 108));
      expect(highlighter.points.last, const Offset(250, 108));
    });

    test('Multi-word bounding box aggregation calculates accurate bounding rect', () {
      const w1 = PdfTextWordModel(text: 'Hello', bounds: Rect.fromLTWH(10, 20, 30, 12));
      const w2 = PdfTextWordModel(text: 'World', bounds: Rect.fromLTWH(45, 20, 35, 12));
      final selectedWords = [w1, w2];

      double minX = double.infinity;
      double minY = double.infinity;
      double maxX = -double.infinity;
      double maxY = -double.infinity;

      for (final w in selectedWords) {
        if (w.bounds.left < minX) minX = w.bounds.left;
        if (w.bounds.top < minY) minY = w.bounds.top;
        if (w.bounds.right > maxX) maxX = w.bounds.right;
        if (w.bounds.bottom > maxY) maxY = w.bounds.bottom;
      }

      final combined = Rect.fromLTRB(minX, minY, maxX, maxY);
      expect(combined, const Rect.fromLTWH(10, 20, 70, 12));
      expect(selectedWords.map((w) => w.text).join(' '), 'Hello World');
    });
  });
}
