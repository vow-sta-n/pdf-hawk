/*
 * PDF Hawk - Modern PDF Reader, Writer, Editor & Scanner
 * Copyright (C) 2026 Van Stan / Novaturients
 *
 * This software is licensed under the PolyForm Noncommercial License 1.0.0.
 * You may obtain a copy of the License at https://polyformproject.org/licenses/noncommercial/1.0.0
 */

import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart' as pdf_types;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfhawk/data/res/utils.dart';
import 'package:pdfhawk/logic/services/storage_service.dart';
import 'package:archive/archive.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:pdfhawk/data/models/writer_document_model.dart';
import 'package:pdfhawk/data/models/writer_element.dart';
import 'package:pdfhawk/data/res/enum.dart';
import 'package:pdfhawk/interface/builders/local_image_builder.dart';
import 'package:pdfhawk/interface/builders/shape_embed_builder.dart';
import 'package:pdfhawk/interface/pages/pdf_reader_page.dart';
import 'package:pdfhawk/interface/painters/shape_painter.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pdfhawk/logic/services/hawk_crypto_service.dart';
import 'package:pdfhawk/interface/widgets/resize_drag_wrapper.dart';
import 'package:pdfhawk/data/res/constants.dart';

class PdfWriterPage extends StatefulWidget {
  final List<WriterElement>? initialElements;
  final String? initialDeltaJson;
  final List<WriterElement>? initialOverlays;
  final File? sourceHawkFile;
  final bool isAutoSaved;

  const PdfWriterPage({
    super.key,
    this.initialElements,
    this.initialDeltaJson,
    this.initialOverlays,
    this.sourceHawkFile,
    this.isAutoSaved = false,
  });

  @override
  State<PdfWriterPage> createState() => _PdfWriterPageState();

  static String parseDocxToDeltaJson(File sourceFile) {
    final delta = Delta();
    double? pageWidth;
    double? pageHeight;
    double? marginTop;
    double? marginBottom;
    double? marginLeft;
    double? marginRight;

    try {
      final bytes = sourceFile.readAsBytesSync();
      final archive = ZipDecoder().decodeBytes(bytes);
      final docFile = archive.findFile('word/document.xml');
      if (docFile == null) return "[]";

      final xmlContent = utf8.decode(docFile.content as List<int>);

      // Extract page size and margins
      final pgSzRegExp = RegExp(r'<w:pgSz\b[^>]*>');
      final pgMarRegExp = RegExp(r'<w:pgMar\b[^>]*>');

      final wRegExp = RegExp(r'w:w="([^"]*)"');
      final hRegExp = RegExp(r'w:h="([^"]*)"');
      final topRegExp = RegExp(r'w:top="([^"]*)"');
      final bottomRegExp = RegExp(r'w:bottom="([^"]*)"');
      final leftRegExp = RegExp(r'w:left="([^"]*)"');
      final rightRegExp = RegExp(r'w:right="([^"]*)"');

      final pgSzMatch = pgSzRegExp.firstMatch(xmlContent);
      if (pgSzMatch != null) {
        final tag = pgSzMatch.group(0) ?? '';
        final wMatch = wRegExp.firstMatch(tag);
        final hMatch = hRegExp.firstMatch(tag);
        if (wMatch != null) {
          final val = double.tryParse(wMatch.group(1) ?? '');
          if (val != null) pageWidth = val / 20.0;
        }
        if (hMatch != null) {
          final val = double.tryParse(hMatch.group(1) ?? '');
          if (val != null) pageHeight = val / 20.0;
        }
      }

      final pgMarMatch = pgMarRegExp.firstMatch(xmlContent);
      if (pgMarMatch != null) {
        final tag = pgMarMatch.group(0) ?? '';
        final topM = topRegExp.firstMatch(tag);
        final bottomM = bottomRegExp.firstMatch(tag);
        final leftM = leftRegExp.firstMatch(tag);
        final rightM = rightRegExp.firstMatch(tag);

        if (topM != null) {
          final val = double.tryParse(topM.group(1) ?? '');
          if (val != null) marginTop = val / 20.0;
        }
        if (bottomM != null) {
          final val = double.tryParse(bottomM.group(1) ?? '');
          if (val != null) marginBottom = val / 20.0;
        }
        if (leftM != null) {
          final val = double.tryParse(leftM.group(1) ?? '');
          if (val != null) marginLeft = val / 20.0;
        }
        if (rightM != null) {
          final val = double.tryParse(rightM.group(1) ?? '');
          if (val != null) marginRight = val / 20.0;
        }
      }

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
      final szRegExp = RegExp(r'<w:sz\b[^>]*w:val="([^"]*)"');
      final rFontsRegExp = RegExp(
        r'<w:rFonts\b[^>]*w:(?:ascii|hAnsi)="([^"]*)"',
      );

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

        bool hasContent = false;
        for (final rMatch in rRegExp.allMatches(pBody)) {
          final rBody = rMatch.group(1) ?? '';

          // Parse run properties
          final attrs = <String, dynamic>{};
          final rPrMatch = rPrRegExp.firstMatch(rBody);
          if (rPrMatch != null) {
            final rPrBody = rPrMatch.group(1) ?? '';

            if (rPrBody.contains('<w:b/>') ||
                rPrBody.contains('<w:b ') ||
                rPrBody.contains('<w:bCs/>') ||
                rPrBody.contains('<w:bCs ')) {
              attrs['bold'] = true;
            }
            if (rPrBody.contains('<w:i/>') ||
                rPrBody.contains('<w:i ') ||
                rPrBody.contains('<w:iCs/>') ||
                rPrBody.contains('<w:iCs ')) {
              attrs['italic'] = true;
            }
            if (rPrBody.contains('<w:u ') || rPrBody.contains('<w:u/>')) {
              attrs['underline'] = true;
            }
            if (rPrBody.contains('<w:strike') ||
                rPrBody.contains('<w:dstrike')) {
              attrs['strike'] = true;
            }
            final colorMatch = colorRegExp.firstMatch(rPrBody);
            if (colorMatch != null) {
              final colorVal = colorMatch.group(1);
              if (colorVal != null && colorVal.length == 6) {
                attrs['color'] = '#$colorVal';
              }
            }
            final fontMatch = rFontsRegExp.firstMatch(rPrBody);
            if (fontMatch != null) {
              final fontVal = fontMatch.group(1);
              if (fontVal != null && fontVal.isNotEmpty) {
                attrs['font'] = fontVal;
              }
            }
            final szMatch = szRegExp.firstMatch(rPrBody);
            if (szMatch != null) {
              final szVal = double.tryParse(szMatch.group(1) ?? '');
              if (szVal != null) {
                attrs['size'] = (szVal / 2.0).toString();
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
            delta.insert(rText, attrs.isNotEmpty ? attrs : null);
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
            delta.insert(pText);
            hasContent = true;
          }
        }

        if (hasContent ||
            headerLevel != null ||
            spaceBefore != null ||
            spaceAfter != null) {
          final lineAttrs = <String, dynamic>{};
          if (headerLevel != null) {
            lineAttrs['header'] = headerLevel;
          }
          if (spaceBefore != null) {
            lineAttrs['spaceBefore'] = spaceBefore;
          }
          if (spaceAfter != null) {
            lineAttrs['spaceAfter'] = spaceAfter;
          }
          delta.insert('\n', lineAttrs.isNotEmpty ? lineAttrs : null);
        }
      }
    } catch (e) {
      debugPrint("Error parsing docx to delta: $e");
    }

    if (delta.isEmpty) {
      delta.insert("\n");
    }

    final resultMap = {
      'deltaJson': jsonEncode(delta.toJson()),
      '?pageWidth': pageWidth,
      '?pageHeight': pageHeight,
      '?marginTop': marginTop,
      '?marginBottom': marginBottom,
      '?marginLeft': marginLeft,
      '?marginRight': marginRight,
    };

    return jsonEncode(resultMap);
  }

  // Fallback helper for legacy element parsing
  static List<WriterElement> parseDocx(File sourceFile) {
    final List<WriterElement> list = [];
    try {
      final bytes = sourceFile.readAsBytesSync();
      final archive = ZipDecoder().decodeBytes(bytes);
      final docFile = archive.findFile('word/document.xml');
      if (docFile == null) return [];

      final xmlContent = utf8.decode(docFile.content as List<int>);

      final pRegExp = RegExp(r'<w:p\b[^>]*>(.*?)</w:p>');
      final tRegExp = RegExp(r'<w:t\b[^>]*>(.*?)</w:t>');

      int index = 0;
      for (final pMatch in pRegExp.allMatches(xmlContent)) {
        final pBody = pMatch.group(1) ?? '';
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
          list.add(
            WriterElement(
              id: "element_docx_${index}_${DateTime.now().millisecondsSinceEpoch}",
              type: ElementType.text,
              textContent: pText,
              isOverlay: false,
              fontSize: 14.0,
              fontFamily: "Roboto",
            ),
          );
          index++;
        }
      }
    } catch (e) {
      debugPrint("Error parsing docx: $e");
    }
    return list;
  }
}

class _PdfWriterPageState extends State<PdfWriterPage> {
  late WriterDocumentModel _document;
  late QuillController _quillController;
  late FocusNode _editorFocusNode;
  Timer? _autoSaveTimer;
  String? _selectedElementId;
  bool _isSaving = false;
  bool _isAutoSaving = false;

  File? _sourceHawkFile;
  bool _isAutoSavedSession = false;

  double? _pageWidth;
  double? _pageHeight;
  double? _marginTop;
  double? _marginBottom;
  double? _marginLeft;
  double? _marginRight;
  Color? _pageColor;
  Color? _writingBgColor;

  void _checkAutoPageCreation() {}

