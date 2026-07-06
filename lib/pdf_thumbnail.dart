import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'package:path/path.dart' as p;

Future<File> generatePdfThumbnail(File pdfFile) async {
  final thumbPath = p.setExtension(pdfFile.path, '.png');
  final thumbFile = File(thumbPath);

  if (await thumbFile.exists()) {
    return thumbFile;
  }

  final document = await PdfDocument.openFile(pdfFile.path);
  final page = await document.getPage(1);

  final image = await page.render(
    width: page.width * 0.4,
    height: page.height * 0.4,
    format: PdfPageImageFormat.png,
  );

  await thumbFile.writeAsBytes(image!.bytes);
  await page.close();
  await document.close();

  return thumbFile;
}

IconData getFileIcon(String path) {
  final lowerPath = path.toLowerCase();
  if (lowerPath.endsWith('.pdf')) {
    return Icons.picture_as_pdf;
  } else if (lowerPath.endsWith('.ppt') || lowerPath.endsWith('.pptx')) {
    return Icons.slideshow;
  } else if (lowerPath.endsWith('.doc') || lowerPath.endsWith('.docx')) {
    return Icons.description;
  }
  return Icons.insert_drive_file;
}

Color getFileColor(String path) {
  final lowerPath = path.toLowerCase();
  if (lowerPath.endsWith('.pdf')) {
    return Colors.red;
  } else if (lowerPath.endsWith('.ppt') || lowerPath.endsWith('.pptx')) {
    return Colors.orange;
  } else if (lowerPath.endsWith('.doc') || lowerPath.endsWith('.docx')) {
    return Colors.blue;
  }
  return Colors.grey;
}
