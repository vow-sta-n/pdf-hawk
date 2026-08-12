/*
 * PDF Hawk - Modern PDF Reader, Writer, Editor & Scanner
 * Copyright (C) 2026 Van Stan / Novaturients
 *
 * This software is licensed under the PolyForm Noncommercial License 1.0.0.
 * You may obtain a copy of the License at https://polyformproject.org/licenses/noncommercial/1.0.0
 */

import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart' as pdf_types;
import 'package:pdf/widgets.dart' as pw;

class DocumentConverter {
  /// Converts docx, pptx, or txt files to a PDF file locally and returns the output PDF file.
  static Future<File> convertToPdf(File sourceFile) async {
    final extension = sourceFile.path.split('.').last.toLowerCase();
    final pdf = pw.Document();

    if (extension == 'txt') {
      final text = await sourceFile.readAsString(encoding: utf8);
      pdf.addPage(
        pw.MultiPage(
          pageFormat: pdf_types.PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return [
              pw.Text(
                text,
                style: const pw.TextStyle(fontSize: 11),
              ),
            ];
          },
        ),
      );
    } else if (extension == 'jpg' || extension == 'jpeg' || extension == 'png') {
      final bytes = await sourceFile.readAsBytes();
      final image = pw.MemoryImage(bytes);
      pdf.addPage(
        pw.Page(
          pageFormat: pdf_types.PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(0),
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Image(image, fit: pw.BoxFit.contain),
            );
          },
        ),
      );
    } else if (extension == 'docx') {
      final bytes = await sourceFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      final docFile = archive.findFile('word/document.xml');
      if (docFile == null) {
        throw Exception("Not a valid DOCX file (missing word/document.xml)");
      }

      final xmlContent = utf8.decode(docFile.content as List<int>);

      final pRegExp = RegExp(r'<w:p\b[^>]*>(.*?)</w:p>', dotAll: true);
      final rRegExp = RegExp(r'<w:r\b[^>]*>(.*?)</w:r>', dotAll: true);
      final rPrRegExp = RegExp(r'<w:rPr\b[^>]*>(.*?)</w:rPr>', dotAll: true);
      final tRegExp = RegExp(r'<w:t\b[^>]*>(.*?)</w:t>', dotAll: true);
      final pPrRegExp = RegExp(r'<w:pPr\b[^>]*>(.*?)</w:pPr>', dotAll: true);
      final pStyleRegExp = RegExp(r'<w:pStyle\b[^>]*w:val="([^"]*)"');
      final colorRegExp = RegExp(r'<w:color\b[^>]*w:val="([^"]*)"');
      final spacingRegExp = RegExp(r'<w:spacing\b[^>]*/?>');
      final beforeRegExp = RegExp(r'w:before="([^"]*)"');
      final afterRegExp = RegExp(r'w:after="([^"]*)"');

      final List<pw.Widget> pdfWidgets = [];

      for (final pMatch in pRegExp.allMatches(xmlContent)) {
        final pBody = pMatch.group(1) ?? '';

        // Check paragraph properties for headers and spacing
        int? headerLevel;
        double? spaceBefore;
        double? spaceAfter;
        final pPrMatch = pPrRegExp.firstMatch(pBody);
        if (pPrMatch != null) {
          final pPrBody = pPrMatch.group(1) ?? '';
          final styleMatch = pStyleRegExp.firstMatch(pPrBody);
          if (styleMatch != null) {
            final styleVal = styleMatch.group(1)?.toLowerCase() ?? '';
            if (styleVal.contains('heading1') ||
                styleVal == 'heading 1' ||
                styleVal == 'h1') {
              headerLevel = 1;
            } else if (styleVal.contains('heading2') ||
                styleVal == 'heading 2' ||
                styleVal == 'h2') {
              headerLevel = 2;
            } else if (styleVal.contains('heading3') ||
                styleVal == 'heading 3' ||
                styleVal == 'h3') {
              headerLevel = 3;
            }
          }
          final spacingMatch = spacingRegExp.firstMatch(pPrBody);
          if (spacingMatch != null) {
            final spacingTag = spacingMatch.group(0) ?? '';
            final beforeMatch = beforeRegExp.firstMatch(spacingTag);
            if (beforeMatch != null) {
              final beforeVal = double.tryParse(beforeMatch.group(1) ?? '');
              if (beforeVal != null) {
                spaceBefore = beforeVal / 20.0;
              }
            }
            final afterMatch = afterRegExp.firstMatch(spacingTag);
            if (afterMatch != null) {
              final afterVal = double.tryParse(afterMatch.group(1) ?? '');
              if (afterVal != null) {
                spaceAfter = afterVal / 20.0;
              }
            }
          }
        }

        final spans = <pw.InlineSpan>[];
        bool hasContent = false;

        for (final rMatch in rRegExp.allMatches(pBody)) {
          final rBody = rMatch.group(1) ?? '';

          // Parse run properties
          bool bold = false;
          bool italic = false;
          bool underline = false;
          bool strike = false;
          pdf_types.PdfColor? color;

          final rPrMatch = rPrRegExp.firstMatch(rBody);
          if (rPrMatch != null) {
            final rPrBody = rPrMatch.group(1) ?? '';
            if (rPrBody.contains('<w:b/>') ||
                rPrBody.contains('<w:b ') ||
                rPrBody.contains('<w:bCs/>') ||
                rPrBody.contains('<w:bCs ')) {
              bold = true;
            }
            if (rPrBody.contains('<w:i/>') ||
                rPrBody.contains('<w:i ') ||
                rPrBody.contains('<w:iCs/>') ||
                rPrBody.contains('<w:iCs ')) {
              italic = true;
            }
            if (rPrBody.contains('<w:u ') || rPrBody.contains('<w:u/>')) {
              underline = true;
            }
            if (rPrBody.contains('<w:strike') ||
                rPrBody.contains('<w:dstrike')) {
              strike = true;
            }
            final colorMatch = colorRegExp.firstMatch(rPrBody);
            if (colorMatch != null) {
              final colorVal = colorMatch.group(1);
              if (colorVal != null && colorVal.length == 6) {
                try {
                  color = pdf_types.PdfColor.fromHex(colorVal);
                } catch (_) {}
              }
            }
          }

          // Extract text inside the run
          final tBuffer = StringBuffer();
          for (final tMatch in tRegExp.allMatches(rBody)) {
            var txt = tMatch.group(1) ?? '';
            txt = txt
                .replaceAll('&amp;', '&')
                .replaceAll('&lt;', '<')
                .replaceAll('&gt;', '>')
                .replaceAll('&quot;', '"')
                .replaceAll('&apos;', "'");
            tBuffer.write(txt);
          }
          final rText = tBuffer.toString();
          if (rText.isNotEmpty) {
            final font = bold
                ? pw.Font.helveticaBold()
                : (italic ? pw.Font.helveticaOblique() : pw.Font.helvetica());

            spans.add(
              pw.TextSpan(
                text: rText,
                style: pw.TextStyle(
                  font: font,
                  fontStyle: italic ? pw.FontStyle.italic : pw.FontStyle.normal,
                  decoration: pw.TextDecoration.combine([
                    if (underline) pw.TextDecoration.underline,
                    if (strike) pw.TextDecoration.lineThrough,
                  ]),
                  color: color ?? pdf_types.PdfColors.black,
                ),
              ),
            );
            hasContent = true;
          }
        }

        // Fallback for raw text without runs
        if (!hasContent) {
          final tBuffer = StringBuffer();
          for (final tMatch in tRegExp.allMatches(pBody)) {
            var txt = tMatch.group(1) ?? '';
            txt = txt
                .replaceAll('&amp;', '&')
                .replaceAll('&lt;', '<')
                .replaceAll('&gt;', '>')
                .replaceAll('&quot;', '"')
                .replaceAll('&apos;', "'");
            tBuffer.write(txt);
          }
          final pText = tBuffer.toString().trim();
          if (pText.isNotEmpty) {
            spans.add(pw.TextSpan(text: pText));
            hasContent = true;
          }
        }

        if (hasContent || headerLevel != null || spaceBefore != null || spaceAfter != null) {
          double fontSize = 11.0;
          bool isBold = false;
          if (headerLevel == 1) {
            fontSize = 22.0;
            isBold = true;
          } else if (headerLevel == 2) {
            fontSize = 17.0;
            isBold = true;
          } else if (headerLevel == 3) {
            fontSize = 14.0;
            isBold = true;
          }

          final font = isBold ? pw.Font.helveticaBold() : pw.Font.helvetica();
          final double beforePadding = spaceBefore ?? 0.0;
          final double afterPadding = spaceAfter ?? (headerLevel != null ? 12.0 : 8.0);

          pdfWidgets.add(
            pw.Container(
              margin: pw.EdgeInsets.only(top: beforePadding, bottom: afterPadding),
              child: pw.RichText(
                text: pw.TextSpan(
                  style: pw.TextStyle(
                    font: font,
                    fontSize: fontSize,
                    color: pdf_types.PdfColors.black,
                  ),
                  children: spans,
                ),
              ),
            ),
          );
        }
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: pdf_types.PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return pdfWidgets;
          },
        ),
      );
    } else if (extension == 'pptx') {
      final bytes = await sourceFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      // Find all slide xml files
      final slideFiles = archive
          .where((file) => RegExp(r'^ppt/slides/slide\d+\.xml$').hasMatch(file.name))
          .toList();

      if (slideFiles.isEmpty) {
        throw Exception("Not a valid PPTX file (no slides found)");
      }

      // Sort slides by sequential number
      slideFiles.sort((a, b) {
        final aNum = int.tryParse(RegExp(r'\d+').firstMatch(a.name)?.group(0) ?? '0') ?? 0;
        final bNum = int.tryParse(RegExp(r'\d+').firstMatch(b.name)?.group(0) ?? '0') ?? 0;
        return aNum.compareTo(bNum);
      });

      final tRegExp = RegExp(r'<a:t\b[^>]*>(.*?)</a:t>');

      for (int i = 0; i < slideFiles.length; i++) {
        final xmlContent = utf8.decode(slideFiles[i].content as List<int>);
        final tBuffer = StringBuffer();

        for (final tMatch in tRegExp.allMatches(xmlContent)) {
          var txt = tMatch.group(1) ?? '';
          txt = txt
              .replaceAll('&amp;', '&')
              .replaceAll('&lt;', '<')
              .replaceAll('&gt;', '>')
              .replaceAll('&quot;', '"')
              .replaceAll('&apos;', "'");
          tBuffer.write(txt);
          tBuffer.write(' ');
        }

        final slideText = tBuffer.toString().trim();

        pdf.addPage(
          pw.Page(
            pageFormat: pdf_types.PdfPageFormat.a4.landscape,
            margin: const pw.EdgeInsets.all(32),
            build: (pw.Context context) {
              return pw.Container(
                padding: const pw.EdgeInsets.all(24),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(
                    color: pdf_types.PdfColor.fromHex('#EDB61F'),
                    width: 2,
                  ),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      "Slide ${i + 1}",
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: pdf_types.PdfColor.fromHex('#EDB61F'),
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Divider(color: pdf_types.PdfColor.fromHex('#EDB61F'), thickness: 1),
                    pw.SizedBox(height: 14),
                    pw.Expanded(
                      child: pw.Text(
                        slideText.isNotEmpty ? slideText : "[Empty Slide]",
                        style: const pw.TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      }
    } else {
      throw Exception("Unsupported document type: .$extension");
    }

    final outputDir = await getApplicationDocumentsDirectory();
    final fileName = sourceFile.path.split('/').last.split('.').first;
    final outputFile = File(
      "${outputDir.path}/${fileName}_Converted_${DateTime.now().millisecondsSinceEpoch}.pdf",
    );
    await outputFile.writeAsBytes(await pdf.save());
    return outputFile;
  }

  /// Converts a list of image files to a single PDF file locally and returns the output PDF file.
  static Future<File> convertImagesToPdf(List<File> imageFiles) async {
    final pdf = pw.Document();

    for (final file in imageFiles) {
      final bytes = await file.readAsBytes();
      final image = pw.MemoryImage(bytes);
      pdf.addPage(
        pw.Page(
          pageFormat: pdf_types.PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(0),
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Image(image, fit: pw.BoxFit.contain),
            );
          },
        ),
      );
    }

    final outputDir = await getApplicationDocumentsDirectory();
    final firstFileName = imageFiles.isNotEmpty
        ? imageFiles.first.path.split('/').last.split('.').first
        : 'images';
    final outputFile = File(
      "${outputDir.path}/${firstFileName}_ImagesConverted_${DateTime.now().millisecondsSinceEpoch}.pdf",
    );
    await outputFile.writeAsBytes(await pdf.save());
    return outputFile;
  }
}

