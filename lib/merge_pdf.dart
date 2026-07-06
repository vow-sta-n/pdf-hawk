import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart' as pwa;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf_render_plus/pdf_render.dart';

Future<File> appendPdfToPdf({
  required File basePdf,
  required File pdfToAppend,
}) async {
  final doc = pw.Document();

  /// Helper to render and add pages
  Future<void> addPdfPages(File pdfFile) async {
    final pdf = await PdfDocument.openFile(pdfFile.path);

    for (int i = 0; i < pdf.pageCount; i++) {
      final page = await pdf.getPage(i + 1);

      final image = await page.render(
        width: page.width.toInt(),
        height: page.height.toInt(),
        // format: PdfPageImageFormat.png,
      );

      doc.addPage(
        pw.Page(
          pageFormat: pwa.PdfPageFormat(
            page.width.toDouble(),
            page.height.toDouble(),
          ),
          build: (_) => pw.Image(
            pw.MemoryImage(image.pixels),
            fit: pw.BoxFit.contain,
          ),
        ),
      );

      await page.document.dispose();
    }

    await pdf.dispose();
  }

  // 1️⃣ Add base PDF pages
  await addPdfPages(basePdf);

  // 2️⃣ Append second PDF pages
  await addPdfPages(pdfToAppend);

  // 3️⃣ Save result
  final dir = await getApplicationDocumentsDirectory();
  final output = File(
    '${dir.path}/merged_${DateTime.now().millisecondsSinceEpoch}.pdf',
  );

  await output.writeAsBytes(await doc.save());
  return output;
}
