import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfhawk/logic/helpers/document_converter.dart';
import 'package:image/image.dart' as img;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf_pdf;

import 'package:flutter/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return Directory.systemTemp.path;
      },
    );
  });

  test('Multi-image PDF creation and dynamic per-page dimension reading', () async {
    final tempDir = await Directory.systemTemp.createTemp('margin_test_');

    // Create Image 1 (Portrait 600x800)
    final img1 = img.Image(width: 600, height: 800);
    img.fill(img1, color: img.ColorRgb8(255, 0, 0));
    final file1 = File('${tempDir.path}/img1.jpg');
    await file1.writeAsBytes(img.encodeJpg(img1));

    // Create Image 2 (Landscape 1200x600)
    final img2 = img.Image(width: 1200, height: 600);
    img.fill(img2, color: img.ColorRgb8(0, 255, 0));
    final file2 = File('${tempDir.path}/img2.jpg');
    await file2.writeAsBytes(img.encodeJpg(img2));

    // Convert both images to PDF
    final pdfFile = await DocumentConverter.convertImagesToPdf([file1, file2]);
    final pdfBytes = await pdfFile.readAsBytes();

    final doc = sf_pdf.PdfDocument(inputBytes: pdfBytes);
    expect(doc.pages.count, equals(2));

    // Check Page 1 size matches img1
    expect(doc.pages[0].size.width, equals(600.0));
    expect(doc.pages[0].size.height, equals(800.0));

    // Check Page 2 size matches img2
    expect(doc.pages[1].size.width, equals(1200.0));
    expect(doc.pages[1].size.height, equals(600.0));
    doc.dispose();

    await tempDir.delete(recursive: true);
  });
}
