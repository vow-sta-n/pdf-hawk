/*
 * PDF Hawk - Modern PDF Reader, Writer, Editor & Scanner
 * Copyright (C) 2026 Van Stan / Novaturients
 *
 * This software is licensed under the PolyForm Noncommercial License 1.0.0.
 * You may obtain a copy of the License at https://polyformproject.org/licenses/noncommercial/1.0.0
 */

import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:community_material_icon/community_material_icon.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_filters/flutter_image_filters.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdfhawk/data/class/editor_overlay_item.dart';
import 'package:pdfhawk/data/models/editor_filter_item.dart';
import 'package:pdfhawk/data/res/constants.dart';
import 'package:pdfhawk/data/res/enum.dart';
import 'package:pdfhawk/data/res/theme.dart';
import 'package:pdfhawk/data/res/utils.dart';
import 'package:pdfhawk/interface/dialogs/color_wheel_dialog.dart';
import 'package:pdfhawk/interface/painters/crop_overlay_painter.dart';
import 'package:pdfhawk/interface/painters/drawing_painter.dart';
import 'package:pdfhawk/interface/painters/knob_painter.dart';
import 'package:pdfhawk/interface/painters/shape_painter.dart';
import 'package:pdfhawk/interface/painters/slider_painter.dart';
import 'package:pdfhawk/logic/helpers/pdf_helper.dart';
import 'package:pdfhawk/logic/services/process_image_edit_isolate.dart';

class ImagesEditorPage extends StatefulWidget {
  final String imagePath;
  final Function(String updatedPath) onSave;

  const ImagesEditorPage({
    super.key,
    required this.imagePath,
    required this.onSave,
  });

  @override
  State<ImagesEditorPage> createState() => _ImagesEditorPageState();
}

class _ImagesEditorPageState extends State<ImagesEditorPage> {
  late String _currentPath;
  late PageController _filterPageController;
  bool _isProcessing = false;
  int _activeTab =
      0; // 0: Filters, 1: Adjust, 2: Insert/Overlay, 3: Crop & Rotate, 4: Draw

  // Overlay / Insert State
  final List<EditorOverlayItem> _overlayItems = [];
  int? _selectedOverlayIndex;
  bool _isOverlayRotateActive = false;

  // Drawing & Annotation State
  final List<DrawingPath> _drawingPaths = [];
  final List<List<DrawingPath>> _drawingUndoHistory = [];
  final List<List<DrawingPath>> _drawingRedoHistory = [];

  // Zoom & Pan Controller for Detailed Drawing
  final TransformationController _zoomTransformationController =
      TransformationController();
  double _zoomScale = 1.0;

  DrawingTool _drawingTool = DrawingTool.pen;
  Color _drawingColor = yellow;
  double _drawingStrokeWidth = 4.0;
  final List<Offset> _currentDrawingPoints = [];
  int? _selectedDrawingPathIndex;
  Offset? _eyedropperPos;
  Color? _eyedropperSampledColor;
  img.Image? _cachedDecodedImageForEyedropper;

  // Auto-bake thresholds to prevent memory bloating
  static const int _maxStrokesBeforeBake = 25;
  static const int _maxPointsBeforeBake = 800;

  int get _totalCurrentDrawingPoints {
    int count = _currentDrawingPoints.length;
    for (final p in _drawingPaths) {
      count += p.points.length;
    }
    return count;
  }

  final Map<String, Size> _imageNaturalSizes = {};