  @override
  void initState() {
    super.initState();
    _sourceHawkFile = widget.sourceHawkFile;
    _isAutoSavedSession =
        widget.isAutoSaved ||
        (_sourceHawkFile != null &&
            p
                .basename(_sourceHawkFile!.path)
                .toLowerCase()
                .startsWith('autosaved_'));
    Document quillDoc;
    List<WriterElement> restoredOverlays = [];
    if (widget.initialDeltaJson != null) {
      try {
        final decoded =
            jsonDecode(widget.initialDeltaJson!) as Map<String, dynamic>;
        if (decoded.containsKey('deltaJson')) {
          final list = jsonDecode(decoded['deltaJson'] as String) as List;
          quillDoc = Document.fromDelta(Delta.fromJson(list));

          _pageWidth = (decoded['pageWidth'] as num?)?.toDouble();
          _pageHeight = (decoded['pageHeight'] as num?)?.toDouble();
          _marginTop = (decoded['marginTop'] as num?)?.toDouble();
          _marginBottom = (decoded['marginBottom'] as num?)?.toDouble();
          _marginLeft = (decoded['marginLeft'] as num?)?.toDouble();
          _marginRight = (decoded['marginRight'] as num?)?.toDouble();
          if (decoded['pageColorHex'] != null) {
            try {
              final hexStr = decoded['pageColorHex'] as String;
              _pageColor = Color(int.parse(hexStr, radix: 16));
            } catch (_) {}
          }
        } else if (decoded.containsKey('quillDeltaJson')) {
          final list = jsonDecode(decoded['quillDeltaJson'] as String) as List;
          quillDoc = Document.fromDelta(Delta.fromJson(list));

          _pageWidth = (decoded['pageWidth'] as num?)?.toDouble();
          _pageHeight = (decoded['pageHeight'] as num?)?.toDouble();
          _marginTop = (decoded['marginTop'] as num?)?.toDouble();
          _marginBottom = (decoded['marginBottom'] as num?)?.toDouble();
          _marginLeft = (decoded['marginLeft'] as num?)?.toDouble();
          _marginRight = (decoded['marginRight'] as num?)?.toDouble();
          if (decoded['pageColorHex'] != null) {
            try {
              final hexStr = decoded['pageColorHex'] as String;
              _pageColor = Color(int.parse(hexStr, radix: 16));
            } catch (_) {}
          }
        } else {
          final list = decoded as List;
          quillDoc = Document.fromDelta(Delta.fromJson(list));
        }
      } catch (_) {
        try {
          final list = jsonDecode(widget.initialDeltaJson!) as List;
          quillDoc = Document.fromDelta(Delta.fromJson(list));
        } catch (_) {
          quillDoc = Document();
        }
      }
      restoredOverlays = widget.initialOverlays ?? [];
    } else if (widget.initialElements != null &&
        widget.initialElements!.isNotEmpty) {
      // Build a delta from text elements
      final delta = Delta();
      for (var el in widget.initialElements!) {
        if (el.type == ElementType.text) {
          delta.insert(el.textContent);
          delta.insert('\n');
        } else {
          restoredOverlays.add(el);
        }
      }
      quillDoc = delta.isNotEmpty ? Document.fromDelta(delta) : Document();
    } else {
      quillDoc = Document();
    }

    _editorFocusNode = FocusNode();

    _quillController = QuillController(
      document: quillDoc,
      selection: const TextSelection.collapsed(offset: 0),
    );

    // Initialize 12pt as default font size if document is new/empty
    if (quillDoc.isEmpty() || quillDoc.toPlainText().trim().isEmpty) {
      _quillController.formatSelection(Attribute.fromKeyValue('size', '12'));
    }

    String? initialPageHex;
    if (_pageColor != null) {
      initialPageHex = _pageColor!.toARGB32().toRadixString(16).padLeft(8, '0');
    }

    _document = WriterDocumentModel(
      quillDeltaJson: jsonEncode(_quillController.document.toDelta().toJson()),
      overlays: restoredOverlays,
      pageWidth: _pageWidth,
      pageHeight: _pageHeight,
      marginTop: _marginTop,
      marginBottom: _marginBottom,
      marginLeft: _marginLeft,
      marginRight: _marginRight,
      pageColorHex: initialPageHex,
    );

    _quillController.addListener(() {
      _checkAutoPageCreation();
      _scheduleDebouncedAutoSave();
    });

    _autoSave();
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _editorFocusNode.dispose();
    _quillController.dispose();
    super.dispose();
  }

  void _updateQuillJson() {
    String? pageHex;
    if (_pageColor != null) {
      pageHex = _pageColor!.toARGB32().toRadixString(16).padLeft(8, '0');
    }
    _document = WriterDocumentModel(
      quillDeltaJson: jsonEncode(_quillController.document.toDelta().toJson()),
      overlays: _document.overlays,
      pageWidth: _pageWidth,
      pageHeight: _pageHeight,
      marginTop: _marginTop,
      marginBottom: _marginBottom,
      marginLeft: _marginLeft,
      marginRight: _marginRight,
      pageColorHex: pageHex,
    );
  }

