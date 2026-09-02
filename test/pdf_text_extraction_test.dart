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
import 'package:pdfhawk/logic/helpers/pdf_helper.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf_pdf;

void main() {
  group('PDF Text Extraction & Models Tests', () {
    late Directory tempDir;
    late File testPdfFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('pdf_text_test_');
      testPdfFile = File('${tempDir.path}/sample.pdf');

      // Create a test PDF document with known text
      final document = sf_pdf.PdfDocument();
      final page = document.pages.add();
      final font = sf_pdf.PdfStandardFont(sf_pdf.PdfFontFamily.helvetica, 14);
      page.graphics.drawString(
        'Hello PDF Hawk World\nThis is selectable text for testing.',
        font,
        bounds: const Rect.fromLTWH(50, 50, 400, 100),
      );
      final bytes = document.saveSync();
      document.dispose();
      await testPdfFile.writeAsBytes(bytes);
    });

    tearDown(() async {
      PdfHelper.clearTextLinesCache();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('PdfTextLineModel and PdfTextWordModel initialize correctly', () {
      const word = PdfTextWordModel(
        text: 'Hawk',
        bounds: Rect.fromLTWH(10, 20, 30, 15),
      );
      expect(word.text, 'Hawk');
      expect(word.bounds.left, 10);

      const line = PdfTextLineModel(
        text: 'Hello PDF Hawk',
        bounds: Rect.fromLTWH(10, 20, 200, 15),
        fontSize: 14.0,
        pageNumber: 1,
        words: [word],
      );
      expect(line.text, 'Hello PDF Hawk');
      expect(line.fontSize, 14.0);
      expect(line.words.length, 1);
    });

    test('extractTextContent extracts plain text accurately', () async {
      final text = await PdfHelper.extractTextContent(
        pdfFile: testPdfFile,
        pageNumber: 1,
      );
      expect(text, contains('Hello PDF Hawk World'));
      expect(text, contains('This is selectable text for testing.'));
    });

    test('extractPageTextLines extracts lines and bounds with caching', () async {
      final lines = await PdfHelper.extractPageTextLines(
        pdfFile: testPdfFile,
        pageNumber: 1,
      );

      expect(lines.isNotEmpty, true);
      expect(lines.first.text, contains('Hello PDF Hawk World'));
      expect(lines.first.bounds.width > 0, true);

      // Verify cached retrieval
      final cachedLines = await PdfHelper.extractPageTextLines(
        pdfFile: testPdfFile,
        pageNumber: 1,
      );
      expect(cachedLines.length, equals(lines.length));
    });
  });
}
