import 'dart:convert';
import 'dart:io';
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
import 'package:pdfhawk/interface/pdf_editor_page.dart';

// --- MODELS ---

enum ElementType { text, image, shape }
enum ShapeType { rectangle, circle, oval }

class WriterElement {
  final String id;
  final ElementType type;
  
  // Layout properties
  double x;
  double y;
  double width;
  double height;
  bool isOverlay;
  
  // Text specific properties (retained for elements that are text overlays if needed)
  String textContent;
  String fontFamily;
  double fontSize;
  bool isBold;
  bool isItalic;
  bool isUnderline;
  bool isStrikethrough;
  int? highlightColorValue; // ARGB int
  int? textColorValue;
  String? linkUrl;
  
  // Image specific properties
  String? imagePath;
  double rotation; // in degrees
  double cropLeft; // percentage/fraction of crop (0.0 to 1.0)
  double cropRight;
  double cropTop;
  double cropBottom;

  // Shape specific properties
  ShapeType? shapeType;
  int? fillColorValue;
  int? borderColorValue;
  double borderWidth;

  WriterElement({
    required this.id,
    required this.type,
    this.x = 20.0,
    this.y = 20.0,
    this.width = 200.0,
    this.height = 100.0,
    this.isOverlay = true,
    this.textContent = "",
    this.fontFamily = "Roboto",
    this.fontSize = 14.0,
    this.isBold = false,
    this.isItalic = false,
    this.isUnderline = false,
    this.isStrikethrough = false,
    this.highlightColorValue,
    this.textColorValue,
    this.linkUrl,
    this.imagePath,
    this.rotation = 0.0,
    this.cropLeft = 0.0,
    this.cropRight = 0.0,
    this.cropTop = 0.0,
    this.cropBottom = 0.0,
    this.shapeType,
    this.fillColorValue,
    this.borderColorValue,
    this.borderWidth = 1.0,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'isOverlay': isOverlay,
      'textContent': textContent,
      'fontFamily': fontFamily,
      'fontSize': fontSize,
      'isBold': isBold,
      'isItalic': isItalic,
      'isUnderline': isUnderline,
      'isStrikethrough': isStrikethrough,
      'highlightColorValue': highlightColorValue,
      'textColorValue': textColorValue,
      'linkUrl': linkUrl,
      'imagePath': imagePath,
      'rotation': rotation,
      'cropLeft': cropLeft,
      'cropRight': cropRight,
      'cropTop': cropTop,
      'cropBottom': cropBottom,
      'shapeType': shapeType?.name,
      'fillColorValue': fillColorValue,
      'borderColorValue': borderColorValue,
      'borderWidth': borderWidth,
    };
  }

  factory WriterElement.fromJson(Map<String, dynamic> json) {
    return WriterElement(
      id: json['id'] as String,
      type: ElementType.values.firstWhere((e) => e.name == json['type']),
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
      isOverlay: json['isOverlay'] as bool? ?? true,
      textContent: json['textContent'] as String? ?? "",
      fontFamily: json['fontFamily'] as String? ?? "Roboto",
      fontSize: (json['fontSize'] as num? ?? 14.0).toDouble(),
      isBold: json['isBold'] as bool? ?? false,
      isItalic: json['isItalic'] as bool? ?? false,
      isUnderline: json['isUnderline'] as bool? ?? false,
      isStrikethrough: json['isStrikethrough'] as bool? ?? false,
      highlightColorValue: json['highlightColorValue'] as int?,
      textColorValue: json['textColorValue'] as int?,
      linkUrl: json['linkUrl'] as String?,
      imagePath: json['imagePath'] as String?,
      rotation: (json['rotation'] as num? ?? 0.0).toDouble(),
      cropLeft: (json['cropLeft'] as num? ?? 0.0).toDouble(),
      cropRight: (json['cropRight'] as num? ?? 0.0).toDouble(),
      cropTop: (json['cropTop'] as num? ?? 0.0).toDouble(),
      cropBottom: (json['cropBottom'] as num? ?? 0.0).toDouble(),
      shapeType: json['shapeType'] != null
          ? ShapeType.values.firstWhere((e) => e.name == json['shapeType'])
          : null,
      fillColorValue: json['fillColorValue'] as int?,
      borderColorValue: json['borderColorValue'] as int?,
      borderWidth: (json['borderWidth'] as num? ?? 1.0).toDouble(),
    );
  }