  void _scheduleDebouncedAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(milliseconds: 800), () {
      _updateQuillJson();
      _autoSave();
    });
  }

  // --- AUTO-SAVE STORAGE & HAWK ENCRYPTION ---
  Future<void> _autoSave() async {
    if (mounted) {
      setState(() {
        _isAutoSaving = true;
      });
    }
    try {
      final jsonMap = _document.toJson();
      final box = Hive.box('pdfhawk_box');
      await box.put('ongoing_writer_session', jsonMap);

      final dir = await getApplicationDocumentsDirectory();
      final file = File("${dir.path}/auto_save_writer.json");
      await file.writeAsString(jsonEncode(jsonMap));
    } catch (e) {
      debugPrint("Auto-save failed: $e");
    } finally {
      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 400));
        if (mounted) {
          setState(() {
            _isAutoSaving = false;
          });
        }
      }
    }
  }

  Future<void> _clearAutoSave() async {
    try {
      final box = Hive.box('pdfhawk_box');
      await box.delete('ongoing_writer_session');

      final dir = await getApplicationDocumentsDirectory();
      final file = File("${dir.path}/auto_save_writer.json");
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint("Failed to clear auto-save: $e");
    }
  }

  String _getSuggestedFileName({String fallback = "Document"}) {
    try {
      final plainText = _quillController.document.toPlainText().trim();
      if (plainText.isNotEmpty) {
        final lines = plainText
            .split(RegExp(r'[\r\n]+'))
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)
            .toList();

        if (lines.isNotEmpty) {
          final firstLine = lines.first;
          final words = firstLine
              .split(RegExp(r'\s+'))
              .where((w) => w.isNotEmpty)
              .toList();

          if (words.isNotEmpty) {
            final chosenWords = words.take(8).toList();
            final combined = chosenWords.join(' ');
            final sanitized = combined
                .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
                .replaceAll(RegExp(r'\s+'), ' ')
                .trim();

            if (sanitized.isNotEmpty) {
              return sanitized;
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Error extracting suggested file name: $e");
    }
    return "${fallback}_${DateTime.now().millisecondsSinceEpoch}";
  }

  Future<bool> _saveAsHawkDocument(BuildContext context) async {
    _updateQuillJson();
    final suggestedName = _getSuggestedFileName();
    final textController = TextEditingController(text: suggestedName);

    final String? docName = await showDialog<String>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: allradius(16.r),
          ),
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          title: Text(
            "Save Encrypted Document (.hawk)",
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              fontSize: 18.sp,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Enter a file name for your encrypted .hawk document:",
                style: GoogleFonts.instrumentSans(
                  fontSize: 13.sp,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                ),
              ),
              Gap(12.h),
              TextField(
                controller: textController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: "Document Name",
                  suffixText: ".hawk",
                  border: OutlineInputBorder(
                    borderRadius: allradius(10.r),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                final input = textController.text.trim();
                Navigator.pop(context, input.isEmpty ? suggestedName : input);
              },
              child: const Text("Save .hawk"),
            ),
          ],
        );
      },
    );

    if (docName != null && docName.isNotEmpty) {
      try {
        final file = await HawkCryptoService.saveHawkFile(
          docName,
          _document.toJson(),
        );
        await _clearAutoSave();

        // If this document was opened from an auto-saved file, delete the old auto-saved file
        if (_sourceHawkFile != null && _isAutoSavedSession) {
          if (_sourceHawkFile!.path != file.path) {
            try {
              await HawkCryptoService.deleteHawkFile(_sourceHawkFile!);
            } catch (e) {
              debugPrint("Failed to delete auto-saved source file: $e");
            }
          }
          _sourceHawkFile = file;
          _isAutoSavedSession = false;
        }

        plainToast(msg: "Document saved as '${p.basename(file.path)}'!");
        return true;
      } catch (e) {
        plainToast(msg: "Something went wrong, Unable to save file!");
        debugPrint(e.toString());
        return false;
      }
    }
    return false;
  }

  Future<bool> onBack() async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final action = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: allradius(20.r),
          ),
          backgroundColor: isDark ? const Color(0xFF1E1E24) : Colors.white,
          title: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  color: Colors.amber.shade700.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.amber.shade700,
                  size: 22.sp,
                ),
              ),
              Gap(10.w),
              Expanded(
                child: Text(
                  "Leave Document?",
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 17.sp,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            "Do you want to save your document before exiting, or discard all changes? Discarding will remove all auto-saved data so no accidental files are left on your device.",
            style: GoogleFonts.inter(
              fontSize: 12.5.sp,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
              height: 1.4,
            ),
          ),
          actionsPadding: EdgeInsets.symmetric(
            horizontal: 16.w,
            vertical: 12.h,
          ),
          actions: [
            // 1. Continue Editing (Cancel dialog)
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, 'cancel'),
              child: Text(
                "Continue",
                style: TextStyle(
                  fontSize: 12.sp,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
            ),
            // 2. Discard / Delete
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(dialogContext, 'delete'),
              icon: Icon(
                Icons.delete_outline_rounded,
                size: 14.sp,
                color: Colors.redAccent,
              ),
              label: Text(
                "Discard",
                style: TextStyle(fontSize: 12.sp, color: Colors.redAccent),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.redAccent, width: 1),
                shape: RoundedRectangleBorder(
                  borderRadius: allradius(10.r),
                ),
              ),
            ),
            // 3. Save Document
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(dialogContext, 'save'),
              icon: Icon(Icons.save_rounded, size: 14.sp, color: Colors.white),
              label: Text(
                "Save",
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: allradius(10.r),
                ),
              ),
            ),
          ],
        );
      },
    );

    if (action == 'save') {
      if (!mounted) return false;
      final saved = await _saveAsHawkDocument(context);
      if (saved && mounted) {
        Navigator.pop(context);
        return true;
      }
      return false;
    } else if (action == 'delete') {
      await _clearAutoSave();
      Fluttertoast.showToast(
        msg: "Document changes discarded.",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.grey.shade800,
        textColor: Colors.white,
      );
      if (mounted) {
        Navigator.pop(context);
      }
      return true;
    }

    // Cancel or dismissed -> stay in editor
    return false;
  }

  // --- ACTIONS ---

  void _addElement(ElementType type) async {
    final id = "el_${type.name}_${DateTime.now().millisecondsSinceEpoch}";
    WriterElement newElement;

    if (type == ElementType.image) {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result == null || result.files.single.path == null) return;
      newElement = WriterElement(
        id: id,
        type: type,
        imagePath: result.files.single.path,
        width: 150,
        height: 150,
        x: 40,
        y: 80,
        isOverlay: true,
      );
    } else {
      // Shape
      newElement = WriterElement(
        id: id,
        type: type,
        shapeType: ShapeType.rectangle,
        fillColorValue: Colors.teal.shade100.withValues(alpha: 0.4).toARGB32(),
        borderColorValue: Colors.teal.toARGB32(),
        borderWidth: 2.0,
        width: 120,
        height: 80,
        x: 40,
        y: 80,
        isOverlay: true,
      );
    }

    setState(() {
      _document.overlays.add(newElement);
      _selectedElementId = id;
    });
    _autoSave();
  }

  void _addInlineElement(ElementType type) async {
    final index = _quillController.selection.baseOffset;
    if (type == ElementType.image) {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result == null || result.files.single.path == null) return;
      final imagePath = result.files.single.path!;

      _quillController.replaceText(index, 0, BlockEmbed.image(imagePath), null);
      _quillController.moveCursorToPosition(index + 1);
    } else {
      if (!mounted) return;
      final selectedShape = await showDialog<ShapeType>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text("Select Shape Type"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.crop_square_rounded),
                  title: const Text("Rectangle"),
                  onTap: () => Navigator.pop(context, ShapeType.rectangle),
                ),
                ListTile(
                  leading: const Icon(Icons.circle_outlined),
                  title: const Text("Circle"),
                  onTap: () => Navigator.pop(context, ShapeType.circle),
                ),
                ListTile(
                  leading: const Icon(Icons.lens_outlined),
                  title: const Text("Oval"),
                  onTap: () => Navigator.pop(context, ShapeType.oval),
                ),
              ],
            ),
          );
        },
      );
      if (selectedShape == null) return;

      final shapeData = jsonEncode({
        'shapeType': selectedShape.name,
        'fillColor': Colors.teal.shade100.withValues(alpha: 0.4).toARGB32(),
        'borderColor': Colors.teal.toARGB32(),
        'borderWidth': 2.0,
        'width': 120.0,
        'height': 80.0,
      });

      _quillController.replaceText(
        index,
        0,
        BlockEmbed('shape', shapeData),
        null,
      );
      _quillController.moveCursorToPosition(index + 1);
    }
  }

  void _deleteElement(String id) {
    setState(() {
      _document.overlays.removeWhere((e) => e.id == id);
      if (_selectedElementId == id) {
        _selectedElementId = null;
      }
    });
    _autoSave();
  }

  void _updateElement(WriterElement el) {
    setState(() {
      final idx = _document.overlays.indexWhere((e) => e.id == el.id);
      if (idx != -1) {
        _document.overlays[idx] = el;
      }
    });
    _scheduleDebouncedAutoSave();
  }

  // --- COMPILATION & SAVE ---

  Future<void> _exportToPdf() async {
    _updateQuillJson();
    setState(() {
      _isSaving = true;
    });

    try {
      final pdf = pw.Document();
      // Standard A4 page format (or custom page dimensions if provided)
      final double pdfWidth = _pageWidth ?? pdf_types.PdfPageFormat.a4.width;
      final double pdfHeight = _pageHeight ?? pdf_types.PdfPageFormat.a4.height;
      final pdfPageFormat = pdf_types.PdfPageFormat(pdfWidth, pdfHeight);

      final double marginTopPdf = _marginTop ?? 36.0;
      final double marginBottomPdf = _marginBottom ?? 36.0;
      final double marginLeftPdf = _marginLeft ?? 36.0;
      final double marginRightPdf = _marginRight ?? 36.0;

      final pdfPageTheme = pw.PageTheme(
        pageFormat: pdfPageFormat,
        margin: pw.EdgeInsets.only(
          left: marginLeftPdf,
          right: marginRightPdf,
          top: marginTopPdf,
          bottom: marginBottomPdf,
        ),
        buildBackground: (pw.Context context) {
          if (_pageColor != null && _pageColor != Colors.white) {
            return pw.FullPage(
              ignoreMargins: true,
              child: pw.Container(
                color: pdf_types.PdfColor.fromInt(_pageColor!.toARGB32()),
              ),
            );
          }
          return pw.SizedBox();
        },
      );

      final List<pw.Widget> multiPageContent =
          _compileQuillDeltaToMultiPageWidgets(_document.quillDeltaJson);

      // Append any overlay elements if present
      if (_document.overlays.isNotEmpty) {
        multiPageContent.add(
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 12),
            child: pw.Divider(color: pdf_types.PdfColors.grey300),
          ),
        );
        for (var el in _document.overlays) {
          multiPageContent.add(
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 8),
              child: _buildPdfElementWidget(
                el,
                pdfWidth - marginLeftPdf - marginRightPdf,
              ),
            ),
          );
        }
      }

      pdf.addPage(
        pw.MultiPage(
          pageTheme: pdfPageTheme,
          header: (pw.Context context) {
            return pw.SizedBox(height: 4);
          },
          footer: (pw.Context context) {
            return pw.Container(
              alignment: pw.Alignment.centerRight,
              margin: const pw.EdgeInsets.only(top: 8),
              child: pw.Text(
                "Page ${context.pageNumber} of ${context.pagesCount}",
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: pdf_types.PdfColors.grey600,
                ),
              ),
            );
          },
          build: (pw.Context context) => multiPageContent,
        ),
      );

      final suggestedName = _getSuggestedFileName(fallback: "WriterExport");
      final outputFile = await StorageService.saveExportedFile(
        fileName: "$suggestedName.pdf",
        bytes: await pdf.save(),
      );

      await _clearAutoSave();

      // If this document was opened from an auto-saved file, delete the old auto-saved file
      if (_sourceHawkFile != null && _isAutoSavedSession) {
        try {
          await HawkCryptoService.deleteHawkFile(_sourceHawkFile!);
          _sourceHawkFile = null;
          _isAutoSavedSession = false;
        } catch (e) {
          debugPrint("Failed to delete auto-saved source file on export: $e");
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Exported PDF: ${outputFile.path.split('/').last}"),
            action: SnackBarAction(
              label: "Open",
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PDFReaderPage(pdfFile: outputFile),
                  ),
                );
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("PDF Export Failed: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  List<pw.Widget> _compileQuillDeltaToMultiPageWidgets(String deltaJson) {
    final List<pw.Widget> widgets = [];
    try {
      final list = jsonDecode(deltaJson) as List;
      final delta = Delta.fromJson(list);
      final lines = _splitDeltaIntoLines(delta);

      int orderedListCounter = 1;

      for (int lineIndex = 0; lineIndex < lines.length; lineIndex++) {
        final line = lines[lineIndex];
        bool isEmbed = false;
        pw.Widget? embedWidget;

        for (var op in line.ops) {
          if (op.data is Map) {
            final dataMap = op.data as Map;
            if (dataMap.containsKey('image')) {
              final imagePath = dataMap['image'] as String;
              final imageFile = File(imagePath);
              if (imageFile.existsSync()) {
                final pdfImage = pw.MemoryImage(imageFile.readAsBytesSync());
                isEmbed = true;
                embedWidget = pw.Center(
                  child: pw.Container(
                    margin: const pw.EdgeInsets.symmetric(vertical: 8),
                    child: pw.Image(
                      pdfImage,
                      width: 260,
                      height: 200,
                      fit: pw.BoxFit.contain,
                    ),
                  ),
                );
              }
            } else if (dataMap.containsKey('shape')) {
              try {
                final value = dataMap['shape'] as String;
                final shapeData = jsonDecode(value) as Map<String, dynamic>;
                final shapeStr =
                    shapeData['shapeType'] as String? ?? 'rectangle';
                final fillColorVal = shapeData['fillColor'] as int?;
                final borderColorVal = shapeData['borderColor'] as int?;
                final borderWidth = (shapeData['borderWidth'] as num? ?? 1.0)
                    .toDouble();
                final w = (shapeData['width'] as num? ?? 100.0).toDouble();
                final h = (shapeData['height'] as num? ?? 60.0).toDouble();

                final fillColor = fillColorVal != null
                    ? pdf_types.PdfColor.fromInt(fillColorVal)
                    : null;
                final borderColor = borderColorVal != null
                    ? pdf_types.PdfColor.fromInt(borderColorVal)
                    : pdf_types.PdfColors.black;

                isEmbed = true;

                pw.Widget shapePdfWidget;
                if (shapeStr == 'circle') {
                  shapePdfWidget = pw.Container(
                    width: w,
                    height: h,
                    decoration: pw.BoxDecoration(
                      shape: pw.BoxShape.circle,
                      color: fillColor,
                      border: pw.Border.all(
                        color: borderColor,
                        width: borderWidth,
                      ),
                    ),
                  );
                } else if (shapeStr == 'oval') {
                  shapePdfWidget = pw.Container(
                    width: w,
                    height: h,
                    decoration: pw.BoxDecoration(
                      borderRadius: pw.BorderRadius.all(
                        pw.Radius.elliptical(w / 2, h / 2),
                      ),
                      color: fillColor,
                      border: pw.Border.all(
                        color: borderColor,
                        width: borderWidth,
                      ),
                    ),
                  );
                } else {
                  shapePdfWidget = pw.Container(
                    width: w,
                    height: h,
                    decoration: pw.BoxDecoration(
                      color: fillColor,
                      border: pw.Border.all(
                        color: borderColor,
                        width: borderWidth,
                      ),
                    ),
                  );
                }

                embedWidget = pw.Center(
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 8),
                    child: shapePdfWidget,
                  ),
                );
              } catch (e) {
                debugPrint("Error parsing inline shape for pdf: $e");
              }
            }
            if (isEmbed) break;
          }
        }

        if (isEmbed && embedWidget != null) {
          widgets.add(embedWidget);
          orderedListCounter = 1;
          continue;
        }

        final lineAttr = line.attributes;
        final header = lineAttr?['header'];
        final listAttr = lineAttr?['list'];
        final blockquote = lineAttr?['blockquote'] == true;
        final codeBlock = lineAttr?['code-block'] == true;
        final alignAttr = lineAttr?['align'] as String?;

        pw.TextAlign textAlign = pw.TextAlign.left;
        if (alignAttr == 'center') {
          textAlign = pw.TextAlign.center;
        } else if (alignAttr == 'right') {
          textAlign = pw.TextAlign.right;
        } else if (alignAttr == 'justify') {
          textAlign = pw.TextAlign.justify;
        }

        double baseFontSize = 11.0;
        pw.Font baseFont = pw.Font.helvetica();
        bool isHeaderBold = false;

        if (header == 1) {
          baseFontSize = 20.0;
          baseFont = pw.Font.helveticaBold();
          isHeaderBold = true;
        } else if (header == 2) {
          baseFontSize = 16.0;
          baseFont = pw.Font.helveticaBold();
          isHeaderBold = true;
        } else if (header == 3) {
          baseFontSize = 13.0;
          baseFont = pw.Font.helveticaBold();
          isHeaderBold = true;
        }

        final children = <pw.InlineSpan>[];

        for (var op in line.ops) {
          if (op.data is! String) continue;
          final text = op.data as String;
          if (text == '\n') continue;

          final attr = op.attributes;
          final bold = attr?['bold'] == true || isHeaderBold;
          final italic = attr?['italic'] == true;
          final underline = attr?['underline'] == true;
          final strike = attr?['strike'] == true;
          final colorHex = attr?['color'] as String?;
          final backgroundHex = attr?['background'] as String?;
          final fontName = attr?['font'] as String?;

          pw.Font currentFont;
          final fontNameLower = fontName?.toLowerCase();
          if (codeBlock ||
              (fontNameLower != null &&
                  (fontNameLower.contains('courier') ||
                      fontNameLower.contains('mono') ||
                      fontNameLower.contains('consolas')))) {
            if (bold && italic) {
              currentFont = pw.Font.courierBoldOblique();
            } else if (bold) {
              currentFont = pw.Font.courierBold();
            } else if (italic) {
              currentFont = pw.Font.courierOblique();
            } else {
              currentFont = pw.Font.courier();
            }
          } else if (fontNameLower != null &&
              (fontNameLower.contains('times') ||
                  fontNameLower.contains('serif') ||
                  fontNameLower.contains('georgia') ||
                  fontNameLower.contains('playfair') ||
                  fontNameLower.contains('lora'))) {
            if (bold && italic) {
              currentFont = pw.Font.timesBoldItalic();
            } else if (bold) {
              currentFont = pw.Font.timesBold();
            } else if (italic) {
              currentFont = pw.Font.timesItalic();
            } else {
              currentFont = pw.Font.times();
            }
          } else {
            if (bold && italic) {
              currentFont = pw.Font.helveticaBoldOblique();
            } else if (bold) {
              currentFont = pw.Font.helveticaBold();
            } else if (italic) {
              currentFont = pw.Font.helveticaOblique();
            } else {
              currentFont = isHeaderBold ? pw.Font.helveticaBold() : baseFont;
            }
          }

          pdf_types.PdfColor textColor = pdf_types.PdfColors.black;
          if (colorHex != null) {
            try {
              textColor = pdf_types.PdfColor.fromHex(colorHex);
            } catch (_) {}
          }

          pw.BoxDecoration? bg;
          if (backgroundHex != null) {
            try {
              bg = pw.BoxDecoration(
                color: pdf_types.PdfColor.fromHex(backgroundHex),
              );
            } catch (_) {}
          }

          double currentFontSize = baseFontSize;
          if (attr != null && attr.containsKey('size')) {
            final sizeVal = attr['size'];
            if (sizeVal is num) {
              currentFontSize = sizeVal.toDouble();
            } else if (sizeVal is String) {
              final parsedNum = double.tryParse(sizeVal);
              if (parsedNum != null) {
                currentFontSize = parsedNum;
              } else if (sizeVal == 'small') {
                currentFontSize = 8.5;
              } else if (sizeVal == 'large') {
                currentFontSize = 16.0;
              } else if (sizeVal == 'huge') {
                currentFontSize = 22.0;
              }
            }
          }

          final spanStyle = pw.TextStyle(
            font: currentFont,
            fontSize: currentFontSize,
            fontStyle: italic ? pw.FontStyle.italic : pw.FontStyle.normal,
            decoration: pw.TextDecoration.combine([
              if (underline) pw.TextDecoration.underline,
              if (strike) pw.TextDecoration.lineThrough,
            ]),
            color: textColor,
            background: bg,
          );

          children.add(pw.TextSpan(text: text, style: spanStyle));
        }

        if (children.isEmpty) {
          // Empty newline line
          widgets.add(pw.SizedBox(height: baseFontSize * 1.2));
          orderedListCounter = 1;
          continue;
        }

        pw.Widget lineWidget = pw.RichText(
          textAlign: textAlign,
          text: pw.TextSpan(children: children),
        );

        if (listAttr == 'bullet') {
          orderedListCounter = 1;
          lineWidget = pw.Padding(
            padding: const pw.EdgeInsets.only(left: 12),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  "•   ",
                  style: pw.TextStyle(
                    fontSize: baseFontSize,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Expanded(child: lineWidget),
              ],
            ),
          );
        } else if (listAttr == 'ordered') {
          final prefix = "$orderedListCounter.   ";
          orderedListCounter++;
          lineWidget = pw.Padding(
            padding: const pw.EdgeInsets.only(left: 12),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  prefix,
                  style: pw.TextStyle(
                    fontSize: baseFontSize,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Expanded(child: lineWidget),
              ],
            ),
          );
        } else {
          orderedListCounter = 1;
        }

        if (blockquote) {
          lineWidget = pw.Container(
            margin: const pw.EdgeInsets.symmetric(vertical: 4),
            padding: const pw.EdgeInsets.only(
              left: 12,
              top: 4,
              bottom: 4,
              right: 8,
            ),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                left: pw.BorderSide(
                  color: pdf_types.PdfColors.blueGrey400,
                  width: 3,
                ),
              ),
              color: pdf_types.PdfColor(0.96, 0.96, 0.98),
            ),
            child: lineWidget,
          );
        } else if (codeBlock) {
          lineWidget = pw.Container(
            width: double.infinity,
            margin: const pw.EdgeInsets.symmetric(vertical: 3),
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: const pw.BoxDecoration(
              color: pdf_types.PdfColor(0.94, 0.94, 0.96),
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: lineWidget,
          );
        }

        double spaceBefore = 0.0;
        double spaceAfter = header != null ? 6.0 : 3.0;
        final spaceBeforeVal = lineAttr?['spaceBefore'] as num?;
        final spaceAfterVal = lineAttr?['spaceAfter'] as num?;
        if (spaceBeforeVal != null) spaceBefore = spaceBeforeVal.toDouble();
        if (spaceAfterVal != null) spaceAfter = spaceAfterVal.toDouble();

        widgets.add(
          pw.Padding(
            padding: pw.EdgeInsets.only(top: spaceBefore, bottom: spaceAfter),
            child: lineWidget,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error compiling delta to multipage pdf widgets: $e");
    }

    if (widgets.isEmpty) {
      widgets.add(pw.Text(""));
    }

    return widgets;
  }

  List<_DeltaLine> _splitDeltaIntoLines(Delta delta) {
    final List<_DeltaLine> lines = [];
    List<Operation> currentOps = [];

    for (var op in delta.toList()) {
      if (op.data is String) {
        final text = op.data as String;
        if (text.contains('\n')) {
          final parts = text.split('\n');
          for (int i = 0; i < parts.length; i++) {
            if (parts[i].isNotEmpty) {
              currentOps.add(Operation.insert(parts[i], op.attributes));
            }
            if (i < parts.length - 1) {
              lines.add(
                _DeltaLine(
                  ops: List.from(currentOps),
                  attributes: op.attributes,
                ),
              );
              currentOps.clear();
            }
          }
        } else {
          currentOps.add(op);
        }
      } else {
        currentOps.add(op);
      }
    }

    if (currentOps.isNotEmpty) {
      lines.add(_DeltaLine(ops: List.from(currentOps), attributes: null));
    }

    return lines;
  }

  pw.Widget _buildPdfElementWidget(WriterElement el, double availableWidth) {
    if (el.type == ElementType.image && el.imagePath != null) {
      final imgBytes = File(el.imagePath!).readAsBytesSync();
      final img = pw.MemoryImage(imgBytes);
      final imageWidget = pw.Image(img, fit: pw.BoxFit.fill);

      if (el.rotation != 0) {
        return pw.Transform.rotate(
          angle: el.rotation * 3.14159 / 180,
          child: imageWidget,
        );
      }
      return imageWidget;
    } else if (el.type == ElementType.shape && el.shapeType != null) {
      final fillColor = el.fillColorValue != null
          ? pdf_types.PdfColor.fromInt(el.fillColorValue!)
          : const pdf_types.PdfColor(0, 0, 0, 0);
      final borderColor = el.borderColorValue != null
          ? pdf_types.PdfColor.fromInt(el.borderColorValue!)
          : pdf_types.PdfColors.black;

      if (el.shapeType == ShapeType.rectangle) {
        return pw.Container(
          decoration: pw.BoxDecoration(
            color: fillColor,
            border: pw.Border.all(color: borderColor, width: el.borderWidth),
          ),
        );
      } else {
        return pw.Container(
          decoration: pw.BoxDecoration(
            color: fillColor,
            shape: pw.BoxShape.circle,
            border: pw.Border.all(color: borderColor, width: el.borderWidth),
          ),
        );
      }
    }
    return pw.SizedBox();
  }

  // --- DIALOGS ---

  void _showImageLongPressPrompt(WriterElement el) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20.r),
              topRight: Radius.circular(20.r),
            ),
          ),
          padding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Image Options",
                style: GoogleFonts.outfit(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Gap(16.h),
              ListTile(
                leading: const Icon(Icons.edit_rounded, color: Colors.blue),
                title: const Text("Edit Image Layout (Crop, Rotation, Size)"),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _selectedElementId = el.id;
                  });
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.swap_horiz_rounded,
                  color: Colors.teal,
                ),
                title: const Text("Replace Image File"),
                onTap: () async {
                  Navigator.pop(context);
                  final result = await FilePicker.platform.pickFiles(
                    type: FileType.image,
                  );
                  if (result != null && result.files.single.path != null) {
                    _updateElement(
                      el.copyWith(imagePath: result.files.single.path),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_forever_rounded,
                  color: Colors.red,
                ),
                title: const Text("Delete Image"),
                onTap: () {
                  Navigator.pop(context);
                  _deleteElement(el.id);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // --- ADD OVERLAY MODAL MENU ---

  void _showAddOverlayMenu(BuildContext context, ThemeData theme, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, -2),
              ),
            ],
          ),
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Add Elements",
                style: GoogleFonts.outfit(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Gap(4.h),
              Text(
                "Insert elements flowing inline with your text, or float them as absolute draggable overlays.",
                style: GoogleFonts.instrumentSans(
                  fontSize: 12.sp,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              Gap(24.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildOverlayOptionCard(
                    icon: Icons.image_outlined,
                    label: "Inline Image",
                    description: "Flows with text",
                    color: Colors.teal.shade500,
                    isDark: isDark,
                    onTap: () {
                      Navigator.pop(context);
                      _addInlineElement(ElementType.image);
                    },
                  ),
                  _buildOverlayOptionCard(
                    icon: Icons.image_rounded,
                    label: "Overlay Image",
                    description: "Draggable layer",
                    color: Colors.teal.shade700,
                    isDark: isDark,
                    onTap: () {
                      Navigator.pop(context);
                      _addElement(ElementType.image);
                    },
                  ),
                ],
              ),
              Gap(16.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildOverlayOptionCard(
                    icon: Icons.category_outlined,
                    label: "Inline Shape",
                    description: "Flows with text",
                    color: Colors.orange.shade500,
                    isDark: isDark,
                    onTap: () {
                      Navigator.pop(context);
                      _addInlineElement(ElementType.shape);
                    },
                  ),
                  _buildOverlayOptionCard(
                    icon: Icons.category_rounded,
                    label: "Overlay Shape",
                    description: "Draggable layer",
                    color: Colors.orange.shade700,
                    isDark: isDark,
                    onTap: () {
                      Navigator.pop(context);
                      _addElement(ElementType.shape);
                    },
                  ),
                ],
              ),
              Gap(16.h),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOverlayOptionCard({
    required IconData icon,
    required String label,
    required String description,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140.w,
        padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 12.w),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C2C2E) : Colors.grey.shade50,
          borderRadius: allradius(16.r),
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.grey.shade200,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28.r),
            ),
            Gap(12.h),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            Gap(4.h),
            Text(
              description,
              textAlign: TextAlign.center,
              style: GoogleFonts.instrumentSans(
                fontSize: 10.sp,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- SUB-WIDGET BUILDERS ---

  Widget _buildElementOnCanvas(WriterElement el) {
    if (el.type == ElementType.image && el.imagePath != null) {
      final file = File(el.imagePath!);
      if (!file.existsSync()) {
        return const Center(child: Icon(Icons.broken_image_rounded, size: 40));
      }
      return LayoutBuilder(
        builder: (context, constraints) {
          return Transform.rotate(
            angle: el.rotation * 3.14159 / 180,
            child: ClipRect(
              child: Align(
                alignment: Alignment(
                  (el.cropLeft - el.cropRight),
                  (el.cropTop - el.cropBottom),
                ),
                widthFactor: 1.0 - el.cropLeft - el.cropRight,
                heightFactor: 1.0 - el.cropTop - el.cropBottom,
                child: Image.file(
                  file,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
            ),
          );
        },
      );
    } else if (el.type == ElementType.shape && el.shapeType != null) {
      final fillColor = el.fillColorValue != null
          ? Color(el.fillColorValue!)
          : Colors.transparent;
      final borderColor = el.borderColorValue != null
          ? Color(el.borderColorValue!)
          : Colors.black;

      return CustomPaint(
        painter: ShapePainter(
          shapeType: el.shapeType!,
          fillColor: fillColor,
          borderColor: borderColor,
          borderWidth: el.borderWidth,
        ),
        size: Size(el.width, el.height),
      );
    }

    return const SizedBox();
  }

  void _showMoreOptionsBottomSheet(
    BuildContext pageContext,
    ThemeData theme,
    bool isDark,
  ) {
    MarginUnit selectedUnit = MarginUnit.inch;

    showModalBottomSheet(
      context: pageContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setBottomSheetState) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 16,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Document Options & Layout",
                          style: GoogleFonts.outfit(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    Gap(12.h),

                    // Section 1: Save & Export Actions
                    Text(
                      "Save & Export",
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    Gap(10.h),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: (_isSaving || _isAutoSaving)
                                ? null
                                : () {
                                    Navigator.pop(context);
                                    _saveAsHawkDocument(pageContext);
                                  },
                            icon: Icon(
                              Icons.lock_outline_rounded,
                              size: 16.sp,
                              color: theme.colorScheme.primary,
                            ),
                            label: Text(
                              "Save .hawk",
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                fontSize: 12.sp,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 12.h),
                              side: BorderSide(
                                color: theme.colorScheme.primary,
                                width: 1.2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: allradius(12.r),
                              ),
                            ),
                          ),
                        ),
                        Gap(12.w),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: (_isSaving || _isAutoSaving)
                                ? null
                                : () {
                                    Navigator.pop(context);
                                    _exportToPdf();
                                  },
                            icon: _isSaving
                                ? SizedBox(
                                    width: 14.r,
                                    height: 14.r,
                                    child: const CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Icon(
                                    Icons.picture_as_pdf_outlined,
                                    size: 16.sp,
                                    color: Colors.white,
                                  ),
                            label: Text(
                              "Save PDF",
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                fontSize: 12.sp,
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              padding: EdgeInsets.symmetric(vertical: 12.h),
                              shape: RoundedRectangleBorder(
                                borderRadius: allradius(12.r),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Gap(24.h),
                    const Divider(),
                    Gap(12.h),

                    // Section 2: Page Margins & Layout Configurations
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Page Layout & Margins",
                          style: GoogleFonts.inter(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        // Unit Segmented Selector (in / cm / pt)
                        SegmentedButton<MarginUnit>(
                          style: SegmentedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.symmetric(horizontal: 4.w),
                            textStyle: TextStyle(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(
                              value: MarginUnit.inch,
                              label: Text("in"),
                            ),
                            ButtonSegment(
                              value: MarginUnit.cm,
                              label: Text("cm"),
                            ),
                            ButtonSegment(
                              value: MarginUnit.pt,
                              label: Text("pt"),
                            ),
                          ],
                          selected: {selectedUnit},
                          onSelectionChanged: (newVal) {
                            setBottomSheetState(() {
                              selectedUnit = newVal.first;
                            });
                          },
                        ),
                      ],
                    ),
                    Gap(12.h),

                    // Main Row: Thumbnail with live margin marking on Left, 2x2 Grid of Margin Adjusters on Right (MainAxisAlignment.spaceBetween)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // 1. Interactive Page Thumbnail with live margin markings
                        _buildMarginThumbnail(
                          top: _marginTop ?? 36.0,
                          bottom: _marginBottom ?? 36.0,
                          left: _marginLeft ?? 36.0,
                          right: _marginRight ?? 36.0,
                          isDark: isDark,
                          theme: theme,
                        ),

                        // 2. 2x2 Grid of Margin Adjusters (Top, Bottom, Left, Right)
                        SizedBox(
                          width: 215.w,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Top Row: Top & Bottom
                              Row(
                                children: [
                                  Expanded(
                                    child: _MarginBoxAdjuster(
                                      label: "Top",
                                      icon: Icons.vertical_align_top_rounded,
                                      valuePt: _marginTop ?? 36.0,
                                      unit: selectedUnit,
                                      isDark: isDark,
                                      theme: theme,
                                      onPtChanged: (val) {
                                        setState(() => _marginTop = val);
                                        setBottomSheetState(() {});
                                        _checkAutoPageCreation();
                                        _scheduleDebouncedAutoSave();
                                      },
                                    ),
                                  ),
                                  Gap(8.w),
                                  Expanded(
                                    child: _MarginBoxAdjuster(
                                      label: "Bottom",
                                      icon: Icons.vertical_align_bottom_rounded,
                                      valuePt: _marginBottom ?? 36.0,
                                      unit: selectedUnit,
                                      isDark: isDark,
                                      theme: theme,
                                      onPtChanged: (val) {
                                        setState(() => _marginBottom = val);
                                        setBottomSheetState(() {});
                                        _checkAutoPageCreation();
                                        _scheduleDebouncedAutoSave();
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              Gap(8.h),
                              // Bottom Row: Left & Right
                              Row(
                                children: [
                                  Expanded(
                                    child: _MarginBoxAdjuster(
                                      label: "Left",
                                      icon: Icons.align_horizontal_left_rounded,
                                      valuePt: _marginLeft ?? 36.0,
                                      unit: selectedUnit,
                                      isDark: isDark,
                                      theme: theme,
                                      onPtChanged: (val) {
                                        setState(() => _marginLeft = val);
                                        setBottomSheetState(() {});
                                        _checkAutoPageCreation();
                                        _scheduleDebouncedAutoSave();
                                      },
                                    ),
                                  ),
                                  Gap(8.w),
                                  Expanded(
                                    child: _MarginBoxAdjuster(
                                      label: "Right",
                                      icon:
                                          Icons.align_horizontal_right_rounded,
                                      valuePt: _marginRight ?? 36.0,
                                      unit: selectedUnit,
                                      isDark: isDark,
                                      theme: theme,
                                      onPtChanged: (val) {
                                        setState(() => _marginRight = val);
                                        setBottomSheetState(() {});
                                        _checkAutoPageCreation();
                                        _scheduleDebouncedAutoSave();
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Gap(10.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _marginTop = 36.0;
                              _marginBottom = 36.0;
                              _marginLeft = 36.0;
                              _marginRight = 36.0;
                            });
                            setBottomSheetState(() {});
                            _checkAutoPageCreation();
                            _scheduleDebouncedAutoSave();
                          },
                          icon: Icon(Icons.restart_alt_rounded, size: 14.sp),
                          label: Text(
                            "Reset (0.5 in)",
                            style: TextStyle(fontSize: 11.sp),
                          ),
                        ),
                      ],
                    ),
                    Gap(12.h),
                    Divider(
                      color: isDark ? Colors.white12 : Colors.grey.shade200,
                    ),
                    Gap(12.h),

                    // Section 3: Page Color (Final Export/Print Color)
                    Row(
                      children: [
                        Icon(
                          Icons.palette_outlined,
                          size: 16.sp,
                          color: theme.colorScheme.primary,
                        ),
                        Gap(6.w),
                        Text(
                          "Page Color (Print & Export)",
                          style: GoogleFonts.inter(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    Gap(4.h),
                    Text(
                      "The actual background color of the exported PDF document.",
                      style: GoogleFonts.inter(
                        fontSize: 11.sp,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                    ),
                    Gap(10.h),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildColorSwatch(
                            label: "White",
                            color: Colors.white,
                            isSelected:
                                _pageColor == null ||
                                _pageColor == Colors.white,
                            isDark: isDark,
                            onTap: () {
                              setState(() => _pageColor = Colors.white);
                              setBottomSheetState(() {});
                              _updateQuillJson();
                              _scheduleDebouncedAutoSave();
                            },
                          ),
                          _buildColorSwatch(
                            label: "Cream",
                            color: const Color(0xFFFAF8F5),
                            isSelected: _pageColor?.toARGB32() == 0xFFFAF8F5,
                            isDark: isDark,
                            onTap: () {
                              setState(
                                () => _pageColor = const Color(0xFFFAF8F5),
                              );
                              setBottomSheetState(() {});
                              _updateQuillJson();
                              _scheduleDebouncedAutoSave();
                            },
                          ),
                          _buildColorSwatch(
                            label: "Ivory",
                            color: const Color(0xFFFBF7EE),
                            isSelected: _pageColor?.toARGB32() == 0xFFFBF7EE,
                            isDark: isDark,
                            onTap: () {
                              setState(
                                () => _pageColor = const Color(0xFFFBF7EE),
                              );
                              setBottomSheetState(() {});
                              _updateQuillJson();
                              _scheduleDebouncedAutoSave();
                            },
                          ),
                          _buildColorSwatch(
                            label: "Mint",
                            color: const Color(0xFFF0FDF4),
                            isSelected: _pageColor?.toARGB32() == 0xFFF0FDF4,
                            isDark: isDark,
                            onTap: () {
                              setState(
                                () => _pageColor = const Color(0xFFF0FDF4),
                              );
                              setBottomSheetState(() {});
                              _updateQuillJson();
                              _scheduleDebouncedAutoSave();
                            },
                          ),
                          _buildColorSwatch(
                            label: "Ice Blue",
                            color: const Color(0xFFF0F9FF),
                            isSelected: _pageColor?.toARGB32() == 0xFFF0F9FF,
                            isDark: isDark,
                            onTap: () {
                              setState(
                                () => _pageColor = const Color(0xFFF0F9FF),
                              );
                              setBottomSheetState(() {});
                              _updateQuillJson();
                              _scheduleDebouncedAutoSave();
                            },
                          ),
                          _buildColorSwatch(
                            label: "Lavender",
                            color: const Color(0xFFFAF5FF),
                            isSelected: _pageColor?.toARGB32() == 0xFFFAF5FF,
                            isDark: isDark,
                            onTap: () {
                              setState(
                                () => _pageColor = const Color(0xFFFAF5FF),
                              );
                              setBottomSheetState(() {});
                              _updateQuillJson();
                              _scheduleDebouncedAutoSave();
                            },
                          ),
                          _buildColorSwatch(
                            label: "Peach",
                            color: const Color(0xFFFFF7ED),
                            isSelected: _pageColor?.toARGB32() == 0xFFFFF7ED,
                            isDark: isDark,
                            onTap: () {
                              setState(
                                () => _pageColor = const Color(0xFFFFF7ED),
                              );
                              setBottomSheetState(() {});
                              _updateQuillJson();
                              _scheduleDebouncedAutoSave();
                            },
                          ),
                          _buildColorSwatch(
                            label: "Slate",
                            color: const Color(0xFF1E293B),
                            isSelected: _pageColor?.toARGB32() == 0xFF1E293B,
                            isDark: isDark,
                            onTap: () {
                              setState(
                                () => _pageColor = const Color(0xFF1E293B),
                              );
                              setBottomSheetState(() {});
                              _updateQuillJson();
                              _scheduleDebouncedAutoSave();
                            },
                          ),
                          _buildColorSwatch(
                            label: "Midnight",
                            color: const Color(0xFF0F172A),
                            isSelected: _pageColor?.toARGB32() == 0xFF0F172A,
                            isDark: isDark,
                            onTap: () {
                              setState(
                                () => _pageColor = const Color(0xFF0F172A),
                              );
                              setBottomSheetState(() {});
                              _updateQuillJson();
                              _scheduleDebouncedAutoSave();
                            },
                          ),
                        ],
                      ),
                    ),
                    Gap(16.h),

                    // Section 4: Writing / Reading Comfort Background (View Only)
                    Row(
                      children: [
                        Icon(
                          Icons.visibility_outlined,
                          size: 16.sp,
                          color: theme.colorScheme.primary,
                        ),
                        Gap(6.w),
                        Text(
                          "Writing Background (View Only)",
                          style: GoogleFonts.inter(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    Gap(4.h),
                    Text(
                      "Comfort view for writing without altering font colors or the exported PDF page color.",
                      style: GoogleFonts.inter(
                        fontSize: 11.sp,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                    ),
                    Gap(10.h),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildColorSwatch(
                            label: "Auto (Page)",
                            color: _pageColor ?? Colors.white,
                            isSelected: _writingBgColor == null,
                            isDark: isDark,
                            onTap: () {
                              setState(() => _writingBgColor = null);
                              setBottomSheetState(() {});
                            },
                          ),
                          _buildColorSwatch(
                            label: "Paper",
                            color: Colors.white,
                            isSelected: _writingBgColor == Colors.white,
                            isDark: isDark,
                            onTap: () {
                              setState(() => _writingBgColor = Colors.white);
                              setBottomSheetState(() {});
                            },
                          ),
                          _buildColorSwatch(
                            label: "Sepia",
                            color: const Color(0xFFF4ECD8),
                            isSelected:
                                _writingBgColor?.toARGB32() == 0xFFF4ECD8,
                            isDark: isDark,
                            onTap: () {
                              setState(
                                () => _writingBgColor = const Color(0xFFF4ECD8),
                              );
                              setBottomSheetState(() {});
                            },
                          ),
                          _buildColorSwatch(
                            label: "Eye-Care",
                            color: const Color(0xFFEAF5EA),
                            isSelected:
                                _writingBgColor?.toARGB32() == 0xFFEAF5EA,
                            isDark: isDark,
                            onTap: () {
                              setState(
                                () => _writingBgColor = const Color(0xFFEAF5EA),
                              );
                              setBottomSheetState(() {});
                            },
                          ),
                          _buildColorSwatch(
                            label: "Charcoal",
                            color: const Color(0xFF222226),
                            isSelected:
                                _writingBgColor?.toARGB32() == 0xFF222226,
                            isDark: isDark,
                            onTap: () {
                              setState(
                                () => _writingBgColor = const Color(0xFF222226),
                              );
                              setBottomSheetState(() {});
                            },
                          ),
                          _buildColorSwatch(
                            label: "Slate Dark",
                            color: const Color(0xFF1E293B),
                            isSelected:
                                _writingBgColor?.toARGB32() == 0xFF1E293B,
                            isDark: isDark,
                            onTap: () {
                              setState(
                                () => _writingBgColor = const Color(0xFF1E293B),
                              );
                              setBottomSheetState(() {});
                            },
                          ),
                          _buildColorSwatch(
                            label: "OLED Black",
                            color: const Color(0xFF000000),
                            isSelected:
                                _writingBgColor?.toARGB32() == 0xFF000000,
                            isDark: isDark,
                            onTap: () {
                              setState(
                                () => _writingBgColor = const Color(0xFF000000),
                              );
                              setBottomSheetState(() {});
                            },
                          ),
                        ],
                      ),
                    ),
                    Gap(20.h),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildColorSwatch({
    required String label,
    required Color color,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final isLightColor = color.computeLuminance() > 0.5;
    return Padding(
      padding: EdgeInsets.only(right: 12.w),
      child: InkWell(
        onTap: onTap,
        borderRadius: allradius(12.r),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38.r,
              height: 38.r,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF6366F1)
                      : (isDark ? Colors.white24 : Colors.black12),
                  width: isSelected ? 2.5 : 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: isSelected
                  ? Center(
                      child: Icon(
                        Icons.check_rounded,
                        size: 18.sp,
                        color: isLightColor ? Colors.black87 : Colors.white,
                      ),
                    )
                  : null,
            ),
            Gap(4.h),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10.sp,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarginThumbnail({
    required double top,
    required double bottom,
    required double left,
    required double right,
    required bool isDark,
    required ThemeData theme,
  }) {
    const double thumbWidth = 92.0;
    const double thumbHeight = 130.0;
    final double docW = _pageWidth ?? 595.28;
    final double docH = _pageHeight ?? 841.89;

    final double sX = thumbWidth / docW;
    final double sY = thumbHeight / docH;

    final double t = (top * sY).clamp(4.0, thumbHeight * 0.38);
    final double b = (bottom * sY).clamp(4.0, thumbHeight * 0.38);
    final double l = (left * sX).clamp(4.0, thumbWidth * 0.38);
    final double r = (right * sX).clamp(4.0, thumbWidth * 0.38);

    final double printableW = (thumbWidth - l - r).clamp(12.0, thumbWidth);
    final double printableH = (thumbHeight - t - b).clamp(12.0, thumbHeight);

    return Container(
      width: thumbWidth,
      height: thumbHeight,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF28282B) : Colors.white,
        borderRadius: allradius(8.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isDark ? Colors.white24 : Colors.grey.shade300,
          width: 1.2,
        ),
      ),
      child: Stack(
        children: [
          // Shaded margin outer regions
          Positioned.fill(
            child: Container(
              color: theme.colorScheme.primary.withValues(alpha: 0.05),
            ),
          ),

          // Printable area interior
          Positioned(
            left: l,
            top: t,
            width: printableW,
            height: printableH,
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E20) : Colors.white,
                borderRadius: allradius(3.r),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.4),
                  width: 1,
                ),
              ),
              padding: EdgeInsets.all(3.r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Container(
                    height: 2.5.h,
                    width: printableW * 0.6,
                    color: theme.colorScheme.primary.withValues(alpha: 0.4),
                  ),
                  Container(
                    height: 2.h,
                    width: printableW * 0.85,
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                  ),
                  Container(
                    height: 2.h,
                    width: printableW * 0.7,
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                  ),
                ],
              ),
            ),
          ),

          // L-shaped Corner crop marks on thumbnail
          Positioned(
            left: l,
            top: t,
            width: printableW,
            height: printableH,
            child: IgnorePointer(
              child: CustomPaint(
                painter: MarginGuidePainter(
                  isDark: isDark,
                  guideColor: theme.colorScheme.primary.withValues(alpha: 0.7),
                ),
              ),
            ),
          ),

          // Mini dimension badges
          Positioned(
            top: 2,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                "${top.toInt()}pt",
                style: TextStyle(
                  fontSize: 7.sp,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 2,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                "${bottom.toInt()}pt",
                style: TextStyle(
                  fontSize: 7.sp,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final overlays = _document.overlays;

    final effectivePaperColor = _writingBgColor ?? _pageColor ?? Colors.white;
    final isPaperDark = effectivePaperColor.computeLuminance() < 0.5;
    final defaultTextColor = isPaperDark
        ? const Color(0xFFF9FAFB)
        : const Color(0xFF111827);
    final secondaryTextColor = isPaperDark
        ? Colors.grey.shade400
        : Colors.grey.shade600;

    // Selected element
    WriterElement? selectedEl;
    if (_selectedElementId != null) {
      try {
        selectedEl = overlays.firstWhere((e) => e.id == _selectedElementId);
      } catch (_) {}
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await onBack();
      },
      child: Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF121212)
            : Colors.grey.shade100,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                borderRadius: allradius(999.r),
                onTap: () => onBack(),
                child: Padding(
                  padding: EdgeInsets.all(6.r),
                  child: Icon(Icons.arrow_back_ios_new_rounded, size: 18.sp),
                ),
              ),
              if (_isAutoSaving)
                Padding(
                  padding: EdgeInsets.only(right: 4.w),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 14.r,
                        height: 14.r,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.r,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      Gap(6.w),
                      Text(
                        "Autosaving...",
                        style: GoogleFonts.inter(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              InkWell(
                borderRadius: allradius(999.r),
                onTap: () =>
                    _showMoreOptionsBottomSheet(context, theme, isDark),
                child: Padding(
                  padding: EdgeInsets.all(6.r),
                  child: Icon(Icons.more_vert_rounded, size: 18.sp),
                ),
              ),
            ],
          ),
        ),
        body: _isSaving
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    Gap(16),
                    Text("Compiling and saving your document..."),
                  ],
                ),
              )
            : Column(
                children: [
                  // Floating command row formatting toolbar
                  Container(
                    margin: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 8.h,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      borderRadius: allradius(12.r),
                      border: Border.all(
                        color: isDark ? Colors.white10 : Colors.grey.shade200,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.35 : 0.08,
                          ),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4.w),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.add),
                                tooltip: "Add Element (Insert)",
                                visualDensity: VisualDensity.compact,
                                onPressed: () =>
                                    _showAddOverlayMenu(context, theme, isDark),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 24.h,
                          color: isDark ? Colors.white12 : Colors.grey.shade300,
                          margin: EdgeInsets.symmetric(horizontal: 4.w),
                        ),
                        Expanded(
                          child: QuillSimpleToolbar(
                            controller: _quillController,
                            config: QuillSimpleToolbarConfig(
                              multiRowsDisplay: false,
                              showFontFamily: true,
                              showFontSize: true,
                              buttonOptions: QuillSimpleToolbarButtonOptions(
                                fontSize: QuillToolbarFontSizeButtonOptions(
                                  items: const {
                                    '8 pt': '8',
                                    '9 pt': '9',
                                    '10 pt': '10',
                                    '11 pt': '11',
                                    '12 pt': '12',
                                    '14 pt': '14',
                                    '16 pt': '16',
                                    '18 pt': '18',
                                    '20 pt': '20',
                                    '24 pt': '24',
                                    '28 pt': '28',
                                    '32 pt': '32',
                                    '36 pt': '36',
                                    '48 pt': '48',
                                    '72 pt': '72',
                                    'Clear Size': '0',
                                  },
                                ),
                              ),
                              showBoldButton: true,
                              showItalicButton: true,
                              showUnderLineButton: true,
                              showStrikeThrough: true,
                              showColorButton: true,
                              showBackgroundColorButton: true,
                              showLink: true,
                              showAlignmentButtons: true,
                              showListNumbers: true,
                              showListBullets: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Single unified whiteboard canvas (Google Docs & Notes app style)
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF141416)
                            : Colors.grey.shade200,
                      ),
                      child: Center(
                        child: Container(
                          constraints: BoxConstraints(maxWidth: 720.w),
                          margin: EdgeInsets.symmetric(
                            vertical: 12.h,
                            horizontal: 12.w,
                          ),
                          decoration: BoxDecoration(
                            color: effectivePaperColor,
                            borderRadius: allradius(12.r),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.12)
                                  : Colors.black.withValues(alpha: 0.08),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: isDark ? 0.45 : 0.08,
                                ),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: allradius(12.r),
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                if (_selectedElementId != null) {
                                  setState(() {
                                    _selectedElementId = null;
                                  });
                                }
                                if (!_editorFocusNode.hasFocus) {
                                  _editorFocusNode.requestFocus();
                                }
                              },
                              child: Stack(
                                children: [
                                  // 1. Fluid Scrollable Quill Text Editor
                                  Positioned.fill(
                                    child: QuillEditor.basic(
                                      controller: _quillController,
                                      focusNode: _editorFocusNode,
                                      config: QuillEditorConfig(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 20.w,
                                          vertical: 20.h,
                                        ),
                                        autoFocus: true,
                                        expands: false,
                                        scrollable: true,
                                        customStyles: DefaultStyles(
                                          paragraph: DefaultTextBlockStyle(
                                            GoogleFonts.inter(
                                              fontSize: 13.sp,
                                              color: defaultTextColor,
                                              height: 1.5,
                                            ),
                                            const HorizontalSpacing(0, 0),
                                            const VerticalSpacing(0, 0),
                                            const VerticalSpacing(0, 0),
                                            null,
                                          ),
                                          h1: DefaultTextBlockStyle(
                                            GoogleFonts.outfit(
                                              fontSize: 24.sp,
                                              fontWeight: FontWeight.bold,
                                              color: defaultTextColor,
                                              height: 1.3,
                                            ),
                                            const HorizontalSpacing(0, 0),
                                            const VerticalSpacing(8, 4),
                                            const VerticalSpacing(0, 0),
                                            null,
                                          ),
                                          h2: DefaultTextBlockStyle(
                                            GoogleFonts.outfit(
                                              fontSize: 20.sp,
                                              fontWeight: FontWeight.bold,
                                              color: defaultTextColor,
                                              height: 1.3,
                                            ),
                                            const HorizontalSpacing(0, 0),
                                            const VerticalSpacing(6, 3),
                                            const VerticalSpacing(0, 0),
                                            null,
                                          ),
                                          h3: DefaultTextBlockStyle(
                                            GoogleFonts.outfit(
                                              fontSize: 16.sp,
                                              fontWeight: FontWeight.w600,
                                              color: defaultTextColor,
                                              height: 1.3,
                                            ),
                                            const HorizontalSpacing(0, 0),
                                            const VerticalSpacing(4, 2),
                                            const VerticalSpacing(0, 0),
                                            null,
                                          ),
                                          lists: DefaultListBlockStyle(
                                            GoogleFonts.inter(
                                              fontSize: 13.sp,
                                              color: defaultTextColor,
                                              height: 1.5,
                                            ),
                                            const HorizontalSpacing(0, 0),
                                            const VerticalSpacing(2, 2),
                                            const VerticalSpacing(0, 0),
                                            null,
                                            null,
                                          ),
                                          quote: DefaultTextBlockStyle(
                                            GoogleFonts.inter(
                                              fontSize: 13.sp,
                                              fontStyle: FontStyle.italic,
                                              color: secondaryTextColor,
                                              height: 1.5,
                                            ),
                                            const HorizontalSpacing(12, 12),
                                            const VerticalSpacing(6, 6),
                                            const VerticalSpacing(0, 0),
                                            BoxDecoration(
                                              border: Border(
                                                left: BorderSide(
                                                  color:
                                                      theme.colorScheme.primary,
                                                  width: 3.w,
                                                ),
                                              ),
                                            ),
                                          ),
                                          code: DefaultTextBlockStyle(
                                            GoogleFonts.jetBrainsMono(
                                              fontSize: 12.sp,
                                              color: defaultTextColor,
                                            ),
                                            const HorizontalSpacing(6, 6),
                                            const VerticalSpacing(4, 4),
                                            const VerticalSpacing(0, 0),
                                            BoxDecoration(
                                              color: isPaperDark
                                                  ? Colors.white.withValues(
                                                      alpha: 0.08,
                                                    )
                                                  : Colors.black.withValues(
                                                      alpha: 0.05,
                                                    ),
                                              borderRadius:
                                                  allradius(4.r),
                                            ),
                                          ),
                                        ),
                                        embedBuilders: [
                                          LocalImageEmbedBuilder(),
                                          ShapeEmbedBuilder(),
                                        ],
                                      ),
                                    ),
                                  ),

                                  // 2. Positioned Layout for Overlays (Images / Shapes)
                                  ...overlays.map((el) {
                                    final isSel = el.id == _selectedElementId;
                                    return ResizeDragWrapper(
                                      x: el.x,
                                      y: el.y,
                                      width: el.width,
                                      height: el.height,
                                      isSelected: isSel,
                                      onTap: () {
                                        setState(() {
                                          _selectedElementId = el.id;
                                        });
                                      },
                                      onDoubleTap: () {},
                                      onLongPress: () {
                                        if (el.type == ElementType.image) {
                                          _showImageLongPressPrompt(el);
                                        } else {
                                          setState(() {
                                            _selectedElementId = el.id;
                                          });
                                        }
                                      },
                                      onRectChanged: (newRect) {
                                        final newX = newRect.left.clamp(
                                          0.0,
                                          720.w - newRect.width,
                                        );
                                        final newY = newRect.top.clamp(
                                          0.0,
                                          2000.0,
                                        );
                                        _updateElement(
                                          el.copyWith(
                                            x: newX,
                                            y: newY,
                                            width: newRect.width,
                                            height: newRect.height,
                                          ),
                                        );
                                      },
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          _buildElementOnCanvas(el),
                                          if (isSel)
                                            Positioned(
                                              top: 2,
                                              right: 2,
                                              child: Container(
                                                padding: EdgeInsets.all(2.r),
                                                decoration: const BoxDecoration(
                                                  color: Colors.redAccent,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: GestureDetector(
                                                  onTap: () =>
                                                      _deleteElement(el.id),
                                                  child: Icon(
                                                    Icons.close,
                                                    size: 12.sp,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Slide-in glassmorphic settings inspector panel
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, animation) {
                      final curvedAnimation = CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOut,
                      );
                      return SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.2),
                          end: Offset.zero,
                        ).animate(curvedAnimation),
                        child: FadeTransition(
                          opacity: curvedAnimation,
                          child: child,
                        ),
                      );
                    },
                    child: selectedEl != null
                        ? KeyedSubtree(
                            key: ValueKey(selectedEl.id),
                            child: _buildInspectorToolbar(selectedEl, isDark),
                          )
                        : const SizedBox.shrink(
                            key: ValueKey('empty_inspector'),
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  // --- INSPECTOR TOOLBAR ---

  Widget _buildInspectorToolbar(WriterElement el, bool isDark) {
    return Container(
      margin: EdgeInsets.only(left: 16.w, right: 16.w, bottom: 20.h),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xE61E1E24)
            : Colors.white.withValues(alpha: 0.95),
        borderRadius: allradius(18.r),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  "${el.type.name.toUpperCase()} OVERLAY OPTIONS",
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 12.sp,
                    letterSpacing: 0.8,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.check_rounded, color: Colors.green),
                    tooltip: "Confirm / Done",
                    onPressed: () {
                      setState(() {
                        _selectedElementId = null;
                      });
                    },
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.redAccent,
                    ),
                    tooltip: "Delete",
                    onPressed: () => _deleteElement(el.id),
                  ),
                ],
              ),
            ],
          ),
          const Divider(),
          if (el.type == ElementType.image) _buildImageInspector(el),
          if (el.type == ElementType.shape) _buildShapeInspector(el, isDark),
        ],
      ),
    );
  }

  // Image manipulation panel (rotation, crop)
  Widget _buildImageInspector(WriterElement el) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.rotate_right_rounded, size: 20),
            Gap(8.w),
            const Text("Rotation"),
            Expanded(
              child: Slider(
                value: el.rotation,
                min: 0,
                max: 360,
                divisions: 36,
                onChanged: (val) {
                  _updateElement(el.copyWith(rotation: val));
                },
              ),
            ),
            Text("${el.rotation.toInt()}°"),
          ],
        ),
        const Text("Crop Controls (Percent)"),
        Row(
          children: [
            const Text("L:"),
            Expanded(
              child: Slider(
                value: el.cropLeft,
                min: 0,
                max: 0.9,
                onChanged: (val) {
                  if (val + el.cropRight < 1.0) {
                    _updateElement(el.copyWith(cropLeft: val));
                  }
                },
              ),
            ),
            const Text("R:"),
            Expanded(
              child: Slider(
                value: el.cropRight,
                min: 0,
                max: 0.9,
                onChanged: (val) {
                  if (el.cropLeft + val < 1.0) {
                    _updateElement(el.copyWith(cropRight: val));
                  }
                },
              ),
            ),
          ],
        ),
        Row(
          children: [
            const Text("T:"),
            Expanded(
              child: Slider(
                value: el.cropTop,
                min: 0,
                max: 0.9,
                onChanged: (val) {
                  if (val + el.cropBottom < 1.0) {
                    _updateElement(el.copyWith(cropTop: val));
                  }
                },
              ),
            ),
            const Text("B:"),
            Expanded(
              child: Slider(
                value: el.cropBottom,
                min: 0,
                max: 0.9,
                onChanged: (val) {
                  if (el.cropTop + val < 1.0) {
                    _updateElement(el.copyWith(cropBottom: val));
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Shapes panel
  Widget _buildShapeInspector(WriterElement el, bool isDark) {
    final fillColor = el.fillColorValue != null
        ? Color(el.fillColorValue!)
        : Colors.transparent;
    final borderColor = el.borderColorValue != null
        ? Color(el.borderColorValue!)
        : Colors.black;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Shape Type Toggles
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Shape Type: "),
            Flexible(
              child: SegmentedButton<ShapeType>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: ShapeType.rectangle,
                    label: Text("Rect"),
                  ),
                  ButtonSegment(value: ShapeType.circle, label: Text("Circle")),
                  ButtonSegment(value: ShapeType.oval, label: Text("Oval")),
                ],
                selected: {el.shapeType ?? ShapeType.rectangle},
                onSelectionChanged: (val) {
                  _updateElement(el.copyWith(shapeType: val.first));
                },
              ),
            ),
          ],
        ),
        Gap(12.h),

        // Border Width
        Row(
          children: [
            const Text("Border Width:"),
            Expanded(
              child: Slider(
                value: el.borderWidth,
                min: 0,
                max: 10,
                onChanged: (val) {
                  _updateElement(el.copyWith(borderWidth: val));
                },
              ),
            ),
            Text(el.borderWidth.toStringAsFixed(1)),
          ],
        ),

        // Fill Color
        const Text("Fill Color:"),
        _buildShapeColorPicker(
          selectedColor: fillColor,
          onColorChanged: (newColor) {
            _updateElement(el.copyWith(fillColorValue: newColor.toARGB32()));
          },
        ),
        Gap(8.h),

        // Border Color
        const Text("Border Color:"),
        _buildShapeColorPicker(
          selectedColor: borderColor,
          onColorChanged: (newColor) {
            _updateElement(el.copyWith(borderColorValue: newColor.toARGB32()));
          },
        ),
      ],
    );
  }

  Widget _buildShapeColorPicker({
    required Color selectedColor,
    required ValueChanged<Color> onColorChanged,
  }) {
    final presets = [
      Colors.transparent,
      Colors.black,
      Colors.white,
      Colors.red,
      Colors.orange,
      Colors.yellow,
      Colors.green,
      Colors.blue,
      Colors.purple,
      Colors.teal,
    ];
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: presets.map((color) {
              final isSelected =
                  selectedColor.withValues(alpha: 1.0) ==
                  color.withValues(alpha: 1.0);
              return GestureDetector(
                onTap: () {
                  onColorChanged(color.withValues(alpha: selectedColor.a));
                },
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 4.h),
                  width: 24.r,
                  height: 24.r,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.blue : Colors.grey.shade400,
                      width: isSelected ? 2.5 : 1,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        Row(
          children: [
            const Text("Opacity:"),
            Expanded(
              child: Slider(
                value: selectedColor.a,
                min: 0.0,
                max: 1.0,
                onChanged: (val) {
                  onColorChanged(selectedColor.withValues(alpha: val));
                },
              ),
            ),
            Text("${(selectedColor.a * 100).toInt()}%"),
          ],
        ),
      ],
    );
  }
}

class _DeltaLine {
  final List<Operation> ops;
  final Map<String, dynamic>? attributes;
  _DeltaLine({required this.ops, this.attributes});
}

class MarginGuidePainter extends CustomPainter {
  final bool isDark;
  final Color? guideColor;

  MarginGuidePainter({required this.isDark, this.guideColor});

  @override
  void paint(Canvas canvas, Size size) {
    final color =
        guideColor ??
        (isDark
            ? Colors.white.withValues(alpha: 0.18)
            : const Color(0xFF6366F1).withValues(alpha: 0.22));

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // 1. Subtle dashed border around printable margin area
    const dashWidth = 4.0;
    const dashSpace = 4.0;

    // Top border
    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, 0),
        Offset(
          startX + dashWidth > size.width ? size.width : startX + dashWidth,
          0,
        ),
        paint,
      );
      startX += dashWidth + dashSpace;
    }

    // Bottom border
    startX = 0;
    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, size.height),
        Offset(
          startX + dashWidth > size.width ? size.width : startX + dashWidth,
          size.height,
        ),
        paint,
      );
      startX += dashWidth + dashSpace;
    }

    // Left border
    double startY = 0;
    while (startY < size.height) {
      canvas.drawLine(
        Offset(0, startY),
        Offset(
          0,
          startY + dashWidth > size.height ? size.height : startY + dashWidth,
        ),
        paint,
      );
      startY += dashWidth + dashSpace;
    }

    // Right border
    startY = 0;
    while (startY < size.height) {
      canvas.drawLine(
        Offset(size.width, startY),
        Offset(
          size.width,
          startY + dashWidth > size.height ? size.height : startY + dashWidth,
        ),
        paint,
      );
      startY += dashWidth + dashSpace;
    }

    // 2. Solid L-shaped corner crop marks (8px length)
    final cornerPaint = Paint()
      ..color = isDark
          ? Colors.white.withValues(alpha: 0.45)
          : const Color(0xFF6366F1).withValues(alpha: 0.55)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const cornerLength = 8.0;

    // Top-Left corner
    canvas.drawLine(
      const Offset(0, 0),
      const Offset(cornerLength, 0),
      cornerPaint,
    );
    canvas.drawLine(
      const Offset(0, 0),
      const Offset(0, cornerLength),
      cornerPaint,
    );

    // Top-Right corner
    canvas.drawLine(
      Offset(size.width, 0),
      Offset(size.width - cornerLength, 0),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(size.width, 0),
      Offset(size.width, cornerLength),
      cornerPaint,
    );

    // Bottom-Left corner
    canvas.drawLine(
      Offset(0, size.height),
      Offset(cornerLength, size.height),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(0, size.height),
      Offset(0, size.height - cornerLength),
      cornerPaint,
    );

    // Bottom-Right corner
    canvas.drawLine(
      Offset(size.width, size.height),
      Offset(size.width - cornerLength, size.height),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(size.width, size.height),
      Offset(size.width, size.height - cornerLength),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant MarginGuidePainter oldDelegate) {
    return oldDelegate.isDark != isDark || oldDelegate.guideColor != guideColor;
  }
}

