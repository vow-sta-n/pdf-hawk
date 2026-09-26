/*
 * PDF Hawk - Modern PDF Reader, Writer, Editor & Scanner
 * Copyright (C) 2026 Van Stan / Novaturients
 *
 * This software is licensed under the PolyForm Noncommercial License 1.0.0.
 * You may obtain a copy of the License at https://polyformproject.org/licenses/noncommercial/1.0.0
 */

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart' as pdf_types;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfhawk/data/res/theme.dart';
import 'package:pdfhawk/data/res/utils.dart';
import 'package:pdfhawk/interface/pages/FileViewers/pdf_reader_page.dart';
import 'package:pdfhawk/logic/services/storage_service.dart';

/// Universal helper class for compiling, previewing, and exporting images to PDF.
class ImageToPdfHelper {
  /// Decodes image dimensions from raw bytes.
  static Future<ui.Size?> _getImageDimensions(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final size = ui.Size(
        frame.image.width.toDouble(),
        frame.image.height.toDouble(),
      );
      frame.image.dispose();
      return size;
    } catch (e) {
      debugPrint("ImageToPdfHelper._getImageDimensions error: $e");
      return null;
    }
  }

  /// Low-level: Compiles a list of image file paths into raw PDF bytes.
  /// Bakes EXIF orientation and fits each page exactly to the image's dimensions.
  static Future<Uint8List> compileImagesToPdfBytes(
    List<String> imagePaths, {
    int quality = 92,
  }) async {
    final pdf = pw.Document();

    for (final path in imagePaths) {
      final file = File(path);
      if (!file.existsSync()) continue;

      final bytes = await file.readAsBytes();
      Uint8List imageBytes = bytes;
      ui.Size? size = await _getImageDimensions(bytes);

      // Ensure orientation is baked so PDF canvas and image dimensions match 1:1
      final decoded = img.decodeImage(bytes);
      if (decoded != null) {
        if (decoded.exif.imageIfd.hasOrientation &&
            decoded.exif.imageIfd.orientation != 1) {
          final baked = img.bakeOrientation(decoded);
          imageBytes = Uint8List.fromList(img.encodeJpg(baked, quality: quality));
          size = ui.Size(baked.width.toDouble(), baked.height.toDouble());
        } else {
          size = ui.Size(decoded.width.toDouble(), decoded.height.toDouble());
        }
      }

      final image = pw.MemoryImage(imageBytes);
      final double width = size?.width ?? pdf_types.PdfPageFormat.a4.width;
      final double height = size?.height ?? pdf_types.PdfPageFormat.a4.height;

      pdf.addPage(
        pw.Page(
          pageFormat: pdf_types.PdfPageFormat(
            width,
            height,
            marginLeft: 0,
            marginTop: 0,
            marginRight: 0,
            marginBottom: 0,
          ),
          margin: const pw.EdgeInsets.all(0),
          build: (pw.Context context) {
            return pw.FullPage(
              ignoreMargins: true,
              child: pw.Image(
                image,
                width: width,
                height: height,
                fit: pw.BoxFit.fill,
              ),
            );
          },
        ),
      );
    }

    return await pdf.save();
  }

  /// Compiles images into a temporary PDF file (useful for realtime preview or sharing).
  static Future<File> compileImagesToTempPdf(
    List<String> imagePaths, {
    int quality = 92,
    String? customTempPath,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final outPath =
        customTempPath ??
        "${tempDir.path}/preview_${DateTime.now().millisecondsSinceEpoch}.pdf";
    final file = File(outPath);
    final pdfBytes = await compileImagesToPdfBytes(imagePaths, quality: quality);
    await file.writeAsBytes(pdfBytes, flush: true);
    return file;
  }

  /// High-level universal export flow with UI:
  /// 1. Prompts user for filename.
  /// 2. Displays non-dismissible loading indicator.
  /// 3. Compiles images to PDF.
  /// 4. Saves to library storage via StorageService.
  /// 5. Shows confirmation SnackBar.
  /// 6. Optionally opens the resulting PDF in PDFReaderPage.
  static Future<File?> exportImagesToPdfDialog(
    BuildContext context, {
    required List<String> imagePaths,
    String? defaultFileName,
    bool openReaderOnSuccess = true,
  }) async {
    if (imagePaths.isEmpty) {
      Fluttertoast.showToast(msg: "Please select at least one image");
      return null;
    }

    final nameController = TextEditingController(
      text:
          defaultFileName ??
          "Document_${DateTime.now().millisecondsSinceEpoch}",
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bool? shouldExport = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E24) : white,
          shape: RoundedRectangleBorder(borderRadius: allradius(20.r)),
          title: Text(
            "Export PDF Document",
            style: GoogleFonts.outfit(
              color: isDark ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Enter filename for your ${imagePaths.length}-page PDF:",
                style: GoogleFonts.instrumentSans(
                  color: isDark ? Colors.white70 : Colors.black87,
                  fontSize: 13.sp,
                ),
              ),
              Gap(12.h),
              TextField(
                controller: nameController,
                autofocus: true,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  suffixText: ".pdf",
                  suffixStyle: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                  filled: true,
                  fillColor: isDark ? Colors.white10 : Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: allradius(12.r),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                "Cancel",
                style: TextStyle(
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: royalblue,
                foregroundColor: white,
                shape: RoundedRectangleBorder(borderRadius: allradius(12.r)),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Export"),
            ),
          ],
        );
      },
    );

    if (shouldExport != true) return null;

    if (!context.mounted) return null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E1E24) : white,
            shape: RoundedRectangleBorder(borderRadius: allradius(16.r)),
            content: Row(
              children: [
                const CircularProgressIndicator(color: royalblue),
                Gap(20.w),
                Expanded(
                  child: Text(
                    "Compiling and saving PDF document...",
                    style: GoogleFonts.outfit(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 14.sp,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    try {
      final pdfBytes = await compileImagesToPdfBytes(imagePaths, quality: 92);

      String filename = nameController.text.trim();
      if (!filename.toLowerCase().endsWith(".pdf")) {
        filename = "$filename.pdf";
      }

      final savedPdf = await StorageService.saveExportedFile(
        fileName: filename,
        bytes: pdfBytes,
      );

      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("PDF saved: ${savedPdf.path.split('/').last}"),
            backgroundColor: royalblue,
            behavior: SnackBarBehavior.floating,
          ),
        );

        if (openReaderOnSuccess) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PDFReaderPage(pdfFile: savedPdf),
            ),
          );
        }
      }

      return savedPdf;
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        Fluttertoast.showToast(msg: "Failed to export PDF: $e");
      }
      return null;
    }
  }
}