  void _resolveImageSize(String path) {
    if (_imageNaturalSizes.containsKey(path)) return;
    final file = File(path);
    if (!file.existsSync()) return;
    FileImage(file)
        .resolve(const ImageConfiguration())
        .addListener(
          ImageStreamListener((info, _) {
            final size = Size(
              info.image.width.toDouble(),
              info.image.height.toDouble(),
            );
            final hadSize = _imageNaturalSizes.containsKey(path);
            _imageNaturalSizes[path] = size;
            if (!hadSize && mounted) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {});
                }
              });
            }
          }),
        );
  }

  Rect _calculateFittedImageRect(Size containerSize, String path) {
    final imageSize = _imageNaturalSizes[path];
    if (imageSize == null || imageSize.width <= 0 || imageSize.height <= 0) {
      return Rect.fromLTWH(0, 0, containerSize.width, containerSize.height);
    }
    final FittedSizes fittedSizes = applyBoxFit(
      BoxFit.contain,
      imageSize,
      containerSize,
    );
    return Alignment.center.inscribe(
      fittedSizes.destination,
      Rect.fromLTWH(0, 0, containerSize.width, containerSize.height),
    );
  }

  // Texture & Filter Selection
  TextureSource? _currentTextureSource;
  TextureSource? _thumbnailTextureSource;
  String _selectedFilterId = 'none';

  List<EditorFilterItem> get _filters => kAppEditorFilters;

  EditorFilterItem get _selectedFilterItem =>
      getEditorFilterItem(_selectedFilterId);

  // Image Adjustments (-50.0 to 50.0)
  double _brightness = 0.0;
  double _contrast = 0.0;
  double _saturation = 0.0;

  // Rotation & Flip
  double _rotationAngle = 0.0; // 0.0 to 360.0 degrees
  bool _flipHorizontal = false;
  bool _flipVertical = false;
  bool _isRotateActive = false;

  // Crop Controls (Normalized 0.0 to 1.0)
  bool _isCropActive = false;
  double _cropLeft = 0.05;
  double _cropTop = 0.05;
  double _cropRight = 0.95;
  double _cropBottom = 0.95;
  String _selectedAspectRatio = 'Free';

  @override
  void initState() {
    super.initState();
    _currentPath = widget.imagePath;
    _filterPageController = PageController(
      viewportFraction: 0.22,
      initialPage: 0,
    );
    _zoomTransformationController.addListener(() {
      final scale = _zoomTransformationController.value.getMaxScaleOnAxis();
      if ((scale - _zoomScale).abs() > 0.01) {
        setState(() {
          _zoomScale = scale;
        });
      }
    });
    _resolveImageSize(_currentPath);
    _loadTexturesForCurrentImage();
  }

  void _resetZoom() {
    _zoomTransformationController.value = Matrix4.identity();
    setState(() {
      _zoomScale = 1.0;
    });
  }

  Future<void> _loadTexturesForCurrentImage() async {
    final file = File(_currentPath);
    if (!file.existsSync()) return;

    try {
      final tex = await TextureSource.fromFile(file);
      if (mounted) {
        setState(() {
          _currentTextureSource = tex;
          _thumbnailTextureSource = tex;
        });
      }
    } catch (e) {
      debugPrint("Error loading TextureSource: $e");
    }
  }

  @override
  void dispose() {
    _filterPageController.dispose();
    _zoomTransformationController.dispose();
    for (final f in _filters) {
      f.dispose();
    }
    super.dispose();
  }

  // History for Undo / Redo
  final List<String> _undoHistory = [];
  final List<String> _redoHistory = [];

  void _saveDrawingStateForUndo() {
    final currentClones = _drawingPaths.map((p) => p.clone()).toList();
    _drawingUndoHistory.add(currentClones);
    _drawingRedoHistory.clear();
  }

  void _undoDrawing() {
    if (_drawingUndoHistory.isEmpty) return;
    final prevState = _drawingUndoHistory.removeLast();
    _drawingRedoHistory.add(_drawingPaths.map((p) => p.clone()).toList());
    setState(() {
      _drawingPaths.clear();
      _drawingPaths.addAll(prevState.map((p) => p.clone()));
      _selectedDrawingPathIndex = null;
    });
    plainToast(msg: "Drawing Undo applied");
  }

  void _redoDrawing() {
    if (_drawingRedoHistory.isEmpty) return;
    final nextState = _drawingRedoHistory.removeLast();
    _drawingUndoHistory.add(_drawingPaths.map((p) => p.clone()).toList());
    setState(() {
      _drawingPaths.clear();
      _drawingPaths.addAll(nextState.map((p) => p.clone()));
      _selectedDrawingPathIndex = null;
    });
    plainToast(msg: "Drawing Redo applied");
  }

  void _deleteSelectedDrawingPath() {
    if (_selectedDrawingPathIndex == null ||
        _selectedDrawingPathIndex! >= _drawingPaths.length) {
      return;
    }
    _saveDrawingStateForUndo();
    setState(() {
      _drawingPaths.removeAt(_selectedDrawingPathIndex!);
      _selectedDrawingPathIndex = null;
    });
    plainToast(msg: "Selected stroke deleted");
  }

  bool get _canUndo {
    final hasDrawingUndo = _drawingUndoHistory.isNotEmpty;
    if (_activeTab == 4) {
      return hasDrawingUndo;
    }
    final hasImageUndo = _undoHistory.isNotEmpty;
    return hasDrawingUndo || hasImageUndo;
  }

  bool get _canRedo {
    final hasDrawingRedo = _drawingRedoHistory.isNotEmpty;
    if (_activeTab == 4) {
      return hasDrawingRedo;
    }
    final hasImageRedo = _redoHistory.isNotEmpty;
    return hasDrawingRedo || hasImageRedo;
  }

  void _undo() {
    final hasDrawingUndo = _drawingUndoHistory.isNotEmpty;
    if (_activeTab == 4) {
      if (hasDrawingUndo) {
        _undoDrawing();
        return;
      }
    } else if (hasDrawingUndo) {
      _undoDrawing();
      return;
    }

    if (!_canUndo || _undoHistory.isEmpty) return;
    final prevPath = _undoHistory.removeLast();
    _redoHistory.add(_currentPath);
    PaintingBinding.instance.imageCache.evict(FileImage(File(_currentPath)));
    _cachedDecodedImageForEyedropper = null;

    setState(() {
      _currentPath = prevPath;
      _resetCurrentEdits();
    });
    _loadTexturesForCurrentImage();
    plainToast(msg: "Undo applied");
  }

  void _redo() {
    final hasDrawingRedo = _drawingRedoHistory.isNotEmpty;
    if (_activeTab == 4) {
      if (hasDrawingRedo) {
        _redoDrawing();
        return;
      }
    } else if (hasDrawingRedo) {
      _redoDrawing();
      return;
    }

    if (!_canRedo || _redoHistory.isEmpty) return;
    final nextPath = _redoHistory.removeLast();
    _undoHistory.add(_currentPath);
    PaintingBinding.instance.imageCache.evict(FileImage(File(_currentPath)));
    _cachedDecodedImageForEyedropper = null;

    setState(() {
      _currentPath = nextPath;
      _resetCurrentEdits();
    });
    _loadTexturesForCurrentImage();
    plainToast(msg: "Redo applied");
  }

  bool get _hasPendingEdits {
    return _selectedFilterId != 'none' ||
        _brightness != 0.0 ||
        _contrast != 0.0 ||
        _saturation != 0.0 ||
        _rotationAngle != 0.0 ||
        _flipHorizontal ||
        _flipVertical ||
        _drawingPaths.isNotEmpty ||
        _overlayItems.isNotEmpty ||
        (_isCropActive &&
            (_cropLeft > 0.01 ||
                _cropTop > 0.01 ||
                _cropRight < 0.99 ||
                _cropBottom < 0.99));
  }

  void _resetCurrentEdits() {
    setState(() {
      _selectedFilterId = 'none';
      _brightness = 0.0;
      _contrast = 0.0;
      _saturation = 0.0;
      _rotationAngle = 0.0;
      _flipHorizontal = false;
      _flipVertical = false;
      _isRotateActive = false;
      _isOverlayRotateActive = false;
      _overlayItems.clear();
      _selectedOverlayIndex = null;
      _currentDrawingPoints.clear();
      _selectedDrawingPathIndex = null;
      _eyedropperPos = null;
      _resetCrop();
    });
    if (_filterPageController.hasClients) {
      _filterPageController.jumpToPage(0);
    }
  }

  Future<void> _sampleColorAt(Offset localPos, Size canvasSize) async {
    if (_cachedDecodedImageForEyedropper == null) {
      final file = File(_currentPath);
      if (file.existsSync()) {
        final bytes = await file.readAsBytes();
        _cachedDecodedImageForEyedropper = img.decodeImage(bytes);
      }
    }

    final decoded = _cachedDecodedImageForEyedropper;
    if (decoded == null) return;

    final normX = (localPos.dx / canvasSize.width).clamp(0.0, 1.0);
    final normY = (localPos.dy / canvasSize.height).clamp(0.0, 1.0);

    final px = (normX * (decoded.width - 1)).round().clamp(
      0,
      decoded.width - 1,
    );
    final py = (normY * (decoded.height - 1)).round().clamp(
      0,
      decoded.height - 1,
    );

    final pixel = decoded.getPixel(px, py);
    final color = Color.fromARGB(
      255,
      pixel.r.toInt(),
      pixel.g.toInt(),
      pixel.b.toInt(),
    );

    setState(() {
      _eyedropperPos = localPos;
      _eyedropperSampledColor = color;
      _drawingColor = color;
    });
  }

  Future<void> _checkAndAutoBakeStrokes() async {
    if (_drawingPaths.length >= _maxStrokesBeforeBake ||
        _totalCurrentDrawingPoints >= _maxPointsBeforeBake) {
      await _bakeStrokesDirectlyToImage(showNotification: true);
    }
  }

  Future<void> _bakeStrokesDirectlyToImage({
    bool showNotification = false,
  }) async {
    final strokes = List<DrawingPath>.from(_drawingPaths);
    if (strokes.isEmpty) return;

    try {
      final bakedFile = await _bakeStrokesToFile(_currentPath, strokes);

      _undoHistory.add(_currentPath);
      _redoHistory.clear();

      setState(() {
        _currentPath = bakedFile.path;
        _drawingPaths.clear();
        _currentDrawingPoints.clear();
        _selectedDrawingPathIndex = null;
        _cachedDecodedImageForEyedropper = null;
      });

      await _loadTexturesForCurrentImage();

      if (showNotification) {
        plainToast(msg: "Drawing merged into image to optimize memory");
      }
    } catch (e) {
      debugPrint("Error baking strokes into image: $e");
    }
  }

  Future<File> _bakeStrokesToFile(
    String imagePath,
    List<DrawingPath> strokes,
  ) async {
    final currentFile = File(imagePath);
    final imageBytes = await currentFile.readAsBytes();
    final ui.Codec codec = await ui.instantiateImageCodec(imageBytes);
    final ui.FrameInfo frameInfo = await codec.getNextFrame();
    final ui.Image baseUiImage = frameInfo.image;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final imgWidth = baseUiImage.width.toDouble();
    final imgHeight = baseUiImage.height.toDouble();

    canvas.drawImage(baseUiImage, Offset.zero, Paint());

    // 1. Render Overlays (Images, Shapes, Text)
    for (final item in _overlayItems) {
      canvas.save();
      final cx = item.position.dx * imgWidth;
      final cy = item.position.dy * imgHeight;
      final itemW = item.width * imgWidth;
      final itemH = item.height * imgHeight;

      canvas.translate(cx, cy);
      canvas.rotate(item.rotation * (pi / 180));

      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: itemW,
        height: itemH,
      );

      switch (item.type) {
        case ElementType.image:
          if (item.imagePath != null && File(item.imagePath!).existsSync()) {
            try {
              final ovBytes = await File(item.imagePath!).readAsBytes();
              final ovCodec = await ui.instantiateImageCodec(ovBytes);
              final ovFrame = await ovCodec.getNextFrame();
              final ovImage = ovFrame.image;
              final ovPaint = Paint()
                ..color = Color.fromRGBO(
                  255,
                  255,
                  255,
                  item.opacity.clamp(0.0, 1.0),
                );
              canvas.drawImageRect(
                ovImage,
                Rect.fromLTWH(
                  0,
                  0,
                  ovImage.width.toDouble(),
                  ovImage.height.toDouble(),
                ),
                rect,
                ovPaint,
              );
              ovImage.dispose();
            } catch (e) {
              debugPrint("Error baking overlay image: $e");
            }
          }
          break;

        case ElementType.shape:
          final painter = ShapePainter(
            shapeType: item.shapeType,
            fillColor: item.fillColor,
            borderColor: item.strokeColor,
            borderWidth: item.strokeWidth * (imgWidth / 360.0),
            isFilled: item.isFilled,
          );
          canvas.save();
          canvas.translate(-itemW / 2, -itemH / 2);
          painter.paint(canvas, Size(itemW, itemH));
          canvas.restore();
          break;

        case ElementType.text:
          if (item.backgroundColor != null) {
            final bgPaint = Paint()..color = item.backgroundColor!;
            canvas.drawRRect(
              RRect.fromRectAndRadius(rect, Radius.circular(itemW * 0.08)),
              bgPaint,
            );
          }
          final textSpan = TextSpan(
            text: item.text,
            style: TextStyle(
              color: item.textColor,
              fontSize: item.fontSize * (imgWidth / 360.0),
              fontWeight: item.isBold ? FontWeight.bold : FontWeight.normal,
              fontStyle: item.isItalic ? FontStyle.italic : FontStyle.normal,
            ),
          );
          final textPainter = TextPainter(
            text: textSpan,
            textAlign: TextAlign.center,
            textDirection: TextDirection.ltr,
          );
          textPainter.layout(maxWidth: itemW * 1.5);
          textPainter.paint(
            canvas,
            Offset(-textPainter.width / 2, -textPainter.height / 2),
          );
          break;
      }

      canvas.restore();
    }

    // 2. Render Drawing Strokes
    for (final stroke in strokes) {
      if (stroke.points.isEmpty) continue;
      final strokePaint = Paint()
        ..color = stroke.isHighlighter
            ? stroke.color.withValues(alpha: 0.4)
            : stroke.color
        ..strokeWidth = stroke.strokeWidth * (imgWidth / 360.0)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final path = Path();
      final first = stroke.points.first;
      path.moveTo(first.dx * imgWidth, first.dy * imgHeight);
      for (int i = 1; i < stroke.points.length; i++) {
        final pt = stroke.points[i];
        path.lineTo(pt.dx * imgWidth, pt.dy * imgHeight);
      }
      canvas.drawPath(path, strokePaint);
    }

    final picture = recorder.endRecording();
    final bakedUiImage = await picture.toImage(
      baseUiImage.width,
      baseUiImage.height,
    );
    final byteData = await bakedUiImage.toByteData(
      format: ui.ImageByteFormat.png,
    );

    final tempDir = await getTemporaryDirectory();
    final bakedFilePath =
        "${tempDir.path}/annotated_${DateTime.now().millisecondsSinceEpoch}.png";
    final bakedFile = File(bakedFilePath);
    await bakedFile.writeAsBytes(byteData!.buffer.asUint8List());

    baseUiImage.dispose();
    bakedUiImage.dispose();
    return bakedFile;
  }

  void _onDrawingPanStart(Offset localPos, Size size) {
    if (_drawingTool == DrawingTool.zoom) return;

    if (_drawingTool == DrawingTool.eyedropper) {
      _sampleColorAt(localPos, size);
      return;
    }

    if (_drawingTool == DrawingTool.select) {
      int? foundIndex;
      final normPos = Offset(
        localPos.dx / size.width,
        localPos.dy / size.height,
      );
      for (int i = _drawingPaths.length - 1; i >= 0; i--) {
        final stroke = _drawingPaths[i];
        if (stroke.hitTest(
          normPos,
          threshold: 24.0 / max(size.width, size.height),
        )) {
          foundIndex = i;
          break;
        }
      }
      if (foundIndex != null) {
        _saveDrawingStateForUndo();
      }
      setState(() {
        _selectedDrawingPathIndex = foundIndex;
      });
      return;
    }

    if (_drawingTool == DrawingTool.eraser) {
      _eraseStrokeAt(localPos, size);
      return;
    }

    setState(() {
      _selectedDrawingPathIndex = null;
      final normPt = Offset(
        (localPos.dx / size.width).clamp(0.0, 1.0),
        (localPos.dy / size.height).clamp(0.0, 1.0),
      );
      _currentDrawingPoints.clear();
      _currentDrawingPoints.add(normPt);
    });
  }

  void _onDrawingPanUpdate(Offset localPos, Offset delta, Size size) {
    if (_drawingTool == DrawingTool.zoom) return;

    if (_drawingTool == DrawingTool.eyedropper) {
      _sampleColorAt(localPos, size);
      return;
    }

    if (_drawingTool == DrawingTool.select) {
      if (_selectedDrawingPathIndex != null &&
          _selectedDrawingPathIndex! < _drawingPaths.length) {
        final normDelta = Offset(delta.dx / size.width, delta.dy / size.height);
        setState(() {
          _drawingPaths[_selectedDrawingPathIndex!].translate(normDelta);
        });
      }
      return;
    }

    if (_drawingTool == DrawingTool.eraser) {
      _eraseStrokeAt(localPos, size);
      return;
    }

    setState(() {
      final normPt = Offset(
        (localPos.dx / size.width).clamp(0.0, 1.0),
        (localPos.dy / size.height).clamp(0.0, 1.0),
      );
      _currentDrawingPoints.add(normPt);
    });
  }

  void _onDrawingPanEnd(Size size) {
    if (_drawingTool == DrawingTool.zoom) return;

    if (_drawingTool == DrawingTool.eyedropper) {
      setState(() {
        _eyedropperPos = null;
        _drawingTool = DrawingTool.pen;
      });
      plainToast(msg: "Color selected from image");
      return;
    }

    if (_drawingTool == DrawingTool.pen ||
        _drawingTool == DrawingTool.highlighter) {
      if (_currentDrawingPoints.isNotEmpty) {
        _saveDrawingStateForUndo();
        final newStroke = DrawingPath(
          points: List<Offset>.from(_currentDrawingPoints),
          color: _drawingColor,
          strokeWidth: _drawingStrokeWidth,
          isHighlighter: _drawingTool == DrawingTool.highlighter,
        );
        setState(() {
          _drawingPaths.add(newStroke);
          _currentDrawingPoints.clear();
        });
        _checkAndAutoBakeStrokes();
      } else {
        setState(() {
          _currentDrawingPoints.clear();
        });
      }
    }
  }

  void _onDrawingTapDown(Offset localPos, Size size) {
    if (_drawingTool == DrawingTool.zoom) return;

    if (_drawingTool == DrawingTool.eraser) {
      _eraseStrokeAt(localPos, size);
    } else if (_drawingTool == DrawingTool.select) {
      int? foundIndex;
      final normPos = Offset(
        localPos.dx / size.width,
        localPos.dy / size.height,
      );
      for (int i = _drawingPaths.length - 1; i >= 0; i--) {
        final stroke = _drawingPaths[i];
        if (stroke.hitTest(
          normPos,
          threshold: 24.0 / max(size.width, size.height),
        )) {
          foundIndex = i;
          break;
        }
      }
      setState(() {
        _selectedDrawingPathIndex = foundIndex;
      });
    }
  }

  void _eraseStrokeAt(Offset localPos, Size size) {
    final normPos = Offset(localPos.dx / size.width, localPos.dy / size.height);
    for (int i = _drawingPaths.length - 1; i >= 0; i--) {
      final stroke = _drawingPaths[i];
      if (stroke.hitTest(
        normPos,
        threshold: 24.0 / max(size.width, size.height),
      )) {
        _saveDrawingStateForUndo();
        setState(() {
          _drawingPaths.removeAt(i);
          if (_selectedDrawingPathIndex == i) {
            _selectedDrawingPathIndex = null;
          } else if (_selectedDrawingPathIndex != null &&
              _selectedDrawingPathIndex! > i) {
            _selectedDrawingPathIndex = _selectedDrawingPathIndex! - 1;
          }
        });
        break;
      }
    }
  }

  void _resetCrop() {
    setState(() {
      _isCropActive = false;
      _cropLeft = 0.05;
      _cropTop = 0.05;
      _cropRight = 0.95;
      _cropBottom = 0.95;
      _selectedAspectRatio = 'Free';
    });
  }

  void _applyAspectRatio(String ratioLabel) {
    setState(() {
      _selectedAspectRatio = ratioLabel;
      final currentW = _cropRight - _cropLeft;
      final centerX = (_cropLeft + _cropRight) / 2;
      final centerY = (_cropTop + _cropBottom) / 2;

      double targetRatio;
      switch (ratioLabel) {
        case '1:1':
          targetRatio = 1.0;
          break;
        case '4:3':
          targetRatio = 4 / 3;
          break;
        case '16:9':
          targetRatio = 16 / 9;
          break;
        case 'A4':
          targetRatio = 1 / 1.414;
          break;
        default:
          return;
      }

      double newW = currentW;
      double newH = newW / targetRatio;
      if (newH > 0.9) {
        newH = 0.9;
        newW = newH * targetRatio;
      }

      _cropLeft = (centerX - newW / 2).clamp(0.0, 0.9);
      _cropRight = (centerX + newW / 2).clamp(_cropLeft + 0.1, 1.0);
      _cropTop = (centerY - newH / 2).clamp(0.0, 0.9);
      _cropBottom = (centerY + newH / 2).clamp(_cropTop + 0.1, 1.0);
    });
  }

  Future<void> _applyAndSaveCurrentEdits() async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
    });

    try {
      Uint8List? shaderBytes;
      // 1. If shader filter is active, export from GPU shader
      if (_selectedFilterId != 'none') {
        try {
          final tex = await TextureSource.fromFile(File(_currentPath));
          final renderedImage = await _selectedFilterItem.config.export(
            tex,
            tex.size,
          );
          final byteData = await renderedImage.toByteData(
            format: ui.ImageByteFormat.png,
          );
          if (byteData != null) {
            shaderBytes = byteData.buffer.asUint8List();
          }
        } catch (e) {
          debugPrint("GPU shader export error: $e");
        }
      }

      final tempDir = await getTemporaryDirectory();
      final tempFilePath =
          "${tempDir.path}/scan_preview_${DateTime.now().millisecondsSinceEpoch}.jpg";

      final params = ImageEditParams(
        inputPath: _currentPath,
        outputPath: tempFilePath,
        cropLeft: _cropLeft,
        cropTop: _cropTop,
        cropRight: _cropRight,
        cropBottom: _cropBottom,
        isCropActive: _isCropActive,
        rotationAngle: _rotationAngle,
        flipHorizontal: _flipHorizontal,
        flipVertical: _flipVertical,
        contrast: _contrast,
        saturation: _saturation,
        brightness: _brightness,
        shaderProcessedBytes: shaderBytes,
      );

      final success = await compute(processImageEditsIsolate, params);

      if (success) {
        final oldPath = _currentPath;
        _undoHistory.add(oldPath);
        _redoHistory.clear();

        // Evict old file from Flutter ImageCache to free memory
        PaintingBinding.instance.imageCache.evict(FileImage(File(oldPath)));
        _cachedDecodedImageForEyedropper = null;

        setState(() {
          _currentPath = tempFilePath;
          _resetCurrentEdits();
        });
        _loadTexturesForCurrentImage();
      }
    } catch (e) {
      if (mounted) {
        plainToast(msg: "Error updating preview: $e");
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  ColorFilter _getAdjustmentColorFilter() {
    final b = _brightness * 2.55;
    final c = 1.0 + (_contrast / 50.0);
    final s = 1.0 + (_saturation / 50.0);

    final sr = (1 - s) * 0.2126;
    final sg = (1 - s) * 0.7152;
    final sb = (1 - s) * 0.0722;

    return ColorFilter.matrix(<double>[
      (sr + s) * c,
      sg * c,
      sb * c,
      0,
      b,
      sr * c,
      (sg + s) * c,
      sb * c,
      0,
      b,
      sr * c,
      sg * c,
      (sb + s) * c,
      0,
      b,
      0,
      0,
      0,
      1,
      0,
    ]);
  }

  Future<void> _onDone() async {
    // 1. Bake drawing strokes & overlays if present
    if (_drawingPaths.isNotEmpty || _overlayItems.isNotEmpty) {
      setState(() => _isProcessing = true);
      final currentFile = File(_currentPath);
      if (currentFile.existsSync()) {
        try {
          final bakedFile = await _bakeStrokesToFile(
            _currentPath,
            _drawingPaths,
          );
          _currentPath = bakedFile.path;
        } catch (e) {
          debugPrint("Error baking strokes & overlays: $e");
        }
      }
      _drawingPaths.clear();
      _overlayItems.clear();
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }

    // 2. Apply any pending filter/crop/adjustment edits
    if (_hasPendingEdits) {
      await _applyAndSaveCurrentEdits();
    }

    // 3. Save final image and notify caller
    try {
      final originalFile = File(widget.imagePath);
      final currentBakedFile = File(_currentPath);
      if (currentBakedFile.existsSync() &&
          currentBakedFile.path != originalFile.path) {
        await currentBakedFile.copy(originalFile.path);
      }
    } catch (e) {
      debugPrint("Note: Unable to overwrite original path: $e");
      plainToast(msg: "Failed to save Image");
    }
    widget.onSave(_currentPath);
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    double w = getWidth(context);
    double h = getHeight(context);
    final file = File(_currentPath);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _onDone();
      },
      child: Scaffold(
        backgroundColor: black,
        body: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: SizedBox()),
              // Preview Area
              Container(
                height: h / 1.6,
                margin: EdgeInsets.only(bottom: 50),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 6.h,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      if (!file.existsSync()) {
                        return const Center(
                          child: Text(
                            "Image file not found",
                            style: TextStyle(color: Colors.white60),
                          ),
                        );
                      }

                      _resolveImageSize(_currentPath);

                      final imageWidget = Image.file(
                        file,
                        fit: BoxFit.contain,
                        width: constraints.maxWidth,
                        height: constraints.maxHeight,
                      );

                      return Stack(
                        children: [
                          InteractiveViewer(
                            transformationController:
                                _zoomTransformationController,
                            minScale: 1.0,
                            maxScale: 8.0,
                            panEnabled:
                                _activeTab == 4 &&
                                _drawingTool == DrawingTool.zoom,
                            scaleEnabled:
                                _activeTab == 4 &&
                                _drawingTool == DrawingTool.zoom,
                            clipBehavior: Clip.hardEdge,
                            child: Stack(
                              children: [
                                Center(
                                  child: ColorFiltered(
                                    colorFilter: _getAdjustmentColorFilter(),
                                    child: Transform(
                                      alignment: Alignment.center,
                                      transform: Matrix4.identity()
                                        ..rotateZ(_rotationAngle * (pi / 180))
                                        ..scaleByDouble(
                                          _flipHorizontal ? -1.0 : 1.0,
                                          _flipVertical ? -1.0 : 1.0,
                                          1.0,
                                          1.0,
                                        ),
                                      child:
                                          (_selectedFilterId != 'none' &&
                                              _currentTextureSource != null)
                                          ? ImageShaderPreview(
                                              texture: _currentTextureSource!,
                                              configuration:
                                                  _selectedFilterItem.config,
                                              fix: BoxFit.contain,
                                            )
                                          : imageWidget,
                                    ),
                                  ),
                                ),
                                _buildOverlayLayer(constraints, _currentPath),
                                _buildDrawingOverlay(constraints, _currentPath),
                                if (_isCropActive)
                                  _buildCropOverlay(constraints),
                                if (_isRotateActive)
                                  Center(child: _buildCircularAngleKnob()),
                                if (_isOverlayRotateActive &&
                                    _selectedOverlayIndex != null &&
                                    _selectedOverlayIndex! <
                                        _overlayItems.length)
                                  Center(
                                    child: _buildOverlayRotationKnob(
                                      _overlayItems[_selectedOverlayIndex!],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (_zoomScale > 1.05)
                            Positioned(
                              top: 10,
                              right: 12,
                              child: GestureDetector(
                                onTap: _resetZoom,
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 10.w,
                                    vertical: 5.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black87,
                                    borderRadius: allradius(16.r),
                                    border: Border.all(
                                      color: yellow,
                                      width: 1.2,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black45,
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.zoom_out_map_rounded,
                                        color: yellow,
                                        size: 14.sp,
                                      ),
                                      SizedBox(width: 4.w),
                                      Text(
                                        "Reset ${_zoomScale.toStringAsFixed(1)}x",
                                        style: GoogleFonts.outfit(
                                          color: Colors.white,
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              // Bottom Control Panel
              if (_activeTab != -1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: _buildActiveTabContent(),
                ),
              // Tab Bar (Bottom)
              if (_activeTab == -1)
                Padding(
                  padding: EdgeInsets.only(bottom: 16.h),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: w,
                        padding: EdgeInsets.symmetric(horizontal: 5.h),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildTabButton(
                              3,
                              Icons.crop_rotate_rounded,
                              "Crop",
                            ),
                            _buildTabButton(1, Icons.tune_rounded, "Adjust"),
                            _buildTabButton(
                              0,
                              CommunityMaterialIcons.image_filter_black_white,
                              "Filter",
                            ),
                            _buildTabButton(4, Icons.draw_rounded, "Markup"),
                            _buildTabButton(2, Icons.image_outlined, "Overlay"),
                          ],
                        ),
                      ),
                      Gap(40.h),
                      SizedBox(
                        width: w,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            InkWell(
                              onTap: () => cancelEditing(context),
                              borderRadius: allradius(8.r),
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 16.w,
                                  vertical: 8.h,
                                ),
                                child: Text(
                                  "Cancel",
                                  style: GoogleFonts.lato(
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.w600,
                                    color: yellow,
                                  ),
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                _buildUndoButton(),
                                Gap(20),
                                _buildRedoButton(),
                              ],
                            ),
                            InkWell(
                              onTap: _onDone,
                              borderRadius: allradius(8.r),
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 16.w,
                                  vertical: 8.h,
                                ),
                                child: Text(
                                  "Save",
                                  style: GoogleFonts.lato(
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.w600,
                                    color: yellow,
                                  ),
                                ),
                              ),
                            ),
                          ],
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
  }

  void cancelEditing(BuildContext context) {
    if (_hasPendingEdits) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text(
            "Discard Edits?",
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            "You have unsaved edits on the current image. Discard and exit?",
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text(
                "Exit",
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        ),
      );
    } else {
      Navigator.pop(context);
    }
  }

  Widget _buildUndoButton({Key? key}) {
    final canUndo = _canUndo;

    return InkWell(
      key: key,
      onTap: canUndo ? _undo : null,
      borderRadius: allradius(10.r),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
        child: Icon(
          Icons.undo_rounded,
          color: canUndo ? Colors.white : Colors.white24,
          size: 20.sp,
        ),
      ),
    );
  }

  Widget _buildRedoButton() {
    final canRedo = _canRedo;

    return InkWell(
      onTap: canRedo ? _redo : null,
      borderRadius: allradius(10.r),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
        child: Icon(
          Icons.redo_rounded,
          color: canRedo ? Colors.white : Colors.white24,
          size: 20.sp,
        ),
      ),
    );
  }

  Widget _buildTabButton(int index, IconData icon, String label, {Key? key}) {
    final isSelected = _activeTab == index;

    return GestureDetector(
      key: key,
      onTap: () {
        setState(() {
          if (_activeTab == index) {
            _activeTab = -1;
          } else {
            _activeTab = index;
          }
        });
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 48.w,
            height: 48.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? yellow : const Color(0xFF222227),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: yellow.withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Icon(
                icon,
                color: isSelected ? Colors.black : Colors.white70,
                size: 22.sp,
              ),
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            label,
            style: GoogleFonts.outfit(
              color: isSelected ? yellow : Colors.white60,
              fontSize: 11.5.sp,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveTabContent() {
    switch (_activeTab) {
      case 0:
        return _buildFiltersTab();
      case 1:
        return _buildAdjustmentsTab();
      case 2:
        return _buildOverlayTab();
      case 3:
        return _buildCropRotateTab();
      case 4:
        return _buildDrawingTab();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildTabActionsRow({
    required String title,
    required VoidCallback onClear,
    required bool hasEdits,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          InkWell(
            onTap: () {
              onClear();
              setState(() {
                _activeTab = -1;
              });
            },
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              child: Text(
                "Cancel",
                style: GoogleFonts.lato(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                  color: yellow,
                ),
              ),
            ),
          ),
          Text(
            title,
            style: GoogleFonts.lato(
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          InkWell(
            onTap: () {
              if (!hasEdits) return;
              if (_isProcessing) {
                return;
              } else {
                _applyAndSaveCurrentEdits();
                setState(() {
                  _activeTab = -1;
                });
              }
            },
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              child: Text(
                "Apply",
                style: GoogleFonts.lato(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                  color: hasEdits ? yellow : grey,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 1: FILTERS ---
  Widget _buildFiltersTab() {
    final hasEdits = _selectedFilterId != 'none';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 90.h,
          child: PageView.builder(
            controller: _filterPageController,
            physics: const BouncingScrollPhysics(),
            itemCount: _filters.length,
            onPageChanged: (index) {
              setState(() {
                _selectedFilterId = _filters[index].id;
              });
            },
            itemBuilder: (context, index) {
              final item = _filters[index];
              final isSel = _selectedFilterId == item.id;

              return GestureDetector(
                onTap: () {
                  _filterPageController.animateToPage(
                    index,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                  );
                },
                child: Center(
                  child: AnimatedScale(
                    scale: isSel ? 1.05 : 0.88,
                    duration: const Duration(milliseconds: 150),
                    child: AnimatedOpacity(
                      opacity: isSel ? 1.0 : 0.45,
                      duration: const Duration(milliseconds: 150),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: EdgeInsets.only(top: 4.r),
                            child: Container(
                              width: 50.r,
                              height: 55.r,
                              decoration: BoxDecoration(
                                color: yellow.withValues(alpha: 0.15),
                                borderRadius: allradius(6),
                                border: isSel
                                    ? Border.all(color: yellow, width: 1.5)
                                    : null,
                              ),
                              child: ClipRRect(
                                borderRadius: allradius(6.r),
                                child: _thumbnailTextureSource != null
                                    ? ImageShaderPreview(
                                        texture: _thumbnailTextureSource!,
                                        configuration: item.config,
                                        fix: BoxFit.cover,
                                      )
                                    : File(_currentPath).existsSync()
                                    ? Image.file(
                                        File(_currentPath),
                                        fit: BoxFit.cover,
                                        cacheWidth: 150,
                                      )
                                    : Icon(
                                        Icons.photo_filter_rounded,
                                        color: isSel ? yellow : Colors.white70,
                                        size: 22.r,
                                      ),
                              ),
                            ),
                          ),
                          Gap(10.h),
                          Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.lato(
                              color: isSel ? Colors.white : Colors.white70,
                              fontSize: 10.sp,
                              fontWeight: isSel
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 4),
          child: _buildTabActionsRow(
            title: "Filters",
            hasEdits: hasEdits,
            onClear: () {
              setState(() {
                _selectedFilterId = 'none';
              });
              if (_filterPageController.hasClients) {
                _filterPageController.animateToPage(
                  0,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                );
              }
            },
          ),
        ),
      ],
    );
  }

  // --- TAB 2: ADJUSTMENTS ---
  Widget _buildAdjustmentsTab() {
    final hasEdits =
        _brightness != 0.0 || _contrast != 0.0 || _saturation != 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Column(
            children: [
              _buildSliderRow(
                "Brightness",
                Icons.wb_sunny_rounded,
                _brightness,
                (val) => setState(() => _brightness = val),
              ),
              _buildSliderRow(
                "Contrast",
                Icons.contrast_rounded,
                _contrast,
                (val) => setState(() => _contrast = val),
              ),
              _buildSliderRow(
                "Saturation",
                Icons.color_lens_rounded,
                _saturation,
                (val) => setState(() => _saturation = val),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 10),
          child: _buildTabActionsRow(
            title: "Adjustments",
            hasEdits: hasEdits,
            onClear: () {
              setState(() {
                _brightness = 0.0;
                _contrast = 0.0;
                _saturation = 0.0;
              });
            },
          ),
        ),
      ],
    );
  }

  // --- TAB 2: INSERT & OVERLAY ---
  Widget _buildOverlayTab() {
    final hasOverlays = _overlayItems.isNotEmpty;
    final isItemSelected =
        _selectedOverlayIndex != null &&
        _selectedOverlayIndex! >= 0 &&
        _selectedOverlayIndex! < _overlayItems.length;
    final selectedItem = isItemSelected
        ? _overlayItems[_selectedOverlayIndex!]
        : null;

    final shapeIcons = <ShapeType, IconData>{
      ShapeType.rectangle: Icons.crop_square_rounded,
      ShapeType.roundedRectangle: Icons.rectangle_rounded,
      ShapeType.circle: Icons.circle_outlined,
      ShapeType.oval: Icons.radio_button_unchecked_rounded,
      ShapeType.star: Icons.star_outline_rounded,
      ShapeType.heart: Icons.favorite_border_rounded,
      ShapeType.triangle: Icons.change_history_rounded,
      ShapeType.arrow: Icons.arrow_right_alt_rounded,
      ShapeType.line: Icons.horizontal_rule_rounded,
      ShapeType.checkmark: Icons.check_rounded,
      ShapeType.cross: Icons.close_rounded,
    };

    final paletteColors = [
      Colors.white,
      Colors.black,
      yellow,
      Colors.redAccent,
      Colors.orangeAccent,
      Colors.amber,
      Colors.greenAccent,
      Colors.tealAccent,
      Colors.cyanAccent,
      Colors.purpleAccent,
      Colors.pinkAccent,
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tab Actions Header
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 14.w),
          child: _buildTabActionsRow(
            title: "Insert & Overlay",
            hasEdits: hasOverlays,
            onClear: () {
              setState(() {
                _overlayItems.clear();
                _selectedOverlayIndex = null;
                _isOverlayRotateActive = false;
              });
            },
          ),
        ),
        Gap(10),
        Row(
          children: [
            Gap(10),
            _buildInsertButton(
              icon: Icons.add_photo_alternate_rounded,
              label: "Image",
              onTap: _pickAndInsertOverlayImage,
            ),
            Gap(8.w),
            _buildInsertButton(
              icon: Icons.text_fields_rounded,
              label: "Text",
              onTap: () => _showAddOrEditTextDialog(),
            ),
            Gap(12.w),
          ],
        ),
        Gap(10),
        // Insert Actions Bar
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 4.h),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Text(
                  'Shapes',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Gap(12.w),
                Container(width: 1, height: 24.h, color: Colors.white24),
                Gap(12.w),
                // Shape selector items
                ...shapeIcons.entries.map((entry) {
                  return Padding(
                    padding: EdgeInsets.only(right: 6.w),
                    child: InkWell(
                      onTap: () {
                        final newItem = EditorOverlayItem(
                          type: ElementType.shape,
                          shapeType: entry.key,
                          position: const Offset(0.5, 0.5),
                          width: 0.28,
                          height: 0.28,
                          strokeColor: yellow,
                          fillColor: Colors.transparent,
                          isFilled: false,
                        );
                        setState(() {
                          _overlayItems.add(newItem);
                          _selectedOverlayIndex = _overlayItems.length - 1;
                        });
                      },
                      borderRadius: allradius(8.r),
                      child: Container(
                        padding: EdgeInsets.all(7.r),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: allradius(8.r),
                        ),
                        child: Icon(
                          entry.value,
                          color: Colors.white,
                          size: 18.sp,
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),

        if (selectedItem != null) ...[
          const Divider(color: Colors.white12, height: 16),

          // Precision Movement D-Pad, Size, Rotation & Delete Controls
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Precision Movement Arrows (D-Pad)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: allradius(10.r),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: "Move Left",
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          setState(() {
                            selectedItem.position = Offset(
                              (selectedItem.position.dx - 0.015).clamp(
                                0.0,
                                1.0,
                              ),
                              selectedItem.position.dy,
                            );
                          });
                        },
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: "Move Up",
                            icon: const Icon(
                              Icons.arrow_upward_rounded,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              setState(() {
                                selectedItem.position = Offset(
                                  selectedItem.position.dx,
                                  (selectedItem.position.dy - 0.015).clamp(
                                    0.0,
                                    1.0,
                                  ),
                                );
                              });
                            },
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: "Move Down",
                            icon: const Icon(
                              Icons.arrow_downward_rounded,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              setState(() {
                                selectedItem.position = Offset(
                                  selectedItem.position.dx,
                                  (selectedItem.position.dy + 0.015).clamp(
                                    0.0,
                                    1.0,
                                  ),
                                );
                              });
                            },
                          ),
                        ],
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: "Move Right",
                        icon: const Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          setState(() {
                            selectedItem.position = Offset(
                              (selectedItem.position.dx + 0.015).clamp(
                                0.0,
                                1.0,
                              ),
                              selectedItem.position.dy,
                            );
                          });
                        },
                      ),
                    ],
                  ),
                ),

                // Size Adjustments (+ / -)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: "Increase Size",
                          icon: const Icon(
                            Icons.zoom_in_rounded,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            setState(() {
                              selectedItem.width = (selectedItem.width * 1.08)
                                  .clamp(0.05, 1.5);
                              selectedItem.height = (selectedItem.height * 1.08)
                                  .clamp(0.05, 1.5);
                              if (selectedItem.type == ElementType.text) {
                                selectedItem.fontSize =
                                    (selectedItem.fontSize + 2).clamp(10, 80);
                              }
                            });
                          },
                        ),
                        IconButton(
                          tooltip: "Decrease Size",
                          icon: const Icon(
                            Icons.zoom_out_rounded,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            setState(() {
                              selectedItem.width = (selectedItem.width / 1.08)
                                  .clamp(0.05, 1.5);
                              selectedItem.height = (selectedItem.height / 1.08)
                                  .clamp(0.05, 1.5);
                              if (selectedItem.type == ElementType.text) {
                                selectedItem.fontSize =
                                    (selectedItem.fontSize - 2).clamp(10, 80);
                              }
                            });
                          },
                        ),
                      ],
                    ),
                    Text(
                      "Scale Size",
                      style: GoogleFonts.instrumentSans(
                        fontSize: 10.sp,
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),

                // Rotate Dial Toggle + Duplicate + Delete
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: _isOverlayRotateActive
                          ? "Hide Rotate Dial"
                          : "Rotate Angle",
                      icon: Icon(
                        Icons.rotate_right_rounded,
                        color: _isOverlayRotateActive ? yellow : Colors.white70,
                      ),
                      onPressed: () {
                        setState(() {
                          _isOverlayRotateActive = !_isOverlayRotateActive;
                        });
                      },
                    ),
                    IconButton(
                      tooltip: "Duplicate",
                      icon: const Icon(
                        Icons.copy_rounded,
                        color: Colors.white70,
                      ),
                      onPressed: () {
                        setState(() {
                          _overlayItems.add(
                            selectedItem.clone(
                              offset: const Offset(0.03, 0.03),
                            ),
                          );
                          _selectedOverlayIndex = _overlayItems.length - 1;
                        });
                      },
                    ),
                    IconButton(
                      tooltip: "Delete Overlay",
                      icon: Icon(Icons.delete_outline_rounded, color: red),
                      onPressed: () {
                        setState(() {
                          _overlayItems.removeAt(_selectedOverlayIndex!);
                          _selectedOverlayIndex = null;
                          _isOverlayRotateActive = false;
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Customization Properties Row (Colors / Text Edit / Fill Toggle)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (selectedItem.type == ElementType.shape) ...[
                    InkWell(
                      onTap: () {
                        setState(() {
                          selectedItem.isFilled = !selectedItem.isFilled;
                          if (selectedItem.isFilled &&
                              selectedItem.fillColor == Colors.transparent) {
                            selectedItem.fillColor = selectedItem.strokeColor
                                .withValues(alpha: 0.5);
                          }
                        });
                      },
                      borderRadius: allradius(8.r),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 6.h,
                        ),
                        decoration: BoxDecoration(
                          color: selectedItem.isFilled
                              ? yellow.withValues(alpha: 0.2)
                              : Colors.white.withValues(alpha: 0.08),
                          borderRadius: allradius(8.r),
                          border: Border.all(
                            color: selectedItem.isFilled
                                ? yellow
                                : Colors.white24,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              selectedItem.isFilled
                                  ? Icons.format_color_fill_rounded
                                  : Icons.format_paint_rounded,
                              color: selectedItem.isFilled
                                  ? yellow
                                  : Colors.white,
                              size: 16.sp,
                            ),
                            Gap(4.w),
                            Text(
                              selectedItem.isFilled ? "Filled" : "Outline",
                              style: TextStyle(
                                color: selectedItem.isFilled
                                    ? yellow
                                    : Colors.white,
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Gap(8.w),
                  ],
                  if (selectedItem.type == ElementType.text) ...[
                    InkWell(
                      onTap: () =>
                          _showAddOrEditTextDialog(existingItem: selectedItem),
                      borderRadius: allradius(8.r),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 6.h,
                        ),
                        decoration: BoxDecoration(
                          color: yellow.withValues(alpha: 0.15),
                          borderRadius: allradius(8.r),
                          border: Border.all(color: yellow),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.edit_rounded,
                              color: yellow,
                              size: 14.sp,
                            ),
                            Gap(4.w),
                            Text(
                              "Edit Text",
                              style: TextStyle(
                                color: yellow,
                                fontSize: 11.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Gap(8.w),
                  ],
                  // Palette Color Chips
                  ...paletteColors.map((col) {
                    final isColSel = selectedItem.type == ElementType.text
                        ? selectedItem.textColor == col
                        : (selectedItem.isFilled
                              ? selectedItem.fillColor == col
                              : selectedItem.strokeColor == col);
                    return Padding(
                      padding: EdgeInsets.only(right: 6.w),
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            if (selectedItem.type == ElementType.text) {
                              selectedItem.textColor = col;
                            } else if (selectedItem.type == ElementType.shape) {
                              if (selectedItem.isFilled) {
                                selectedItem.fillColor = col;
                              }
                              selectedItem.strokeColor = col;
                            }
                          });
                        },
                        child: Container(
                          width: 22.r,
                          height: 22.r,
                          decoration: BoxDecoration(
                            color: col,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isColSel
                                  ? Colors.cyanAccent
                                  : Colors.white38,
                              width: isColSel ? 2.5 : 1.0,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
        const Gap(4),
      ],
    );
  }

  // --- TAB 3: CROP & ROTATE ---
  Widget _buildCropRotateTab() {
    final aspectRatios = ['Free', '1:1', '4:3', '16:9', 'A4'];
    final hasEdits =
        _rotationAngle != 0.0 ||
        _flipHorizontal ||
        _flipVertical ||
        (_isCropActive &&
            (_cropLeft > 0.01 ||
                _cropTop > 0.01 ||
                _cropRight < 0.99 ||
                _cropBottom < 0.99));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Aspect Ratio Chips (Top)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: aspectRatios.map((ratio) {
              final isSel = _isCropActive && _selectedAspectRatio == ratio;
              return Padding(
                padding: EdgeInsets.only(right: 8.w),
                child: InkWell(
                  onTap: () {
                    if (isSel) {
                      _resetCrop();
                    } else {
                      setState(() => _isCropActive = true);
                      _applyAspectRatio(ratio);
                    }
                  },
                  borderRadius: allradius(8.r),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 14.w,
                      vertical: 6.h,
                    ),
                    decoration: BoxDecoration(
                      color: isSel
                          ? yellow.withValues(alpha: 0.15)
                          : Colors.transparent,
                      borderRadius: allradius(4.r),
                      border: Border.all(
                        color: isSel ? yellow : Colors.white24,
                        width: isSel ? 1.5 : 1.0,
                      ),
                    ),
                    child: Text(
                      ratio,
                      style: GoogleFonts.lato(
                        color: isSel ? yellow : Colors.white70,
                        fontSize: 11.sp,
                        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const Gap(12),

        // Controls Row: Flips + Infinite Circular Angle Knob + Reset Crop
        Padding(
          padding: EdgeInsets.symmetric(vertical: 4.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                tooltip: "Flip Horizontal",
                icon: Icon(
                  Icons.flip_rounded,
                  color: _flipHorizontal ? yellow : Colors.white,
                ),
                onPressed: () {
                  setState(() {
                    _flipHorizontal = !_flipHorizontal;
                  });
                },
              ),
              IconButton(
                tooltip: "Flip Vertical",
                icon: Icon(
                  Icons.swap_vert_rounded,
                  color: _flipVertical ? yellow : Colors.white,
                ),
                onPressed: () {
                  setState(() {
                    _flipVertical = !_flipVertical;
                  });
                },
              ),
              IconButton(
                tooltip: _isRotateActive ? "Hide Rotate Dial" : "Rotate Angle",
                icon: Icon(
                  Icons.rotate_right_rounded,
                  color: _isRotateActive ? yellow : Colors.white70,
                ),
                onPressed: () {
                  setState(() {
                    _isRotateActive = !_isRotateActive;
                  });
                },
              ),
            ],
          ),
        ),
        const Gap(4),
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 10),
          child: _buildTabActionsRow(
            title: "Crop & Rotate",
            hasEdits: hasEdits,
            onClear: () {
              setState(() {
                _rotationAngle = 0.0;
                _flipHorizontal = false;
                _flipVertical = false;
                _resetCrop();
              });
            },
          ),
        ),
      ],
    );
  }

  // --- TAB 4: DRAW & ANNOTATE ---
  Widget _buildDrawingTab() {
    final hasEdits =
        _drawingPaths.isNotEmpty || _currentDrawingPoints.isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          child: Column(
            children: [
              // Row 1: Drawing tools & Color Picker trigger
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildDrawingToolIcon(
                    tool: DrawingTool.pen,
                    icon: Icons.edit_rounded,
                    label: "Pen",
                  ),
                  _buildDrawingToolIcon(
                    tool: DrawingTool.highlighter,
                    icon: Icons.brush_rounded,
                    label: "Highlighter",
                  ),
                  _buildDrawingToolIcon(
                    tool: DrawingTool.select,
                    icon: Icons.open_with_rounded,
                    label: "Move",
                  ),
                  _buildDrawingToolIcon(
                    tool: DrawingTool.zoom,
                    icon: Icons.zoom_in_rounded,
                    label: "Zoom",
                  ),
                  _buildDrawingToolIcon(
                    tool: DrawingTool.eraser,
                    icon: Icons.cleaning_services_rounded,
                    label: "Eraser",
                  ),
                  _buildDrawingToolIcon(
                    tool: DrawingTool.eyedropper,
                    icon: Icons.colorize_rounded,
                    label: "Eyedrop",
                  ),
                  // Color Wheel Dialog Trigger Button
                  GestureDetector(
                    onTap: () async {
                      final picked = await ColorWheelDialog.show(
                        context,
                        initialColor: _drawingColor,
                      );
                      if (picked != null) {
                        setState(() {
                          _drawingColor = picked;
                        });
                      }
                    },
                    child: Container(
                      padding: EdgeInsets.all(4.r),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24, width: 1.2),
                      ),
                      child: Container(
                        width: 22.r,
                        height: 22.r,
                        decoration: BoxDecoration(
                          color: _drawingColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _drawingColor.withValues(alpha: 0.5),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // If a shape/stroke is selected, show an action bar with Delete button
              if (_selectedDrawingPathIndex != null &&
                  _selectedDrawingPathIndex! < _drawingPaths.length)
                Container(
                  margin: EdgeInsets.only(top: 8.h),
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 6.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.15),
                    borderRadius: allradius(8.r),
                    border: Border.all(
                      color: Colors.redAccent.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.touch_app_rounded,
                            color: Colors.white70,
                            size: 16.sp,
                          ),
                          SizedBox(width: 6.w),
                          Text(
                            "Shape selected",
                            style: GoogleFonts.outfit(
                              color: Colors.white70,
                              fontSize: 12.sp,
                            ),
                          ),
                        ],
                      ),
                      InkWell(
                        onTap: _deleteSelectedDrawingPath,
                        borderRadius: allradius(6.r),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 2.h,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.redAccent,
                                size: 16.sp,
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                "Delete",
                                style: GoogleFonts.outfit(
                                  color: Colors.redAccent,
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // If Zoom is active, show helper hint or reset button
              if (_drawingTool == DrawingTool.zoom)
                Container(
                  margin: EdgeInsets.only(top: 8.h),
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 6.h,
                  ),
                  decoration: BoxDecoration(
                    color: yellow.withValues(alpha: 0.15),
                    borderRadius: allradius(8.r),
                    border: Border.all(color: yellow.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          "Pinch to zoom & drag to pan. Switch to Pen to draw/sign.",
                          style: GoogleFonts.instrumentSans(
                            color: Colors.white70,
                            fontSize: 11.5.sp,
                          ),
                        ),
                      ),
                      if (_zoomScale > 1.05)
                        GestureDetector(
                          onTap: _resetZoom,
                          child: Padding(
                            padding: EdgeInsets.only(left: 6.w),
                            child: Text(
                              "Reset 1x",
                              style: GoogleFonts.outfit(
                                color: yellow,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

              const Gap(10),

              // Row 2: Stroke Size Slider with Live Dot Preview
              Row(
                children: [
                  Icon(
                    Icons.line_weight_rounded,
                    size: 16.r,
                    color: Colors.white70,
                  ),
                  const Gap(8),
                  Expanded(
                    child: SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 3.5,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 6,
                        ),
                        activeTrackColor: yellow,
                        inactiveTrackColor: Colors.white24,
                        thumbColor: _drawingColor,
                      ),
                      child: Slider(
                        value: _drawingStrokeWidth,
                        min: 1.5,
                        max: 28.0,
                        onChanged: (val) =>
                            setState(() => _drawingStrokeWidth = val),
                      ),
                    ),
                  ),
                  const Gap(6),
                  Container(
                    width: 28.r,
                    height: 28.r,
                    alignment: Alignment.center,
                    child: Container(
                      width: _drawingStrokeWidth.clamp(3.0, 20.0),
                      height: _drawingStrokeWidth.clamp(3.0, 20.0),
                      decoration: BoxDecoration(
                        color: _drawingColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 4),
          child: _buildTabActionsRow(
            title: "Draw & Annotate",
            hasEdits: hasEdits,
            onClear: () {
              _saveDrawingStateForUndo();
              setState(() {
                _drawingPaths.clear();
                _currentDrawingPoints.clear();
                _selectedDrawingPathIndex = null;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInsertButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: allradius(8.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
        decoration: BoxDecoration(
          color: yellow.withValues(alpha: 0.15),
          borderRadius: allradius(8.r),
          border: Border.all(color: yellow.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: yellow, size: 16.sp),
            Gap(6.w),
            Text(
              label,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverlayLayer(BoxConstraints constraints, String path) {
    if (_overlayItems.isEmpty && _activeTab != 2) {
      return const SizedBox.shrink();
    }

    final imageRect = _calculateFittedImageRect(constraints.biggest, path);

    return Positioned(
      left: imageRect.left,
      top: imageRect.top,
      width: imageRect.width,
      height: imageRect.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (int i = 0; i < _overlayItems.length; i++)
            _buildSingleOverlayWidget(i, _overlayItems[i], imageRect.size),
        ],
      ),
    );
  }

  Widget _buildSingleOverlayWidget(
    int index,
    EditorOverlayItem item,
    Size imageSize,
  ) {
    final isSelected = _selectedOverlayIndex == index && _activeTab == 2;
    final itemW = (item.width * imageSize.width).clamp(
      20.0,
      imageSize.width * 2,
    );
    final itemH = (item.height * imageSize.height).clamp(
      20.0,
      imageSize.height * 2,
    );
    final itemLeft = (item.position.dx * imageSize.width) - (itemW / 2);
    final itemTop = (item.position.dy * imageSize.height) - (itemH / 2);

    Widget content;
    switch (item.type) {
      case ElementType.image:
        if (item.imagePath != null && File(item.imagePath!).existsSync()) {
          content = Image.file(
            File(item.imagePath!),
            fit: BoxFit.contain,
            width: itemW,
            height: itemH,
          );
        } else {
          content = Icon(
            Icons.broken_image_rounded,
            color: Colors.white54,
            size: 32.sp,
          );
        }
        break;

      case ElementType.shape:
        content = CustomPaint(
          size: Size(itemW, itemH),
          painter: ShapePainter(
            shapeType: item.shapeType,
            fillColor: item.fillColor,
            borderColor: item.strokeColor,
            borderWidth: item.strokeWidth,
            isFilled: item.isFilled,
          ),
        );
        break;

      case ElementType.text:
        content = Container(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
          decoration: item.backgroundColor != null
              ? BoxDecoration(
                  color: item.backgroundColor,
                  borderRadius: allradius(6.r),
                )
              : null,
          child: Text(
            item.text,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: item.textColor,
              fontSize: item.fontSize,
              fontWeight: item.isBold ? FontWeight.bold : FontWeight.normal,
              fontStyle: item.isItalic ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        );
        break;
    }

    return Positioned(
      left: itemLeft,
      top: itemTop,
      width: itemW,
      height: itemH,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (_activeTab == 2) {
            setState(() {
              _selectedOverlayIndex = index;
            });
          }
        },
        onPanUpdate: _activeTab == 2
            ? (details) {
                setState(() {
                  _selectedOverlayIndex = index;
                  final newDx =
                      (item.position.dx + details.delta.dx / imageSize.width)
                          .clamp(0.0, 1.0);
                  final newDy =
                      (item.position.dy + details.delta.dy / imageSize.height)
                          .clamp(0.0, 1.0);
                  item.position = Offset(newDx, newDy);
                });
              }
            : null,
        child: Transform.rotate(
          angle: item.rotation * (pi / 180),
          child: Opacity(
            opacity: item.opacity.clamp(0.0, 1.0),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Center(child: content),
                if (isSelected) ...[
                  // Selection Border
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: yellow, width: 1.5),
                        borderRadius: allradius(4.r),
                      ),
                    ),
                  ),
                  // Resize Handle Top-Left
                  Positioned(
                    top: -6,
                    left: -6,
                    child: _buildResizeHandle(
                      onPan: (delta) {
                        setState(() {
                          final scaleFactor =
                              1.0 - (delta.dx / imageSize.width) * 2;
                          item.width = (item.width * scaleFactor).clamp(
                            0.05,
                            1.2,
                          );
                          item.height = (item.height * scaleFactor).clamp(
                            0.05,
                            1.2,
                          );
                        });
                      },
                    ),
                  ),
                  // Resize Handle Top-Right
                  Positioned(
                    top: -6,
                    right: -6,
                    child: _buildResizeHandle(
                      onPan: (delta) {
                        setState(() {
                          final scaleFactor =
                              1.0 + (delta.dx / imageSize.width) * 2;
                          item.width = (item.width * scaleFactor).clamp(
                            0.05,
                            1.2,
                          );
                          item.height = (item.height * scaleFactor).clamp(
                            0.05,
                            1.2,
                          );
                        });
                      },
                    ),
                  ),
                  // Resize Handle Bottom-Left
                  Positioned(
                    bottom: -6,
                    left: -6,
                    child: _buildResizeHandle(
                      onPan: (delta) {
                        setState(() {
                          final scaleFactor =
                              1.0 - (delta.dx / imageSize.width) * 2;
                          item.width = (item.width * scaleFactor).clamp(
                            0.05,
                            1.2,
                          );
                          item.height = (item.height * scaleFactor).clamp(
                            0.05,
                            1.2,
                          );
                        });
                      },
                    ),
                  ),
                  // Resize Handle Bottom-Right
                  Positioned(
                    bottom: -6,
                    right: -6,
                    child: _buildResizeHandle(
                      onPan: (delta) {
                        setState(() {
                          final scaleFactor =
                              1.0 + (delta.dx / imageSize.width) * 2;
                          item.width = (item.width * scaleFactor).clamp(
                            0.05,
                            1.2,
                          );
                          item.height = (item.height * scaleFactor).clamp(
                            0.05,
                            1.2,
                          );
                        });
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResizeHandle({required Function(Offset delta) onPan}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: (details) => onPan(details.delta),
      child: Container(
        width: 14.r,
        height: 14.r,
        decoration: BoxDecoration(
          color: yellow,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 4)],
        ),
      ),
    );
  }

  Widget _buildOverlayRotationKnob(EditorOverlayItem item) {
    const knobSize = 210.0;

    return GestureDetector(
      onPanStart: (details) =>
          _onOverlayKnobPan(details.localPosition, knobSize, item),
      onPanUpdate: (details) =>
          _onOverlayKnobPan(details.localPosition, knobSize, item),
      onTapDown: (details) =>
          _onOverlayKnobPan(details.localPosition, knobSize, item),
      child: SizedBox(
        width: knobSize,
        height: knobSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: const Size(knobSize, knobSize),
              painter: AngleKnobPainter(
                angleInDegrees: item.rotation,
                activeColor: yellow,
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _showOverlayAngleInputDialog(item),
              onDoubleTap: () {
                setState(() {
                  item.rotation = 0.0;
                });
                plainToast(msg: "Overlay rotation reset to 0°");
              },
              child: Container(
                width: 78.r,
                height: 78.r,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.55),
                  border: Border.all(color: Colors.white24, width: 1.5),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${item.rotation.round()}",
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "°",
                          style: TextStyle(
                            color: yellow,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      "TAP TO EDIT",
                      style: GoogleFonts.lato(
                        color: Colors.white54,
                        fontSize: 7.sp,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onOverlayKnobPan(
    Offset localPosition,
    double size,
    EditorOverlayItem item,
  ) {
    final center = Offset(size / 2, size / 2);
    final dx = localPosition.dx - center.dx;
    final dy = localPosition.dy - center.dy;
    double rad = atan2(dy, dx) + (pi / 2);
    if (rad < 0) rad += 2 * pi;
    double deg = (rad * 180 / pi) % 360.0;
    if (deg < 0) deg += 360.0;
    setState(() {
      item.rotation = deg;
    });
  }

  Future<void> _showOverlayAngleInputDialog(EditorOverlayItem item) async {
    final controller = TextEditingController(text: "${item.rotation.round()}");
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF222228),
        shape: RoundedRectangleBorder(borderRadius: allradius(16.r)),
        title: Text(
          "Enter Overlay Angle (0° - 360°)",
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: GoogleFonts.outfit(color: Colors.white, fontSize: 18.sp),
          decoration: const InputDecoration(
            hintText: "0 - 360",
            suffixText: "°",
            suffixStyle: TextStyle(color: yellow, fontWeight: FontWeight.bold),
            hintStyle: TextStyle(color: Colors.white30),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white24),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: yellow, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              "Cancel",
              style: TextStyle(color: Colors.white60, fontSize: 13.sp),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: yellow,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: allradius(8.r)),
            ),
            onPressed: () {
              final text = controller.text.trim();
              final val = double.tryParse(text);
              if (val != null) {
                final normalized = ((val % 360.0) + 360.0) % 360.0;
                Navigator.pop(ctx, normalized);
              } else {
                Navigator.pop(ctx);
              }
            },
            child: const Text("Apply"),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      setState(() {
        item.rotation = result;
      });
    }
  }

  Future<void> _showAddOrEditTextDialog({
    EditorOverlayItem? existingItem,
  }) async {
    final controller = TextEditingController(text: existingItem?.text ?? "");
    Color selectedColor = existingItem?.textColor ?? Colors.white;
    bool isBold = existingItem?.isBold ?? false;
    bool isItalic = existingItem?.isItalic ?? false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF222228),
          shape: RoundedRectangleBorder(borderRadius: allradius(16.r)),
          title: Text(
            existingItem == null ? "Insert Text" : "Edit Text",
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  maxLines: 3,
                  minLines: 1,
                  style: GoogleFonts.outfit(
                    color: selectedColor,
                    fontSize: 16.sp,
                    fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                    fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
                  ),
                  decoration: InputDecoration(
                    hintText: "Enter your text here...",
                    hintStyle: const TextStyle(color: Colors.white30),
                    filled: true,
                    fillColor: Colors.black26,
                    border: OutlineInputBorder(
                      borderRadius: allradius(10.r),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: allradius(10.r),
                      borderSide: const BorderSide(color: yellow, width: 2),
                    ),
                  ),
                ),
                Gap(12.h),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.format_bold_rounded,
                        color: isBold ? yellow : Colors.white60,
                      ),
                      onPressed: () => setDialogState(() => isBold = !isBold),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.format_italic_rounded,
                        color: isItalic ? yellow : Colors.white60,
                      ),
                      onPressed: () =>
                          setDialogState(() => isItalic = !isItalic),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                "Cancel",
                style: TextStyle(color: Colors.white60, fontSize: 13.sp),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: yellow,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: allradius(8.r)),
              ),
              onPressed: () {
                final txt = controller.text.trim();
                if (txt.isNotEmpty) {
                  if (existingItem != null) {
                    setState(() {
                      existingItem.text = txt;
                      existingItem.textColor = selectedColor;
                      existingItem.isBold = isBold;
                      existingItem.isItalic = isItalic;
                    });
                  } else {
                    final newItem = EditorOverlayItem(
                      type: ElementType.text,
                      text: txt,
                      textColor: selectedColor,
                      fontSize: 22.0,
                      isBold: isBold,
                      isItalic: isItalic,
                      position: const Offset(0.5, 0.5),
                      width: 0.45,
                      height: 0.15,
                    );
                    setState(() {
                      _overlayItems.add(newItem);
                      _selectedOverlayIndex = _overlayItems.length - 1;
                    });
                  }
                }
                Navigator.pop(ctx);
              },
              child: const Text("Save"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndInsertOverlayImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null) {
      final newItem = EditorOverlayItem(
        type: ElementType.image,
        imagePath: result.files.single.path,
        position: const Offset(0.5, 0.5),
        width: 0.35,
        height: 0.35,
      );
      setState(() {
        _overlayItems.add(newItem);
        _selectedOverlayIndex = _overlayItems.length - 1;
      });
      plainToast(msg: "Image overlay added");
    }
  }

  Widget _buildDrawingToolIcon({
    required DrawingTool tool,
    required IconData icon,
    required String label,
  }) {
    final isSel = _drawingTool == tool;
    return GestureDetector(
      onTap: () {
        setState(() {
          _drawingTool = tool;
          if (tool != DrawingTool.select) {
            _selectedDrawingPathIndex = null;
          }
        });
        if (tool == DrawingTool.eyedropper) {
          plainToast(msg: "Touch & drag on image to sample color");
        } else if (tool == DrawingTool.zoom) {
          plainToast(msg: "Pinch to zoom & drag to reposition image");
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: isSel ? yellow.withValues(alpha: 0.25) : Colors.transparent,
          borderRadius: allradius(8.r),
          border: Border.all(
            color: isSel ? yellow : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Icon(icon, size: 18.sp, color: isSel ? yellow : Colors.white70),
      ),
    );
  }

  Widget _buildDrawingOverlay(BoxConstraints constraints, String path) {
    final hasStrokes =
        _drawingPaths.isNotEmpty || _currentDrawingPoints.isNotEmpty;
    final isDrawTabActive = _activeTab == 4;
    final isDrawingInteractive =
        isDrawTabActive && _drawingTool != DrawingTool.zoom;

    if (!hasStrokes && !isDrawTabActive) {
      return const SizedBox.shrink();
    }

    final imageRect = _calculateFittedImageRect(constraints.biggest, path);

    return Positioned(
      left: imageRect.left,
      top: imageRect.top,
      width: imageRect.width,
      height: imageRect.height,
      child: ClipRect(
        child: GestureDetector(
          behavior: isDrawingInteractive
              ? HitTestBehavior.opaque
              : HitTestBehavior.deferToChild,
          onPanStart: isDrawingInteractive
              ? (details) =>
                    _onDrawingPanStart(details.localPosition, imageRect.size)
              : null,
          onPanUpdate: isDrawingInteractive
              ? (details) => _onDrawingPanUpdate(
                  details.localPosition,
                  details.delta,
                  imageRect.size,
                )
              : null,
          onPanEnd: isDrawingInteractive
              ? (details) => _onDrawingPanEnd(imageRect.size)
              : null,
          onTapDown: isDrawingInteractive
              ? (details) =>
                    _onDrawingTapDown(details.localPosition, imageRect.size)
              : null,
          child: CustomPaint(
            size: imageRect.size,
            painter: DrawingPainter(
              paths: _drawingPaths,
              currentPoints: _currentDrawingPoints,
              currentColor: _drawingColor,
              currentStrokeWidth: _drawingStrokeWidth,
              isCurrentHighlighter: _drawingTool == DrawingTool.highlighter,
              scaleX: imageRect.width,
              scaleY: imageRect.height,
              selectedPathIndex: _selectedDrawingPathIndex,
              eyedropperPos: _eyedropperPos,
              eyedropperColor: _eyedropperSampledColor,
            ),
          ),
        ),
      ),
    );
  }

  // --- CROP OVERLAY PAINTER & HANDLES ---
  Widget _buildCropOverlay(BoxConstraints constraints) {
    final width = constraints.maxWidth;
    final height = constraints.maxHeight;

    final l = _cropLeft * width;
    final t = _cropTop * height;
    final r = _cropRight * width;
    final b = _cropBottom * height;

    const touchSize = 40.0;
    const halfTouch = touchSize / 2;

    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: CropOverlayPainter(cropRect: Rect.fromLTRB(l, t, r, b)),
          ),
        ),

        // 1. Draggable Entire Crop Box Body
        Positioned(
          left: l,
          top: t,
          width: (r - l).clamp(1.0, width),
          height: (b - t).clamp(1.0, height),
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onPanUpdate: (details) {
              final cropW = _cropRight - _cropLeft;
              final cropH = _cropBottom - _cropTop;
              final dx = details.delta.dx / width;
              final dy = details.delta.dy / height;

              double newLeft = _cropLeft + dx;
              double newTop = _cropTop + dy;

              if (newLeft < 0.0) newLeft = 0.0;
              if (newLeft + cropW > 1.0) newLeft = 1.0 - cropW;
              if (newTop < 0.0) newTop = 0.0;
              if (newTop + cropH > 1.0) newTop = 1.0 - cropH;

              setState(() {
                _cropLeft = newLeft;
                _cropRight = newLeft + cropW;
                _cropTop = newTop;
                _cropBottom = newTop + cropH;
              });
            },
            child: const SizedBox.expand(),
          ),
        ),

        // 2. Top Left Handle
        Positioned(
          left: l - halfTouch,
          top: t - halfTouch,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanUpdate: (details) {
              setState(() {
                final newLeft = (l + details.delta.dx) / width;
                final newTop = (t + details.delta.dy) / height;

                if (newLeft >= 0.0 && newLeft < _cropRight - 0.05) {
                  _cropLeft = newLeft;
                }
                if (newTop >= 0.0 && newTop < _cropBottom - 0.05) {
                  _cropTop = newTop;
                }
              });
            },
            child: Container(
              width: touchSize,
              height: touchSize,
              alignment: Alignment.center,
              color: Colors.transparent,
              child: _buildHandleCircle(),
            ),
          ),
        ),

        // 3. Top Right Handle
        Positioned(
          left: r - halfTouch,
          top: t - halfTouch,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanUpdate: (details) {
              setState(() {
                final newRight = (r + details.delta.dx) / width;
                final newTop = (t + details.delta.dy) / height;

                if (newRight <= 1.0 && newRight > _cropLeft + 0.05) {
                  _cropRight = newRight;
                }
                if (newTop >= 0.0 && newTop < _cropBottom - 0.05) {
                  _cropTop = newTop;
                }
              });
            },
            child: Container(
              width: touchSize,
              height: touchSize,
              alignment: Alignment.center,
              color: Colors.transparent,
              child: _buildHandleCircle(),
            ),
          ),
        ),

        // 4. Bottom Left Handle
        Positioned(
          left: l - halfTouch,
          top: b - halfTouch,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanUpdate: (details) {
              setState(() {
                final newLeft = (l + details.delta.dx) / width;
                final newBottom = (b + details.delta.dy) / height;

                if (newLeft >= 0.0 && newLeft < _cropRight - 0.05) {
                  _cropLeft = newLeft;
                }
                if (newBottom <= 1.0 && newBottom > _cropTop + 0.05) {
                  _cropBottom = newBottom;
                }
              });
            },
            child: Container(
              width: touchSize,
              height: touchSize,
              alignment: Alignment.center,
              color: Colors.transparent,
              child: _buildHandleCircle(),
            ),
          ),
        ),

        // 5. Bottom Right Handle
        Positioned(
          left: r - halfTouch,
          top: b - halfTouch,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanUpdate: (details) {
              setState(() {
                final newRight = (r + details.delta.dx) / width;
                final newBottom = (b + details.delta.dy) / height;

                if (newRight <= 1.0 && newRight > _cropLeft + 0.05) {
                  _cropRight = newRight;
                }
                if (newBottom <= 1.0 && newBottom > _cropTop + 0.05) {
                  _cropBottom = newBottom;
                }
              });
            },
            child: Container(
              width: touchSize,
              height: touchSize,
              alignment: Alignment.center,
              color: Colors.transparent,
              child: _buildHandleCircle(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCircularAngleKnob() {
    const knobSize = 210.0;

    return GestureDetector(
      onPanStart: (details) => _onKnobPan(details.localPosition, knobSize),
      onPanUpdate: (details) => _onKnobPan(details.localPosition, knobSize),
      onTapDown: (details) => _onKnobPan(details.localPosition, knobSize),
      child: SizedBox(
        width: knobSize,
        height: knobSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: const Size(knobSize, knobSize),
              painter: AngleKnobPainter(
                angleInDegrees: _rotationAngle,
                activeColor: yellow,
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _showAngleInputDialog,
              onDoubleTap: () {
                setState(() {
                  _rotationAngle = 0.0;
                });
                plainToast(msg: "Rotation reset to 0°");
              },
              child: Container(
                width: 78.r,
                height: 78.r,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.45),
                  border: Border.all(color: Colors.white12, width: 1),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${_rotationAngle.round()}",
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "°",
                          style: TextStyle(
                            color: yellow,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      "TAP TO EDIT",
                      style: GoogleFonts.lato(
                        color: Colors.white54,
                        fontSize: 7.sp,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAngleInputDialog() async {
    final controller = TextEditingController(text: "${_rotationAngle.round()}");
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF222228),
        shape: RoundedRectangleBorder(borderRadius: allradius(16.r)),
        title: Text(
          "Enter Angle (0° - 360°)",
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: GoogleFonts.outfit(color: Colors.white, fontSize: 18.sp),
          decoration: const InputDecoration(
            hintText: "0 - 360",
            suffixText: "°",
            suffixStyle: TextStyle(color: yellow, fontWeight: FontWeight.bold),
            hintStyle: TextStyle(color: Colors.white30),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white24),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: yellow, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              "Cancel",
              style: TextStyle(color: Colors.white60, fontSize: 13.sp),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: yellow,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: allradius(8.r)),
            ),
            onPressed: () {
              final text = controller.text.trim();
              final val = double.tryParse(text);
              if (val != null) {
                final normalized = ((val % 360.0) + 360.0) % 360.0;
                Navigator.pop(ctx, normalized);
              } else {
                Navigator.pop(ctx);
              }
            },
            child: const Text("Apply"),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _rotationAngle = result;
      });
    }
  }

  void _onKnobPan(Offset localPosition, double size) {
    final center = Offset(size / 2, size / 2);
    final dx = localPosition.dx - center.dx;
    final dy = localPosition.dy - center.dy;
    double rad = atan2(dy, dx) + (pi / 2);
    if (rad < 0) rad += 2 * pi;
    double deg = (rad * 180 / pi) % 360.0;
    if (deg < 0) deg += 360.0;
    setState(() {
      _rotationAngle = deg;
    });
  }

  Widget _buildSliderRow(
    String label,
    IconData icon,
    double value,
    ValueChanged<double> onChanged,
  ) {
    final isZero = value.round() == 0;
    final isPos = value > 0;
    final dynamicColor = isZero
        ? Colors.white70
        : isPos
        ? yellow
        : Colors.amberAccent;

    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 16.r, color: dynamicColor),
          SizedBox(width: 8.w),
          SizedBox(
            width: 78.w,
            child: Text(
              label,
              style: GoogleFonts.lato(
                color: isZero ? Colors.white70 : Colors.white,
                fontSize: 11.sp,
                fontWeight: isZero ? FontWeight.normal : FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onDoubleTap: () {
                onChanged(0.0);
              },
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 3.5,
                  trackShape: const CenteredSliderTrackShape(
                    positiveColor: yellow,
                    negativeColor: Colors.amberAccent,
                    inactiveColor: Colors.white24,
                  ),
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 5.5,
                    elevation: 1.0,
                    pressedElevation: 3.0,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 12.0,
                  ),
                  thumbColor: dynamicColor,
                  overlayColor: dynamicColor.withValues(alpha: 0.2),
                ),
                child: Slider(
                  value: value,
                  min: -50.0,
                  max: 50.0,
                  onChanged: onChanged,
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              if (!isZero) onChanged(0.0);
            },
            child: SizedBox(
              width: 34.w,
              child: Text(
                isZero
                    ? "0"
                    : isPos
                    ? "+${value.round()}"
                    : "${value.round()}",
                textAlign: TextAlign.end,
                style: GoogleFonts.outfit(
                  color: dynamicColor,
                  fontSize: 11.sp,
                  fontWeight: isZero ? FontWeight.normal : FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHandleCircle() {
    return Container(
      width: 15.0,
      height: 15.0,
      decoration: BoxDecoration(
        color: yellow,
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 4.0,
            offset: Offset(0, 2),
          ),
        ],
      ),
    );
  }
}
