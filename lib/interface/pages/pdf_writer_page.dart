import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart' as pdf_types;
import 'package:pdf/widgets.dart' as pw;
import 'package:archive/archive.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:pdfhawk/data/models/writer_document_model.dart';
import 'package:pdfhawk/data/models/writer_element.dart';
import 'package:pdfhawk/data/res/enum.dart';
import 'package:pdfhawk/interface/builders/local_image_builder.dart';
import 'package:pdfhawk/interface/builders/shape_embed_builder.dart';
import 'package:pdfhawk/interface/pages/pdf_reader_page.dart';
import 'package:pdfhawk/interface/painters/grid_background_painter.dart';
import 'package:pdfhawk/interface/painters/shape_painter.dart';
import 'package:pdfhawk/interface/widgets/resize_drag_wrapper.dart';

class PdfWriterPage extends StatefulWidget {
  final List<WriterElement>? initialElements;
  final String? initialDeltaJson;
  final List<WriterElement>? initialOverlays;

  const PdfWriterPage({
    super.key,
    this.initialElements,
    this.initialDeltaJson,
    this.initialOverlays,
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
      if (pageWidth != null) 'pageWidth': pageWidth,
      if (pageHeight != null) 'pageHeight': pageHeight,
      if (marginTop != null) 'marginTop': marginTop,
      if (marginBottom != null) 'marginBottom': marginBottom,
      if (marginLeft != null) 'marginLeft': marginLeft,
      if (marginRight != null) 'marginRight': marginRight,
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
  Timer? _autoSaveTimer;
  String? _selectedElementId;
  bool _isSaving = false;

  double? _pageWidth;
  double? _pageHeight;
  double? _marginTop;
  double? _marginBottom;
  double? _marginLeft;
  double? _marginRight;

  final double _canvasWidth = 360.0;
  double get _canvasHeight {
    if (_pageWidth != null && _pageHeight != null && _pageWidth! > 0) {
      return _canvasWidth * (_pageHeight! / _pageWidth!);
    }
    return _canvasWidth * 1.414; // A4 Ratio
  }

  int _pageCount = 1;

  void _checkAutoPageCreation() {
    final text = _quillController.document.toPlainText();
    final lineCount = text.split('\n').length;
    final double maxEditorHeight = _canvasHeight - _editorTop - _editorBottom;
    const double approxLineHeight = 22.0;
    final int linesPerPage =
        (maxEditorHeight / approxLineHeight).floor().clamp(12, 45);

    final int calculatedPages = (lineCount / linesPerPage).ceil().clamp(1, 100);
    if (calculatedPages > _pageCount) {
      setState(() {
        _pageCount = calculatedPages;
      });
    }
  }

  void _addNewPage() {
    setState(() {
      _pageCount++;
      final currentLen = _quillController.document.length;
      _quillController.document.insert(
        currentLen > 0 ? currentLen - 1 : 0,
        '\n\n',
      );
      _quillController.updateSelection(
        TextSelection.collapsed(offset: _quillController.document.length - 1),
        ChangeSource.local,
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Added Page $_pageCount"),
        duration: const Duration(seconds: 1),
        backgroundColor: Colors.green,
      ),
    );
  }

  double get _editorScale => 360.0 / (_pageWidth ?? 595.27559);


  double get _editorLeft =>
      _marginLeft != null ? _marginLeft! * _editorScale : 20.0;
  double get _editorTop =>
      _marginTop != null ? _marginTop! * _editorScale : 20.0;
  double get _editorRight =>
      _marginRight != null ? _marginRight! * _editorScale : 20.0;
  double get _editorBottom =>
      _marginBottom != null ? _marginBottom! * _editorScale : 20.0;

  @override
  void initState() {
    super.initState();

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
        } else if (decoded.containsKey('quillDeltaJson')) {
          final list = jsonDecode(decoded['quillDeltaJson'] as String) as List;
          quillDoc = Document.fromDelta(Delta.fromJson(list));

          _pageWidth = (decoded['pageWidth'] as num?)?.toDouble();
          _pageHeight = (decoded['pageHeight'] as num?)?.toDouble();
          _marginTop = (decoded['marginTop'] as num?)?.toDouble();
          _marginBottom = (decoded['marginBottom'] as num?)?.toDouble();
          _marginLeft = (decoded['marginLeft'] as num?)?.toDouble();
          _marginRight = (decoded['marginRight'] as num?)?.toDouble();
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

    _quillController = QuillController(
      document: quillDoc,
      selection: const TextSelection.collapsed(offset: 0),
    );

    _document = WriterDocumentModel(
      quillDeltaJson: jsonEncode(_quillController.document.toDelta().toJson()),
      overlays: restoredOverlays,
      pageWidth: _pageWidth,
      pageHeight: _pageHeight,
      marginTop: _marginTop,
      marginBottom: _marginBottom,
      marginLeft: _marginLeft,
      marginRight: _marginRight,
    );

    _quillController.addListener(() {
      _checkAutoPageCreation();
      _updateQuillJson();
      if (mounted) {
        setState(() {});
      }
    });


    _autoSave();
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _quillController.dispose();
    super.dispose();
  }

  void _updateQuillJson() {
    _document = WriterDocumentModel(
      quillDeltaJson: jsonEncode(_quillController.document.toDelta().toJson()),
      overlays: _document.overlays,
      pageWidth: _pageWidth,
      pageHeight: _pageHeight,
      marginTop: _marginTop,
      marginBottom: _marginBottom,
      marginLeft: _marginLeft,
      marginRight: _marginRight,
    );
    _scheduleDebouncedAutoSave();
  }

  void _scheduleDebouncedAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 1), () {
      _autoSave();
    });
  }