  WriterElement copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
    bool? isOverlay,
    String? textContent,
    String? fontFamily,
    double? fontSize,
    bool? isBold,
    bool? isItalic,
    bool? isUnderline,
    bool? isStrikethrough,
    int? highlightColorValue,
    int? textColorValue,
    String? linkUrl,
    String? imagePath,
    double? rotation,
    double? cropLeft,
    double? cropRight,
    double? cropTop,
    double? cropBottom,
    ShapeType? shapeType,
    int? fillColorValue,
    int? borderColorValue,
    double? borderWidth,
  }) {
    return WriterElement(
      id: id,
      type: type,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      isOverlay: isOverlay ?? this.isOverlay,
      textContent: textContent ?? this.textContent,
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      isBold: isBold ?? this.isBold,
      isItalic: isItalic ?? this.isItalic,
      isUnderline: isUnderline ?? this.isUnderline,
      isStrikethrough: isStrikethrough ?? this.isStrikethrough,
      highlightColorValue: highlightColorValue ?? this.highlightColorValue,
      textColorValue: textColorValue ?? this.textColorValue,
      linkUrl: linkUrl ?? this.linkUrl,
      imagePath: imagePath ?? this.imagePath,
      rotation: rotation ?? this.rotation,
      cropLeft: cropLeft ?? this.cropLeft,
      cropRight: cropRight ?? this.cropRight,
      cropTop: cropTop ?? this.cropTop,
      cropBottom: cropBottom ?? this.cropBottom,
      shapeType: shapeType ?? this.shapeType,
      fillColorValue: fillColorValue ?? this.fillColorValue,
      borderColorValue: borderColorValue ?? this.borderColorValue,
      borderWidth: borderWidth ?? this.borderWidth,
    );
  }
}

class WriterDocumentModel {
  final String quillDeltaJson;
  final List<WriterElement> overlays;

  WriterDocumentModel({
    required this.quillDeltaJson,
    required this.overlays,
  });

  Map<String, dynamic> toJson() => {
    'quillDeltaJson': quillDeltaJson,
    'overlays': overlays.map((e) => e.toJson()).toList(),
  };

