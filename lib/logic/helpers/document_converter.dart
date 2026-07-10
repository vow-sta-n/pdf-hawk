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

      // Extract paragraphs (<w:p>) and text runs (<w:t>) using regex
      final pRegExp = RegExp(r'<w:p\b[^>]*>(.*?)</w:p>');
      final tRegExp = RegExp(r'<w:t\b[^>]*>(.*?)</w:t>');

      final paragraphs = <String>[];
      for (final pMatch in pRegExp.allMatches(xmlContent)) {
        final pBody = pMatch.group(1) ?? '';
        final tBuffer = StringBuffer();
        for (final tMatch in tRegExp.allMatches(pBody)) {
          var txt = tMatch.group(1) ?? '';
          // Decode simple XML entities
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
          paragraphs.add(pText);
        }
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: pdf_types.PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return paragraphs.map((text) {
              return pw.Paragraph(
                text: text,
                style: const pw.TextStyle(fontSize: 11),
                margin: const pw.EdgeInsets.only(bottom: 8),
              );
            }).toList();
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