  // --- AUTO-SAVE STORAGE ---

  Future<void> _autoSave() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File("${dir.path}/auto_save_writer.json");
      await file.writeAsString(jsonEncode(_document.toJson()));
    } catch (e) {
      debugPrint("Auto-save failed: $e");
    }
  }

  Future<void> _clearAutoSave() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File("${dir.path}/auto_save_writer.json");
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint("Failed to clear auto-save: $e");
    }
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
    setState(() {
      _isSaving = true;
    });

    try {
      final pdf = pw.Document();
      // Dynamic page format and dimensions
      final double pdfWidth = _pageWidth ?? pdf_types.PdfPageFormat.a4.width;
      final double pdfHeight = _pageHeight ?? pdf_types.PdfPageFormat.a4.height;
      final pdfPageFormat = pdf_types.PdfPageFormat(pdfWidth, pdfHeight);

      final double scaleX = pdfWidth / _canvasWidth;
      final double scaleY = pdfHeight / _canvasHeight;

      for (int i = 0; i < _pageCount; i++) {
        pdf.addPage(
          pw.Page(
            pageFormat: pdfPageFormat,
            margin: const pw.EdgeInsets.all(0),
            build: (pw.Context context) {
              return pw.Stack(
                children: [
                  // 1. Render Flowing Quill Text elements
                  pw.Positioned(
                    left: _editorLeft * scaleX,
                    top: _editorTop * scaleY,
                    child: pw.SizedBox(
                      width:
                          (_canvasWidth - _editorLeft - _editorRight) * scaleX,
                      height:
                          (_canvasHeight - _editorTop - _editorBottom) * scaleY,
                      child: _compileQuillDeltaToPdf(
                        _document.quillDeltaJson,
                        (_canvasWidth - _editorLeft - _editorRight) * scaleX,
                        scaleX,
                      ),
                    ),
                  ),

                  // 2. Render Overlay Elements placed absolutely on first page
                  if (i == 0)
                    ..._document.overlays.map((el) {
                      final double pdfX = el.x * scaleX;
                      final double pdfY = el.y * scaleY;
                      final double pdfW = el.width * scaleX;
                      final double pdfH = el.height * scaleY;

                      return pw.Positioned(
                        left: pdfX,
                        top: pdfY,
                        child: pw.SizedBox(
                          width: pdfW,
                          height: pdfH,
                          child: _buildPdfElementWidget(el, pdfW),
                        ),
                      );
                    }),
                ],
              );
            },
          ),
        );
      }


      final outputDir = await getApplicationDocumentsDirectory();
      final outputFile = File(
        "${outputDir.path}/WriterExport_${DateTime.now().millisecondsSinceEpoch}.pdf",
      );
      await outputFile.writeAsBytes(await pdf.save());

      await _clearAutoSave();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Document saved successfully!"),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PDFReaderPage(pdfFile: outputFile),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Export failed: $e"),
            backgroundColor: Colors.redAccent,
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

  pw.Widget _compileQuillDeltaToPdf(
    String deltaJson,
    double width,
    double scale,
  ) {
    final List<pw.Widget> widgets = [];
    try {
      final list = jsonDecode(deltaJson) as List;
      final delta = Delta.fromJson(list);
      final lines = _splitDeltaIntoLines(delta);

      for (var line in lines) {
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
                    margin: pw.EdgeInsets.symmetric(vertical: 8 * scale),
                    child: pw.Image(
                      pdfImage,
                      width: 200 * scale,
                      height: 200 * scale,
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
                final borderWidth =
                    (shapeData['borderWidth'] as num? ?? 1.0).toDouble() *
                    scale;
                final w =
                    (shapeData['width'] as num? ?? 100.0).toDouble() * scale;
                final h =
                    (shapeData['height'] as num? ?? 60.0).toDouble() * scale;

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
                    padding: pw.EdgeInsets.symmetric(vertical: 8 * scale),
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
          continue;
        }

        final children = <pw.InlineSpan>[];

        final lineAttr = line.attributes;
        final header = lineAttr?['header'];
        final listAttr = lineAttr?['list'];

        double fontSize = 12.0 * scale;
        pw.Font font = pw.Font.helvetica();
        bool isBold = false;

        if (header == 1) {
          fontSize = 22.0 * scale;
          font = pw.Font.helveticaBold();
          isBold = true;
        } else if (header == 2) {
          fontSize = 17.0 * scale;
          font = pw.Font.helveticaBold();
          isBold = true;
        } else if (header == 3) {
          fontSize = 14.0 * scale;
          font = pw.Font.helveticaBold();
          isBold = true;
        }

        for (var op in line.ops) {
          if (op.data is! String) continue;
          final text = op.data as String;
          if (text == '\n') continue;

          final attr = op.attributes;
          final bold = attr?['bold'] == true;
          final italic = attr?['italic'] == true;
          final underline = attr?['underline'] == true;
          final strike = attr?['strike'] == true;
          final colorHex = attr?['color'] as String?;
          final backgroundHex = attr?['background'] as String?;
          final fontName = attr?['font'] as String?;

          pw.Font currentFont;
          final bool isBoldText = bold || isBold;
          final fontNameLower = fontName?.toLowerCase();
          if (fontNameLower != null &&
              (fontNameLower.contains('times') ||
                  fontNameLower.contains('georgia') ||
                  fontNameLower.contains('serif') ||
                  fontNameLower.contains('playfair') ||
                  fontNameLower.contains('lora'))) {
            if (isBoldText && italic) {
              currentFont = pw.Font.timesBoldItalic();
            } else if (isBoldText) {
              currentFont = pw.Font.timesBold();
            } else if (italic) {
              currentFont = pw.Font.timesItalic();
            } else {
              currentFont = pw.Font.times();
            }
          } else if (fontNameLower != null &&
              (fontNameLower.contains('courier') ||
                  fontNameLower.contains('mono') ||
                  fontNameLower.contains('consolas') ||
                  fontNameLower.contains('code'))) {
            if (isBoldText && italic) {
              currentFont = pw.Font.courierBoldOblique();
            } else if (isBoldText) {
              currentFont = pw.Font.courierBold();
            } else if (italic) {
              currentFont = pw.Font.courierOblique();
            } else {
              currentFont = pw.Font.courier();
            }
          } else {
            if (isBoldText && italic) {
              currentFont = pw.Font.helveticaBoldOblique();
            } else if (isBoldText) {
              currentFont = pw.Font.helveticaBold();
            } else if (italic) {
              currentFont = pw.Font.helveticaOblique();
            } else {
              currentFont = isBold ? pw.Font.helveticaBold() : font;
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

          double currentFontSize = fontSize;
          if (attr != null && attr.containsKey('size')) {
            final sizeVal = attr['size'];
            if (sizeVal is num) {
              currentFontSize = sizeVal.toDouble() * scale;
            } else if (sizeVal is String) {
              final parsedNum = double.tryParse(sizeVal);
              if (parsedNum != null) {
                currentFontSize = parsedNum * scale;
              } else if (sizeVal == 'small') {
                currentFontSize = 9.0 * scale;
              } else if (sizeVal == 'large') {
                currentFontSize = 18.0 * scale;
              } else if (sizeVal == 'huge') {
                currentFontSize = 24.0 * scale;
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

        pw.Widget lineWidget = pw.RichText(
          text: pw.TextSpan(children: children),
        );

        if (listAttr == 'bullet') {
          lineWidget = pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text("•  ", style: pw.TextStyle(fontSize: fontSize)),
              pw.Expanded(child: lineWidget),
            ],
          );
        } else if (listAttr == 'ordered') {
          lineWidget = pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text("1.  ", style: pw.TextStyle(fontSize: fontSize)),
              pw.Expanded(child: lineWidget),
            ],
          );
        }

        final spaceBeforeVal = lineAttr?['spaceBefore'] as num?;
        final spaceAfterVal = lineAttr?['spaceAfter'] as num?;
        final double beforePadding = spaceBeforeVal != null
            ? spaceBeforeVal.toDouble() * scale
            : 0.0;
        final double afterPadding = spaceAfterVal != null
            ? spaceAfterVal.toDouble() * scale
            : 6.0 * scale;

        widgets.add(
          pw.Padding(
            padding: pw.EdgeInsets.only(
              top: beforePadding,
              bottom: afterPadding,
            ),
            child: lineWidget,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error compiling delta: $e");
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: widgets,
    );
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
          borderRadius: BorderRadius.circular(16.r),
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

  // --- MAIN LAYOUT ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final overlays = _document.overlays;

    // Selected element
    WriterElement? selectedEl;
    if (_selectedElementId != null) {
      try {
        selectedEl = overlays.firstWhere((e) => e.id == _selectedElementId);
      } catch (_) {}
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey.shade100,
      appBar: AppBar(
        actions: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            child: TextButton.icon(
              onPressed: _isSaving ? null : _exportToPdf,
              icon: const Icon(
                Icons.picture_as_pdf_rounded,
                color: Colors.white,
                size: 18,
              ),
              label: const Text(
                "Export",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: TextButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
            ),
          ),
        ],
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
                  margin: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: isDark ? Colors.white10 : Colors.grey.shade200,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 6,
                        offset: Offset(0, 3),
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
                              icon: const Icon(Icons.redo_rounded),
                              tooltip: "Redo",
                              visualDensity: VisualDensity.compact,
                              onPressed: _quillController.hasRedo
                                  ? () => _quillController.redo()
                                  : null,
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_box_outlined),
                              tooltip: "Add Element (Insert)",
                              visualDensity: VisualDensity.compact,
                              onPressed: () =>
                                  _showAddOverlayMenu(context, theme, isDark),
                            ),
                            IconButton(
                              icon: const Icon(Icons.post_add_rounded),
                              tooltip: "Add New Page",
                              visualDensity: VisualDensity.compact,
                              onPressed: _addNewPage,
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
                          config: const QuillSimpleToolbarConfig(
                            multiRowsDisplay: false,
                            showFontFamily: true,
                            showFontSize: true,
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

                // Visual Page Area with Figma-like dotted grid
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedElementId = null;
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF161616)
                            : Colors.grey.shade50,
                      ),
                      child: CustomPaint(
                        painter: GridBackgroundPainter(
                          dotColor: isDark
                              ? Colors.white12
                              : Colors.grey.shade300,
                        ),
                        child: Center(
                          child: SingleChildScrollView(
                            padding: EdgeInsets.symmetric(
                              vertical: 36.h,
                              horizontal: 24.w,
                            ),
                            child: Column(
                              children: List.generate(_pageCount, (pageIndex) {
                                return Column(
                                  key: ValueKey("writer_page_$pageIndex"),
                                  children: [
                                    // Canvas Indicator Badge
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 10.w,
                                        vertical: 4.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.white10
                                            : Colors.black.withValues(
                                                alpha: 0.05,
                                              ),
                                        borderRadius:
                                            BorderRadius.circular(6.r),
                                      ),
                                      child: Text(
                                        _pageWidth != null
                                            ? "Page ${pageIndex + 1} of $_pageCount • ${(_pageWidth! / 72.0).toStringAsFixed(1)}in × ${(_pageHeight! / 72.0).toStringAsFixed(1)}in (Constant Size)"
                                            : "Page ${pageIndex + 1} of $_pageCount (Constant A4 Size)",
                                        style: TextStyle(
                                          fontSize: 10.sp,
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? Colors.white54
                                              : Colors.black54,
                                        ),
                                      ),
                                    ),
                                    Gap(12.h),

                                    // Constant-sized A4 Page
                                    Container(
                                      width: _canvasWidth,
                                      height: _canvasHeight,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius:
                                            BorderRadius.circular(8.r),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: isDark ? 0.4 : 0.15,
                                            ),
                                            blurRadius: 16,
                                            offset: const Offset(0, 6),
                                          ),
                                        ],
                                      ),
                                      child: ClipRect(
                                        child: Stack(
                                          children: [
                                            // 1. Natural flowing Quill Text Editor
                                            if (pageIndex == 0)
                                              Positioned(
                                                left: _editorLeft,
                                                top: _editorTop,
                                                width:
                                                    _canvasWidth -
                                                    _editorLeft -
                                                    _editorRight,
                                                height:
                                                    _canvasHeight -
                                                    _editorTop -
                                                    _editorBottom,
                                                child: QuillEditor.basic(
                                                  controller: _quillController,
                                                  config: QuillEditorConfig(
                                                    padding: EdgeInsets.zero,
                                                    autoFocus: true,
                                                    expands: false,
                                                    placeholder:
                                                        "Start typing here...",
                                                    embedBuilders: [
                                                      LocalImageEmbedBuilder(),
                                                      ShapeEmbedBuilder(),
                                                    ],
                                                  ),
                                                ),
                                              ),

                                            // 2. Positioned Layout for Overlays (Images / Shapes)
                                            if (pageIndex == 0)
                                              ...overlays.map((el) {
                                                final isSel =
                                                    el.id ==
                                                    _selectedElementId;
                                                return ResizeDragWrapper(
                                                  x: el.x,
                                                  y: el.y,
                                                  width: el.width,
                                                  height: el.height,
                                                  isSelected: isSel,
                                                  onTap: () {
                                                    setState(() {
                                                      _selectedElementId =
                                                          el.id;
                                                    });
                                                  },
                                                  onDoubleTap: () {},
                                                  onLongPress: () {
                                                    if (el.type ==
                                                        ElementType.image) {
                                                      _showImageLongPressPrompt(
                                                        el,
                                                      );
                                                    }
                                                  },
                                                  onRectChanged: (newRect) {
                                                    _updateElement(
                                                      el.copyWith(
                                                        x: newRect.left,
                                                        y: newRect.top,
                                                        width: newRect.width,
                                                        height: newRect.height,
                                                      ),
                                                    );
                                                  },
                                                  child: _buildElementOnCanvas(
                                                    el,
                                                  ),
                                                );
                                              }),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Gap(24.h),
                                  ],
                                );
                              }),
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
                      : const SizedBox.shrink(key: ValueKey('empty_inspector')),
                ),
              ],
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
        borderRadius: BorderRadius.circular(18.r),
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
