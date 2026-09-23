/*
 * PDF Hawk - Modern PDF Reader, Writer, Editor & Scanner
 * Copyright (C) 2026 Van Stan / Novaturients
 *
 * This software is licensed under the PolyForm Noncommercial License 1.0.0.
 * You may obtain a copy of the License at https://polyformproject.org/licenses/noncommercial/1.0.0
 */

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import 'package:pdfhawk/data/models/device_document_model.dart';
import 'package:pdfhawk/data/models/writer_document_model.dart';
import 'package:pdfhawk/data/res/utils.dart';
import 'package:pdfhawk/data/res/enum.dart';
import 'package:pdfhawk/data/res/theme.dart';
import 'package:pdfhawk/interface/pages/FileViewers/image_viewer_page.dart';
import 'package:pdfhawk/interface/pages/FileViewers/pdf_reader_page.dart';
import 'package:pdfhawk/interface/pages/ScanAndCreate/pdf_writer_page.dart';
import 'package:pdfhawk/logic/helpers/document_converter.dart';
import 'package:pdfhawk/logic/services/device_documents_service.dart';
import 'package:pdfhawk/logic/services/hawk_crypto_service.dart';
import 'package:pdfhawk/interface/pages/home/recent_files.dart';

class DocumentViewerHelper {
  /// Opens any supported document in its dedicated read-only viewer mode.
  /// - PDF: Opens in PDFReaderPage
  /// - Images (JPG, PNG, WebP, BMP, GIF): Opens in ImageViewerPage
  /// - Office / Text (DOCX, PPTX, TXT, MD, LOG): Converts to cached preview PDF and opens in PDFReaderPage
  /// - Hawk (.hawk): Decrypts and opens in PdfWriterPage
  static Future<void> openDocument(
    BuildContext context,
    File file, {
    DeviceDocumentModel? doc,
    VoidCallback? onReturn,
  }) async {
    if (!file.existsSync()) {
      Fluttertoast.showToast(msg: "File no longer exists at path");
      return;
    }

    final ext = p.extension(file.path).toLowerCase().replaceAll('.', '');
    final category =
        doc?.category ?? DeviceDocumentsService.getCategoryForExtension(ext);

    // 1. PDF
    if (category == DocumentCategory.pdf || ext == 'pdf') {
      await _recordRecentFile(file.path);
      if (!context.mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => PDFReaderPage(pdfFile: file)),
      );
      onReturn?.call();
      return;
    }

    // 2. Images (Instant InteractiveViewer read-only preview)
    if (category == DocumentCategory.image ||
        const {'jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp'}.contains(ext)) {
      if (!context.mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ImageViewerPage(imageFile: file),
        ),
      );
      onReturn?.call();
      return;
    }

    // 3. Hawk proprietary file
    if (category == DocumentCategory.hawk || ext == 'hawk') {
      try {
        final jsonMap = await HawkCryptoService.readHawkFile(file);
        final writerDoc = WriterDocumentModel.fromJson(jsonMap);
        if (!context.mounted) return;
        final isAuto =
            p.basename(file.path).toLowerCase().startsWith('autosaved_');
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PdfWriterPage(
              initialDeltaJson: writerDoc.quillDeltaJson,
              initialOverlays: writerDoc.overlays,
              sourceHawkFile: file,
              isAutoSaved: isAuto,
            ),
          ),
        );
        onReturn?.call();
      } catch (e) {
        Fluttertoast.showToast(msg: "Error opening .hawk document: $e");
      }
      return;
    }

    // 4. Word (.docx), PowerPoint (.pptx), Plain Text (.txt, .md, .log, .rtf)
    if (ext == 'docx' ||
        ext == 'pptx' ||
        ext == 'txt' ||
        ext == 'md' ||
        ext == 'log' ||
        ext == 'rtf' ||
        category == DocumentCategory.word ||
        category == DocumentCategory.ppt ||
        category == DocumentCategory.text) {
      // Legacy binary formats need special notice
      if (ext == 'doc' || ext == 'dot' || ext == 'ppt' || ext == 'pot') {
        _showLegacyFormatNotice(context, ext);
        return;
      }

      await _openWithPreviewConversion(
        context,
        file,
        ext.toUpperCase(),
        onReturn: onReturn,
      );
      return;
    }

    // 5. Fallback
    Fluttertoast.showToast(msg: "Opening .${ext.toUpperCase()} is not supported");
  }

  static Future<void> _recordRecentFile(String path) async {
    await addRecentFile(path);
  }

  static Future<void> _openWithPreviewConversion(
    BuildContext context,
    File file,
    String typeLabel, {
    VoidCallback? onReturn,
  }) async {
    // Show sleek loading dialog
    bool isDialogDismissed = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        final theme = Theme.of(dialogCtx);
        final isDark = theme.brightness == Brightness.dark;
        return PopScope(
          canPop: false,
          child: Dialog(
            backgroundColor: isDark ? const Color(0xFF1E1E24) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: allradius(16.r)),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: royalblue,
                    ),
                  ),
                  Gap(18.w),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Loading $typeLabel...",
                          style: GoogleFonts.outfit(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        Gap(3.h),
                        Text(
                          "Preparing read-only view",
                          style: GoogleFonts.instrumentSans(
                            fontSize: 12.sp,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    try {
      final previewPdf = await DocumentConverter.convertToPreviewPdf(file);

      if (context.mounted) {
        isDialogDismissed = true;
        Navigator.of(context, rootNavigator: true).pop();
      }

      await _recordRecentFile(previewPdf.path);

      if (!context.mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PDFReaderPage(pdfFile: previewPdf),
        ),
      );
      onReturn?.call();
    } catch (e) {
      if (context.mounted && !isDialogDismissed) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      Fluttertoast.showToast(msg: "Error opening $typeLabel: $e");
    }
  }

  static void _showLegacyFormatNotice(BuildContext context, String ext) {
    final modernExt = ext.startsWith('doc') ? 'DOCX' : 'PPTX';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Legacy .${ext.toUpperCase()} File"),
        content: Text(
          "Binary .$ext files are a legacy format and cannot be rendered directly.\n\nPlease convert the file to modern .$modernExt or export it as a PDF to view it in PDF Hawk.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }
}