enum MarginUnit { pt, inch, cm }

double _ptToUnit(double pt, MarginUnit unit) {
  switch (unit) {
    case MarginUnit.pt:
      return pt;
    case MarginUnit.inch:
      return pt / 72.0;
    case MarginUnit.cm:
      return (pt / 72.0) * 2.54;
  }
}

double _unitToPt(double val, MarginUnit unit) {
  switch (unit) {
    case MarginUnit.pt:
      return val;
    case MarginUnit.inch:
      return val * 72.0;
    case MarginUnit.cm:
      return (val / 2.54) * 72.0;
  }
}

double _getUnitStep(MarginUnit unit) {
  switch (unit) {
    case MarginUnit.pt:
      return 1.0;
    case MarginUnit.inch:
      return 0.1;
    case MarginUnit.cm:
      return 0.25;
  }
}

class _MarginBoxAdjuster extends StatefulWidget {
  final String label;
  final IconData icon;
  final double valuePt;
  final MarginUnit unit;
  final bool isDark;
  final ThemeData theme;
  final ValueChanged<double> onPtChanged;

  const _MarginBoxAdjuster({
    required this.label,
    required this.icon,
    required this.valuePt,
    required this.unit,
    required this.isDark,
    required this.theme,
    required this.onPtChanged,
  });