  factory WriterDocumentModel.fromJson(Map<String, dynamic> json) {
    return WriterDocumentModel(
      quillDeltaJson: json['quillDeltaJson'] as String? ?? "[]",
      overlays: (json['overlays'] as List? ?? [])
          .map((e) => WriterElement.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

// --- SHAPE PAINTER ---

class ShapePainter extends CustomPainter {
  final ShapeType shapeType;
  final Color fillColor;
  final Color borderColor;
  final double borderWidth;

  ShapePainter({
    required this.shapeType,
    required this.fillColor,
    required this.borderColor,
    required this.borderWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paintFill = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    final paintBorder = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    if (shapeType == ShapeType.rectangle) {
      canvas.drawRect(rect, paintFill);
      if (borderWidth > 0) {
        canvas.drawRect(rect, paintBorder);
      }
    } else if (shapeType == ShapeType.circle || shapeType == ShapeType.oval) {
      canvas.drawOval(rect, paintFill);
      if (borderWidth > 0) {
        canvas.drawOval(rect, paintBorder);
      }
    }
  }

  @override
  bool shouldRepaint(covariant ShapePainter oldDelegate) {
    return oldDelegate.shapeType != shapeType ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.borderWidth != borderWidth;
  }
}

// --- RESIZE / DRAG WRAPPER ---

class ResizeDragWrapper extends StatefulWidget {
  final Widget child;
  final double x;
  final double y;
  final double width;
  final double height;
  final bool isSelected;
  final ValueChanged<Rect> onRectChanged;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final VoidCallback onLongPress;

  const ResizeDragWrapper({
    super.key,
    required this.child,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.isSelected,
    required this.onRectChanged,
    required this.onTap,
    required this.onDoubleTap,
    required this.onLongPress,
  });

  @override
  State<ResizeDragWrapper> createState() => _ResizeDragWrapperState();
}

class _ResizeDragWrapperState extends State<ResizeDragWrapper> {
  @override
  Widget build(BuildContext context) {
    final handleSize = 12.r;
    final halfHandle = handleSize / 2;

    return Positioned(
      left: widget.x - (widget.isSelected ? halfHandle : 0),
      top: widget.y - (widget.isSelected ? halfHandle : 0),
      width: widget.width + (widget.isSelected ? handleSize : 0),
      height: widget.height + (widget.isSelected ? handleSize : 0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Content
          Positioned(
            left: widget.isSelected ? halfHandle : 0,
            top: widget.isSelected ? halfHandle : 0,
            width: widget.width,
            height: widget.height,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onTap,
              onDoubleTap: widget.onDoubleTap,
              onLongPress: widget.onLongPress,
              onPanUpdate: widget.isSelected
                  ? (details) {
                      widget.onRectChanged(
                        Rect.fromLTWH(
                          widget.x + details.delta.dx,
                          widget.y + details.delta.dy,
                          widget.width,
                          widget.height,
                        ),
                      );
                    }
                  : null,
              child: Container(
                decoration: BoxDecoration(
                  border: widget.isSelected
                      ? Border.all(color: Colors.blue.shade600, width: 1.5)
                      : null,
                ),
                child: widget.child,
              ),
            ),
          ),

          // Resizing Handles (only when selected)
          if (widget.isSelected) ...[
            // Top Left
            Positioned(
              left: 0,
              top: 0,
              width: handleSize,
              height: handleSize,
              child: GestureDetector(
                onPanUpdate: (details) {
                  widget.onRectChanged(
                    Rect.fromLTRB(
                      widget.x + details.delta.dx,
                      widget.y + details.delta.dy,
                      widget.x + widget.width,
                      widget.y + widget.height,
                    ),
                  );
                },
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black26, blurRadius: 2),
                    ],
                  ),
                ),
              ),
            ),

            // Top Right
            Positioned(
              right: 0,
              top: 0,
              width: handleSize,
              height: handleSize,
              child: GestureDetector(
                onPanUpdate: (details) {
                  widget.onRectChanged(
                    Rect.fromLTRB(
                      widget.x,
                      widget.y + details.delta.dy,
                      widget.x + widget.width + details.delta.dx,
                      widget.y + widget.height,
                    ),
                  );
                },
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black26, blurRadius: 2),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom Left
            Positioned(
              left: 0,
              bottom: 0,
              width: handleSize,
              height: handleSize,
              child: GestureDetector(
                onPanUpdate: (details) {
                  widget.onRectChanged(
                    Rect.fromLTRB(
                      widget.x + details.delta.dx,
                      widget.y,
                      widget.x + widget.width,
                      widget.y + widget.height + details.delta.dy,
                    ),
                  );
                },
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black26, blurRadius: 2),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom Right
            Positioned(
              right: 0,
              bottom: 0,
              width: handleSize,
              height: handleSize,
              child: GestureDetector(
                onPanUpdate: (details) {
                  widget.onRectChanged(
                    Rect.fromLTWH(
                      widget.x,
                      widget.y,
                      widget.width + details.delta.dx,
                      widget.height + details.delta.dy,
                    ),
                  );
                },
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black26, blurRadius: 2),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// --- MAIN PAGE ---

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

  // DOCX Parser
  static String parseDocxToDeltaJson(File sourceFile) {
    final delta = Delta();
    try {
      final bytes = sourceFile.readAsBytesSync();
      final archive = ZipDecoder().decodeBytes(bytes);
      final docFile = archive.findFile('word/document.xml');
      if (docFile == null) return "[]";

      final xmlContent = utf8.decode(docFile.content as List<int>);

      // Extract paragraphs (<w:p>) and text runs (<w:t>) using regex
      final pRegExp = RegExp(r'<w:p\b[^>]*>(.*?)</w:p>');
      final tRegExp = RegExp(r'<w:t\b[^>]*>(.*?)</w:t>');

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
          delta.insert(pText);
          delta.insert('\n');
        }
      }
    } catch (e) {
      debugPrint("Error parsing docx to delta: $e");
    }

    if (delta.isEmpty) {
      delta.insert("Start typing here...\n");
    }

    return jsonEncode(delta.toJson());
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
  String? _selectedElementId;
  bool _isSaving = false;

  final double _canvasWidth = 360.0;
  double get _canvasHeight => _canvasWidth * 1.414; // A4 Ratio

  @override
  void initState() {
    super.initState();

    Document quillDoc;
    List<WriterElement> restoredOverlays = [];

    if (widget.initialDeltaJson != null) {
      try {
        final list = jsonDecode(widget.initialDeltaJson!) as List;
        quillDoc = Document.fromDelta(Delta.fromJson(list));
      } catch (_) {
        quillDoc = Document();
      }
      restoredOverlays = widget.initialOverlays ?? [];
    } else if (widget.initialElements != null && widget.initialElements!.isNotEmpty) {
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
      quillDoc = Document()..insert(0, "Start typing here...\n");
    }

    _quillController = QuillController(
      document: quillDoc,
      selection: const TextSelection.collapsed(offset: 0),
    );

    _document = WriterDocumentModel(
      quillDeltaJson: jsonEncode(_quillController.document.toDelta().toJson()),
      overlays: restoredOverlays,
    );

    _quillController.addListener(() {
      _updateQuillJson();
    });

    _autoSave();
  }

  @override
  void dispose() {
    _quillController.dispose();
    super.dispose();
  }

  void _updateQuillJson() {
    setState(() {
      _document = WriterDocumentModel(
        quillDeltaJson: jsonEncode(_quillController.document.toDelta().toJson()),
        overlays: _document.overlays,
      );
    });
    _autoSave();
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
        fillColorValue: Colors.blue.shade100.toARGB32(),
        borderColorValue: Colors.blue.toARGB32(),
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
    _autoSave();
  }

  // --- COMPILATION & SAVE ---

  Future<void> _exportToPdf() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final pdf = pw.Document();

      // Standard A4 dimensions
      final pdfPageFormat = pdf_types.PdfPageFormat.a4;
      final double a4Width = pdfPageFormat.width;
      final double a4Height = pdfPageFormat.height;

      final double scaleX = a4Width / _canvasWidth;
      final double scaleY = a4Height / _canvasHeight;

      pdf.addPage(
        pw.Page(
          pageFormat: pdfPageFormat,
          margin: const pw.EdgeInsets.all(0),
          build: (pw.Context context) {
            return pw.Stack(
              children: [
                // 1. Render Flowing Quill Text elements
                pw.Positioned(
                  left: 30,
                  top: 30,
                  child: pw.SizedBox(
                    width: a4Width - 60,
                    height: a4Height - 60,
                    child: _compileQuillDeltaToPdf(_document.quillDeltaJson, a4Width - 60),
                  ),
                ),

                // 2. Render Overlay Elements placed absolutely
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
            builder: (context) => PdfEditorPage(pdfFile: outputFile),
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

  pw.Widget _compileQuillDeltaToPdf(String deltaJson, double width) {
    final List<pw.Widget> widgets = [];
    try {
      final list = jsonDecode(deltaJson) as List;
      final delta = Delta.fromJson(list);
      final lines = _splitDeltaIntoLines(delta);
      
      for (var line in lines) {
        final children = <pw.InlineSpan>[];
        
        final lineAttr = line.attributes;
        final header = lineAttr?['header'];
        final listAttr = lineAttr?['list'];
        
        double fontSize = 12.0;
        pw.Font font = pw.Font.helvetica();
        bool isBold = false;
        
        if (header == 1) {
          fontSize = 22.0;
          font = pw.Font.helveticaBold();
          isBold = true;
        } else if (header == 2) {
          fontSize = 17.0;
          font = pw.Font.helveticaBold();
          isBold = true;
        } else if (header == 3) {
          fontSize = 14.0;
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
          if (fontName == 'serif' || fontName == 'playfairDisplay' || fontName == 'lora') {
            currentFont = (bold || isBold) ? pw.Font.timesBold() : pw.Font.times();
          } else if (fontName == 'monospace' || fontName == 'robotoMono') {
            currentFont = (bold || isBold) ? pw.Font.courierBold() : pw.Font.courier();
          } else {
            currentFont = (bold || isBold) ? pw.Font.helveticaBold() : font;
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
              bg = pw.BoxDecoration(color: pdf_types.PdfColor.fromHex(backgroundHex));
            } catch (_) {}
          }
          
          final spanStyle = pw.TextStyle(
            font: currentFont,
            fontSize: fontSize,
            fontStyle: italic ? pw.FontStyle.italic : pw.FontStyle.normal,
            decoration: pw.TextDecoration.combine([
              if (underline) pw.TextDecoration.underline,
              if (strike) pw.TextDecoration.lineThrough,
            ]),
            color: textColor,
            background: bg,
          );
          
          children.add(
            pw.TextSpan(text: text, style: spanStyle),
          );
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
        
        widgets.add(pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 6),
          child: lineWidget,
        ));
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
              lines.add(_DeltaLine(ops: List.from(currentOps), attributes: op.attributes));
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
        selectedEl = overlays.firstWhere(
          (e) => e.id == _selectedElementId,
        );
      } catch (_) {}
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey.shade100,
      appBar: AppBar(
        title: Text(
          "PDF Writer Workspace",
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded),
            tooltip: "Export Document to PDF",
            onPressed: _isSaving ? null : _exportToPdf,
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
                // Quill Formatting Toolbar
                QuillSimpleToolbar(
                  controller: _quillController,
                  config: const QuillSimpleToolbarConfig(
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

                // Quick overlays toolbar
                _buildWorkspaceQuickToolbar(),

                // Visual Page Area
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(20.r),
                      child: Container(
                        width: _canvasWidth,
                        height: _canvasHeight,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8.r),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRect(
                          child: Stack(
                            children: [
                              // 1. Natural flowing Quill Text Editor
                              Positioned(
                                left: 20,
                                top: 20,
                                width: _canvasWidth - 40,
                                height: _canvasHeight - 40,
                                child: QuillEditor.basic(
                                  controller: _quillController,
                                  config: const QuillEditorConfig(
                                    autoFocus: true,
                                    expands: true,
                                    padding: EdgeInsets.zero,
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
                                  child: _buildElementOnCanvas(el),
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Element properties inspector toolbar
                if (selectedEl != null)
                  _buildInspectorToolbar(selectedEl, isDark)
                else
                  _buildSelectHelperBanner(isDark),
              ],
            ),
    );
  }

  Widget _buildWorkspaceQuickToolbar() {
    return Container(
      color: Theme.of(context).cardColor,
      padding: EdgeInsets.symmetric(vertical: 4.h, horizontal: 16.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          TextButton.icon(
            onPressed: () => _addElement(ElementType.image),
            icon: const Icon(Icons.image_rounded),
            label: const Text("Add Overlay Image"),
          ),
          TextButton.icon(
            onPressed: () => _addElement(ElementType.shape),
            icon: const Icon(Icons.category_rounded),
            label: const Text("Add Overlay Shape"),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectHelperBanner(bool isDark) {
    return Container(
      width: double.infinity,
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      padding: EdgeInsets.symmetric(vertical: 16.h),
      child: Center(
        child: Text(
          "Tap any overlay shape or image to customize or format it",
          style: GoogleFonts.instrumentSans(
            fontSize: 13.sp,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
      ),
    );
  }

  // --- INSPECTOR TOOLBAR ---

  Widget _buildInspectorToolbar(WriterElement el, bool isDark) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  "${el.type.name.toUpperCase()} Overlay Settings",
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.sp,
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.redAccent,
                    ),
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
            const Icon(Icons.rotate_right_rounded),
            Gap(4.w),
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
            SegmentedButton<ShapeType>(
              segments: const [
                ButtonSegment(value: ShapeType.rectangle, label: Text("Rect")),
                ButtonSegment(value: ShapeType.circle, label: Text("Circle")),
                ButtonSegment(value: ShapeType.oval, label: Text("Oval")),
              ],
              selected: {el.shapeType ?? ShapeType.rectangle},
              onSelectionChanged: (val) {
                _updateElement(el.copyWith(shapeType: val.first));
              },
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