  @override
  State<_MarginBoxAdjuster> createState() => _MarginBoxAdjusterState();
}

class _MarginBoxAdjusterState extends State<_MarginBoxAdjuster> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: _formatValue(widget.valuePt, widget.unit),
    );
  }

  @override
  void didUpdateWidget(covariant _MarginBoxAdjuster oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.valuePt != widget.valuePt || oldWidget.unit != widget.unit) {
      final formatted = _formatValue(widget.valuePt, widget.unit);
      if (_controller.text != formatted) {
        _controller.text = formatted;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatValue(double pt, MarginUnit unit) {
    final val = _ptToUnit(pt, unit);
    switch (unit) {
      case MarginUnit.pt:
        return val % 1 == 0 ? val.toInt().toString() : val.toStringAsFixed(1);
      case MarginUnit.inch:
      case MarginUnit.cm:
        return val.toStringAsFixed(2);
    }
  }

  void _step(int direction) {
    final step = _getUnitStep(widget.unit);
    final currentUnitVal = _ptToUnit(widget.valuePt, widget.unit);
    final newUnitVal = (currentUnitVal + (direction * step)).clamp(
      _ptToUnit(5.0, widget.unit),
      _ptToUnit(150.0, widget.unit),
    );
    final newPt = _unitToPt(newUnitVal, widget.unit);
    widget.onPtChanged(newPt);
  }

  void _onSubmitted(String text) {
    final parsed = double.tryParse(text.trim());
    if (parsed != null && parsed >= 0) {
      final newPt = _unitToPt(parsed, widget.unit).clamp(5.0, 150.0);
      widget.onPtChanged(newPt);
    } else {
      _controller.text = _formatValue(widget.valuePt, widget.unit);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = widget.theme.colorScheme.primary;
    final bg = widget.isDark ? const Color(0xFF2C2C2E) : Colors.grey.shade100;
    final border = widget.isDark ? Colors.white12 : Colors.grey.shade300;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: allradius(10.r),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(widget.icon, size: 12.sp, color: primary),
              Gap(3.w),
              Expanded(
                child: Text(
                  widget.label,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 9.5.sp,
                    fontWeight: FontWeight.w600,
                    color: widget.isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          Gap(4.h),
          Row(
            children: [
              // Value input text box
              Expanded(
                child: Container(
                  height: 28.h,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: widget.isDark
                        ? const Color(0xFF1E1E1E)
                        : Colors.white,
                    borderRadius: allradius(6.r),
                    border: Border.all(color: border),
                  ),
                  child: TextField(
                    controller: _controller,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 10.5.sp,
                      fontWeight: FontWeight.bold,
                      color: widget.isDark ? Colors.white : Colors.black87,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                      suffixText: widget.unit.name,
                      suffixStyle: TextStyle(
                        fontSize: 8.sp,
                        color: Colors.grey,
                      ),
                    ),
                    onChanged: _onSubmitted,
                    onSubmitted: _onSubmitted,
                  ),
                ),
              ),
              Gap(3.w),
              // Arrow column (Up and Down arrows for +/- 1 adjustments)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () => _step(1),
                    borderRadius: allradius(4.r),
                    child: Container(
                      padding: EdgeInsets.all(2.r),
                      decoration: BoxDecoration(
                        color: widget.isDark
                            ? Colors.white12
                            : Colors.grey.shade200,
                        borderRadius: allradius(4.r),
                      ),
                      child: Icon(
                        Icons.keyboard_arrow_up_rounded,
                        size: 11.sp,
                        color: primary,
                      ),
                    ),
                  ),
                  Gap(2.h),
                  InkWell(
                    onTap: () => _step(-1),
                    borderRadius: allradius(4.r),
                    child: Container(
                      padding: EdgeInsets.all(2.r),
                      decoration: BoxDecoration(
                        color: widget.isDark
                            ? Colors.white12
                            : Colors.grey.shade200,
                        borderRadius: allradius(4.r),
                      ),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 11.sp,
                        color: primary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
