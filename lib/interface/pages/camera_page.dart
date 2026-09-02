/*
 * PDF Hawk - Modern PDF Reader, Writer, Editor & Scanner
 * Copyright (C) 2026 Van Stan / Novaturients
 *
 * This software is licensed under the PolyForm Noncommercial License 1.0.0.
 * You may obtain a copy of the License at https://polyformproject.org/licenses/noncommercial/1.0.0
 */

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:community_material_icon/community_material_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfhawk/interface/pages/images_editor_page.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_image_filters/flutter_image_filters.dart';
import 'package:pdfhawk/data/models/editor_filter_item.dart';
import 'package:pdfhawk/interface/widgets/level_gauge_widget.dart';
import 'package:pdfhawk/interface/widgets/reorderable_grid.dart';
import 'package:pdfhawk/data/res/constants.dart';
import 'package:pdfhawk/data/res/theme.dart';
import 'package:pdfhawk/data/res/utils.dart';
import 'package:pdfhawk/interface/painters/camera_corner_painter.dart';
import 'package:pdfhawk/interface/painters/camera_crop_mask_painter.dart';
import 'package:pdfhawk/interface/painters/shutter_progress_painter.dart';
import 'package:pdfhawk/interface/pages/pdf_reader_page.dart';
import 'package:pdfhawk/logic/helpers/document_converter.dart';
import 'package:pdfhawk/logic/services/storage_service.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  final List<String> _capturedImages = [];
  FlashMode _flashMode = FlashMode.off;
  final int _selectedCameraIndex = 0;
  bool _isTakingPicture = false;
  late final AnimationController _shutterProgressController;
  late final AnimationController _scanAnimationController;
  late final TabController _sheetTabController;

  // Expandable Bottom Sheet State
  bool _isSheetExpanded = false;

  // Level Gauge state
  bool _isGaugeEnabled = true;

  // Filters state
  bool _showFilterRow = false;
  String _selectedFilterId = 'none';
  TextureSource? _thumbnailTextureSource;
  late final PageController _filterPageController = PageController(
    viewportFraction: 0.22,
    initialPage: 0,
  );

  late final List<EditorFilterItem> _filters = [
    EditorFilterItem(
      id: 'none',
      name: 'Original',
      createConfig: () => NoneShaderConfiguration(),
    ),
    EditorFilterItem(
      id: 'magicScan',
      name: 'Magic Scan',
      createConfig: () => ContrastShaderConfiguration()..contrast = 2.0,
    ),
    EditorFilterItem(
      id: 'grayscale',
      name: 'B&W',
      createConfig: () => GrayscaleShaderConfiguration(),
    ),
    EditorFilterItem(
      id: 'docClean',
      name: 'Doc Clean',
      createConfig: () =>
          LuminanceThresholdShaderConfiguration()..threshold = 0.5,
    ),
    EditorFilterItem(
      id: 'sepia',
      name: 'Sepia',
      createConfig: () => MonochromeShaderConfiguration()
        ..color = const Color(0xFF704214)
        ..intensity = 0.85,
    ),
    EditorFilterItem(
      id: 'vivid',
      name: 'Vivid',
      createConfig: () => SaturationShaderConfiguration()..saturation = 1.6,
    ),
    EditorFilterItem(
      id: 'vibrance',
      name: 'Vibrance',
      createConfig: () => VibranceShaderConfiguration()..vibrance = 0.9,
    ),
    EditorFilterItem(
      id: 'warm',
      name: 'Warm',
      createConfig: () => WhiteBalanceShaderConfiguration()
        ..temperature = 6500
        ..tint = 12,
    ),
    EditorFilterItem(
      id: 'cool',
      name: 'Cool',
      createConfig: () => WhiteBalanceShaderConfiguration()
        ..temperature = 4000
        ..tint = -12,
    ),
    EditorFilterItem(
      id: 'vintage',
      name: 'Vintage',
      createConfig: () => VignetteShaderConfiguration()
        ..start = 0.3
        ..end = 0.75,
    ),
    EditorFilterItem(
      id: 'contrast',
      name: 'Contrast',
      createConfig: () => ContrastShaderConfiguration()..contrast = 1.5,
    ),
    EditorFilterItem(
      id: 'brighten',
      name: 'Brighten',
      createConfig: () => BrightnessShaderConfiguration()..brightness = 0.2,
    ),
    EditorFilterItem(
      id: 'exposure',
      name: 'Exposure',
      createConfig: () => ExposureShaderConfiguration()..exposure = 0.4,
    ),
    EditorFilterItem(
      id: 'invert',
      name: 'Invert',
      createConfig: () => ColorInvertShaderConfiguration(),
    ),
  ];

  EditorFilterItem get _selectedFilterItem {
    return _filters.firstWhere(
      (f) => f.id == _selectedFilterId,
      orElse: () => _filters.first,
    );
  }

  int get _selectedFilterIndex {
    final idx = _filters.indexWhere((f) => f.id == _selectedFilterId);
    return idx >= 0 ? idx : 0;
  }

  // Camera Aspect Ratio (Viewfinder viewport & photo format)
  String _cameraAspectRatio = '4:3'; // '4:3', '16:9', '1:1', 'Full'

  // Auto Crop & Crop Ratio State (Framing overlays on top of camera picture)
  bool _isAutoCrop = false;
  String _selectedCropRatio = 'Free';
  Size _lastPreviewSize = const Size(360, 640);

  // PhotoManager Gallery & Album Picker State
  List<AssetPathEntity> _albums = [];
  AssetPathEntity? _currentAlbum;
  List<AssetEntity> _albumAssets = [];
  final Set<AssetEntity> _selectedAssets = {};
  bool _isLoadingGallery = false;
  bool _hasGalleryPermission = true;
  int _currentGalleryPage = 0;
  bool _hasMoreGalleryAssets = true;
  bool _isLoadingMoreAssets = false;
  static const int _galleryPageSize = 80;
  final ScrollController _galleryScrollController = ScrollController();

  // Zoom & Focus states
  double _minAvailableZoom = 1.0;
  double _maxAvailableZoom = 1.0;
  double _currentScale = 1.0;
  double _baseScale = 1.0;
  int _pointers = 0;
  Offset? _tapFocusOffset;
  Timer? _focusResetTimer;
  Timer? _zoomBadgeTimer;
  bool _showZoomBadge = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    levelGaugeController.start();
    stabilizationController.start();
    _shutterProgressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scanAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _sheetTabController = TabController(length: 2, vsync: this);
    _galleryScrollController.addListener(_onGalleryScroll);
    _initializeCamera();
    _initGalleryAlbums();
    _loadThumbnailTexture();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    levelGaugeController.stop();
    stabilizationController.stop();
    _focusResetTimer?.cancel();
    _zoomBadgeTimer?.cancel();
    _controller?.dispose();
    _shutterProgressController.dispose();
    _scanAnimationController.dispose();
    _sheetTabController.dispose();
    _galleryScrollController.removeListener(_onGalleryScroll);
    _galleryScrollController.dispose();
    _filterPageController.dispose();
    for (final f in _filters) {
      f.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _controller;

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      if (_isGaugeEnabled) {
        levelGaugeController.stop();
        stabilizationController.stop();
      }
      if (cameraController != null && cameraController.value.isInitialized) {
        cameraController.dispose();
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_isGaugeEnabled) {
        levelGaugeController.start();
        stabilizationController.start();
      }
      if (cameraController != null) {
        _onNewCameraSelected(cameraController.description);
      }
    }
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        await _onNewCameraSelected(_cameras[_selectedCameraIndex]);
      } else {
        _showSnackBar("No cameras available on this device.");
        if (mounted) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      _showSnackBar("Error listing cameras: $e");
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  Future<void> _onNewCameraSelected(CameraDescription cameraDescription) async {
    if (_controller != null) {
      await _controller!.dispose();
    }

    final CameraController cameraController = CameraController(
      cameraDescription,
      ResolutionPreset.max,
      enableAudio: false,
    );

    _controller = cameraController;

    cameraController.addListener(() {
      if (mounted) setState(() {});
    });

    try {
      await cameraController.initialize();
      await Future.wait([
        cameraController.getMinZoomLevel().then(
          (val) => _minAvailableZoom = val,
        ),
        cameraController.getMaxZoomLevel().then(
          (val) => _maxAvailableZoom = val,
        ),
      ]);
      await cameraController.setFlashMode(_flashMode);

      _currentScale = _minAvailableZoom;
      _baseScale = _minAvailableZoom;

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
        if (_isSheetExpanded) {
          try {
            await cameraController.pausePreview();
          } catch (_) {}
        }
      }
    } on CameraException catch (e) {
      _showSnackBar("Camera error: ${e.description}");
    }
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _baseScale = _currentScale;
  }

  Future<void> _handleScaleUpdate(ScaleUpdateDetails details) async {
    if (_controller == null || _pointers != 2) return;

    final newScale = (_baseScale * details.scale).clamp(
      _minAvailableZoom,
      _maxAvailableZoom,
    );

    if ((newScale - _currentScale).abs() > 0.01) {
      _currentScale = newScale;
      await _controller!.setZoomLevel(_currentScale);

      _zoomBadgeTimer?.cancel();
      setState(() {
        _showZoomBadge = true;
      });
      _zoomBadgeTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _showZoomBadge = false;
          });
        }
      });
    }
  }

  Future<void> _handleTapToFocus(
    TapUpDetails details,
    BoxConstraints constraints,
  ) async {
    if (_showFilterRow) {
      setState(() {
        _showFilterRow = false;
      });
    }
    if (_controller == null || !_controller!.value.isInitialized) return;

    final offset = Offset(
      (details.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0),
      (details.localPosition.dy / constraints.maxHeight).clamp(0.0, 1.0),
    );

    setState(() {
      _tapFocusOffset = details.localPosition;
    });

    _focusResetTimer?.cancel();
    _focusResetTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _tapFocusOffset = null;
        });
      }
    });

    try {
      await _controller!.setFocusPoint(offset);
      await _controller!.setExposurePoint(offset);
    } catch (_) {}
  }

  double? _getCameraAspectRatioValue() {
    switch (_cameraAspectRatio) {
      case '4:3':
        return 3 / 4; // 0.75 in portrait
      case '16:9':
        return 9 / 16; // 0.5625 in portrait
      case '1:1':
        return 1.0;
      case 'Full':
      default:
        return null; // Full screen
    }
  }

  double? _getCropRatioValue(String ratio) {
    switch (ratio) {
      case '1:1':
        return 1.0;
      case '4:3':
      case '3:4':
        return 3 / 4; // width / height in portrait
      case '16:9':
      case '9:16':
        return 9 / 16;
      case 'A4':
        return 1 / 1.414;
      case '3:2':
      case '2:3':
        return 2 / 3;
      case 'Full':
      case 'Free':
      default:
        return null; // Full screen / unconstrained
    }
  }

  Rect _calculateCropFrameRect(Size containerSize) {
    const double padding = 32.0;
    final maxW = (containerSize.width - (padding * 2)).clamp(
      50.0,
      double.infinity,
    );
    final maxH = (containerSize.height - (padding * 2)).clamp(
      50.0,
      double.infinity,
    );

    final ratio = _getCropRatioValue(_selectedCropRatio);
    if (ratio == null) {
      // Free / Full
      return Rect.fromCenter(
        center: Offset(containerSize.width / 2, containerSize.height / 2),
        width: maxW,
        height: maxH,
      );
    }

    double w = maxW;
    double h = w / ratio;
    if (h > maxH) {
      h = maxH;
      w = h * ratio;
    }

    return Rect.fromCenter(
      center: Offset(containerSize.width / 2, containerSize.height / 2),
      width: w,
      height: h,
    );
  }

  Future<void> _processAndSaveCapturedImage(
    String srcPath,
    String destPath,
  ) async {
    try {
      final bytes = await File(srcPath).readAsBytes();
      img.Image? decoded = img.decodeImage(bytes);
      if (decoded == null) {
        await File(srcPath).copy(destPath);
        try {
          File(srcPath).deleteSync();
        } catch (_) {}
        return;
      }

      // 1. Bake orientation so pixel coordinates match portrait orientation
      decoded = img.bakeOrientation(decoded);

      // 2. Apply Camera Aspect Ratio (4:3, 16:9, 1:1, Full)
      img.Image processedImage = decoded;
      final cameraRatioValue = _getCameraAspectRatioValue();
      if (cameraRatioValue != null) {
        final imgW = processedImage.width;
        final imgH = processedImage.height;

        int cropW = imgW;
        int cropH = (cropW / cameraRatioValue).round();
        if (cropH > imgH) {
          cropH = imgH;
          cropW = (cropH * cameraRatioValue).round();
        }

        int cropX = ((imgW - cropW) / 2).round().clamp(0, imgW - cropW);
        int cropY = ((imgH - cropH) / 2).round().clamp(0, imgH - cropH);

        processedImage = img.copyCrop(
          processedImage,
          x: cropX,
          y: cropY,
          width: cropW,
          height: cropH,
        );
      }

      // 3. Apply Crop Ratio ONLY when Auto Crop ("Crop It") is enabled
      if (_isAutoCrop) {
        final frameRect = _calculateCropFrameRect(_lastPreviewSize);
        final normLeft = (frameRect.left / _lastPreviewSize.width).clamp(
          0.0,
          1.0,
        );
        final normTop = (frameRect.top / _lastPreviewSize.height).clamp(
          0.0,
          1.0,
        );
        final normW = (frameRect.width / _lastPreviewSize.width).clamp(
          0.0,
          1.0,
        );
        final normH = (frameRect.height / _lastPreviewSize.height).clamp(
          0.0,
          1.0,
        );

        final curW = processedImage.width;
        final curH = processedImage.height;

        int cropX = (normLeft * curW).round().clamp(0, curW - 1);
        int cropY = (normTop * curH).round().clamp(0, curH - 1);
        int cropW = (normW * curW).round().clamp(1, curW - cropX);
        int cropH = (normH * curH).round().clamp(1, curH - cropY);

        processedImage = img.copyCrop(
          processedImage,
          x: cropX,
          y: cropY,
          width: cropW,
          height: cropH,
        );
      }

      // 4. Encode cleanly to JPEG, stripping bulky EXIF metadata / camera bloat
      final encoded = img.encodeJpg(processedImage, quality: 92);
      await File(destPath).writeAsBytes(encoded);

      try {
        File(srcPath).deleteSync();
      } catch (_) {}
    } catch (e) {
      debugPrint("Error processing captured image: $e");
      await File(srcPath).copy(destPath);
      try {
        File(srcPath).deleteSync();
      } catch (_) {}
    }
  }

  Future<void> _loadThumbnailTexture([String? filePath]) async {
    try {
      TextureSource? tex;
      if (filePath != null && File(filePath).existsSync()) {
        tex = await TextureSource.fromFile(File(filePath));
      } else if (_capturedImages.isNotEmpty &&
          File(_capturedImages.last).existsSync()) {
        tex = await TextureSource.fromFile(File(_capturedImages.last));
      } else {
        tex = await TextureSource.fromAsset('assets/src/logo.png');
      }
      if (mounted) {
        setState(() {
          _thumbnailTextureSource = tex;
        });
      }
    } catch (e) {
      debugPrint("Error loading thumbnail texture: $e");
    }
  }

  Future<void> _applyFilterToImage(String imagePath) async {
    try {
      final filterItem = _selectedFilterItem;
      if (filterItem.id == 'none') return;

      final file = File(imagePath);
      if (!file.existsSync()) return;

      final tex = await TextureSource.fromFile(file);
      final renderedImage = await filterItem.config.export(tex, tex.size);
      final byteData = await renderedImage.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (byteData != null) {
        final pngBytes = byteData.buffer.asUint8List();
        final decoded = img.decodeImage(pngBytes);
        if (decoded != null) {
          final jpgBytes = img.encodeJpg(decoded, quality: 92);
          await file.writeAsBytes(jpgBytes);
        } else {
          await file.writeAsBytes(pngBytes);
        }
      }
    } catch (e) {
      debugPrint("Error applying filter to image: $e");
    }
  }

  Future<void> _takePicture() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isTakingPicture) {
      return;
    }

    setState(() {
      _isTakingPicture = true;
    });

    _scanAnimationController.repeat(reverse: true);
    _shutterProgressController.forward(from: 0.0);

    try {
      final file = await _controller!.takePicture();

      // Persist the captured image to app documents directory
      final appDir = await getApplicationDocumentsDirectory();
      final scanDir = Directory("${appDir.path}/scans");
      if (!scanDir.existsSync()) {
        scanDir.createSync(recursive: true);
      }
      final savedPath =
          "${scanDir.path}/scan_${DateTime.now().millisecondsSinceEpoch}_${_capturedImages.length}.jpg";

      // Process image: applies Camera Aspect Ratio, and Crop Ratio if Auto Crop is enabled
      await _processAndSaveCapturedImage(file.path, savedPath);

      // Apply selected filter right when picture is taken
      if (_selectedFilterId != 'none') {
        await _applyFilterToImage(savedPath);
      }

      if (mounted) {
        setState(() {
          _capturedImages.add(savedPath);
        });
        _loadThumbnailTexture(savedPath);
      }
    } on CameraException catch (e) {
      _showSnackBar("Error taking picture: ${e.description}");
    } catch (e) {
      _showSnackBar("Error saving picture: $e");
    } finally {
      if (mounted) {
        _scanAnimationController.stop();
        _scanAnimationController.reset();
        _shutterProgressController.reset();
        setState(() {
          _isTakingPicture = false;
        });
      }
    }
  }

  Future<void> _cycleFlashMode() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    FlashMode nextMode;
    switch (_flashMode) {
      case FlashMode.off:
        nextMode = FlashMode.always;
        break;
      case FlashMode.always:
        nextMode = FlashMode.auto;
        break;
      case FlashMode.auto:
        nextMode = FlashMode.torch;
        break;
      case FlashMode.torch:
        nextMode = FlashMode.off;
        break;
    }

    try {
      await _controller!.setFlashMode(nextMode);
      setState(() => _flashMode = nextMode);
    } catch (e) {
      _showSnackBar("Failed to set flash mode: $e");
    }
  }

  void _showSnackBar(String text) {
    if (!mounted) return;
    plainToast(msg: text);
  }

  void _setSheetExpanded(bool expand) {
    if (_isSheetExpanded == expand) return;
    setState(() {
      _isSheetExpanded = expand;
      if (expand) {
        _showFilterRow = false;
      }
    });

    final controller = _controller;
    if (controller != null && controller.value.isInitialized) {
      try {
        if (expand) {
          controller.pausePreview();
        } else {
          controller.resumePreview();
        }
      } catch (e) {
        debugPrint("Error toggling camera preview: $e");
      }
    }
  }

  IconData _getFlashIcon() {
    switch (_flashMode) {
      case FlashMode.off:
        return Icons.flash_off_rounded;
      case FlashMode.always:
        return Icons.flash_on_rounded;
      case FlashMode.auto:
        return Icons.flash_auto_rounded;
      case FlashMode.torch:
        return Icons.highlight_rounded;
    }
  }

  // --- ACTIONS FOR CAPTURED IMAGES ---

  void _openEditorForImage(int index) {
    if (_capturedImages.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImagesEditorPage(
          imagePath: _capturedImages[index],
          onSave: (updatedPath) {
            setState(() {
              _capturedImages[index] = updatedPath;
            });
          },
        ),
      ),
    );
  }

  Future<void> _saveImageToGallery(String path) async {
    try {
      final file = File(path);
      if (!file.existsSync()) return;
      final bytes = await file.readAsBytes();
      final fileName = "Scan_${DateTime.now().millisecondsSinceEpoch}.jpg";
      await StorageService.saveExportedFile(
        fileName: fileName,
        bytes: bytes,
        subFolder: "Scans",
      );
      _showSnackBar("Saved to PDFHawk/Scans/$fileName");
    } catch (e) {
      _showSnackBar("Failed to save image: $e");
    }
  }

  void _shareImage(String path) {
    final file = File(path);
    if (file.existsSync()) {
      SharePlus.instance.share(
        ShareParams(files: [XFile(path)], text: "Scanned Document Page"),
      );
    }
  }

  void _deleteCapturedImage(int index) {
    if (index < 0 || index >= _capturedImages.length) return;
    setState(() {
      final path = _capturedImages.removeAt(index);
      final file = File(path);
      if (file.existsSync()) {
        file.deleteSync();
      }
    });
    _showSnackBar("Page ${index + 1} deleted");
  }

  void _clearAllCapturedImages() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          "Clear All Scanned Pages?",
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          "Are you sure you want to discard all scanned images?",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Cancel",
              style: TextStyle(color: Colors.white60),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                for (final path in _capturedImages) {
                  final file = File(path);
                  if (file.existsSync()) {
                    file.deleteSync();
                  }
                }
                _capturedImages.clear();
              });
              Navigator.pop(context);
            },
            child: const Text(
              "Clear All",
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  // --- GALLERY ACTIONS ---

  // --- GALLERY ACTIONS VIA PHOTO MANAGER ---

  void _onGalleryScroll() {
    if (_galleryScrollController.hasClients &&
        _galleryScrollController.position.pixels >=
            _galleryScrollController.position.maxScrollExtent - 250) {
      if (_hasMoreGalleryAssets &&
          !_isLoadingMoreAssets &&
          !_isLoadingGallery) {
        _loadAssetsForCurrentAlbum(page: _currentGalleryPage + 1);
      }
    }
  }

  Future<void> _initGalleryAlbums() async {
    setState(() => _isLoadingGallery = true);
    try {
      final PermissionState ps = await PhotoManager.requestPermissionExtend();
      if (!ps.isAuth && !ps.hasAccess) {
        if (mounted) {
          setState(() {
            _hasGalleryPermission = false;
            _isLoadingGallery = false;
          });
        }
        return;
      }

      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        hasAll: true,
        filterOption: FilterOptionGroup(
          imageOption: const FilterOption(
            needTitle: true,
            sizeConstraint: SizeConstraint(ignoreSize: true),
          ),
          orders: [
            const OrderOption(type: OrderOptionType.createDate, asc: false),
          ],
        ),
      );

      if (mounted) {
        setState(() {
          _hasGalleryPermission = true;
          _albums = albums;
          _currentAlbum = albums.isNotEmpty ? albums.first : null;
        });
      }

      if (_currentAlbum != null) {
        await _loadAssetsForCurrentAlbum(page: 0);
      }
    } catch (e) {
      debugPrint("Error initializing PhotoManager gallery: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoadingGallery = false);
      }
    }
  }

  Future<void> _loadAssetsForCurrentAlbum({int page = 0}) async {
    if (_currentAlbum == null) return;
    if (page == 0) {
      setState(() {
        _isLoadingGallery = true;
        _currentGalleryPage = 0;
        _albumAssets.clear();
        _hasMoreGalleryAssets = true;
      });
    } else {
      if (!_hasMoreGalleryAssets || _isLoadingMoreAssets) return;
      setState(() => _isLoadingMoreAssets = true);
    }

    try {
      final assets = await _currentAlbum!.getAssetListPaged(
        page: page,
        size: _galleryPageSize,
      );

      if (mounted) {
        setState(() {
          if (page == 0) {
            _albumAssets = assets;
          } else {
            _albumAssets.addAll(assets);
          }
          _currentGalleryPage = page;
          _hasMoreGalleryAssets = assets.length == _galleryPageSize;
        });
      }
    } catch (e) {
      debugPrint("Error loading assets for album: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingGallery = false;
          _isLoadingMoreAssets = false;
        });
      }
    }
  }

  void _onAlbumSelected(AssetPathEntity album) {
    if (_currentAlbum?.id == album.id) return;
    setState(() {
      _currentAlbum = album;
      _selectedAssets.clear();
    });
    _loadAssetsForCurrentAlbum(page: 0);
  }

  void _showAlbumSelectionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E24),
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.35,
          maxChildSize: 0.85,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 14.h,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Device Albums",
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white70,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white12, height: 1),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: _albums.length,
                    itemBuilder: (context, index) {
                      final album = _albums[index];
                      final isSelected = _currentAlbum?.id == album.id;

                      return FutureBuilder<int>(
                        future: album.assetCountAsync,
                        builder: (context, snapshot) {
                          final count = snapshot.data ?? 0;
                          return ListTile(
                            leading: FutureBuilder<List<AssetEntity>>(
                              future: album.getAssetListRange(start: 0, end: 1),
                              builder: (context, thumbSnap) {
                                if (thumbSnap.hasData &&
                                    thumbSnap.data!.isNotEmpty) {
                                  return ClipRRect(
                                    borderRadius: allradius(8.r),
                                    child: SizedBox(
                                      width: 48.r,
                                      height: 48.r,
                                      child: AssetEntityImage(
                                        thumbSnap.data!.first,
                                        isOriginal: false,
                                        thumbnailSize:
                                            const ThumbnailSize.square(150),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  );
                                }
                                return Container(
                                  width: 48.r,
                                  height: 48.r,
                                  decoration: BoxDecoration(
                                    color: Colors.white10,
                                    borderRadius: allradius(8.r),
                                  ),
                                  child: const Icon(
                                    Icons.photo_album_rounded,
                                    color: Colors.white38,
                                  ),
                                );
                              },
                            ),
                            title: Text(
                              album.name.isEmpty ? "Recent" : album.name,
                              style: GoogleFonts.outfit(
                                color: isSelected ? royalblue : Colors.white,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                fontSize: 14.sp,
                              ),
                            ),
                            subtitle: Text(
                              "$count photos",
                              style: GoogleFonts.instrumentSans(
                                color: Colors.white54,
                                fontSize: 12.sp,
                              ),
                            ),
                            trailing: isSelected
                                ? const Icon(
                                    Icons.check_circle_rounded,
                                    color: royalblue,
                                  )
                                : null,
                            onTap: () {
                              Navigator.pop(context);
                              _onAlbumSelected(album);
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _pickImagesFromCustomPicker() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );
      if (result != null && result.paths.isNotEmpty) {
        final appDir = await getApplicationDocumentsDirectory();
        final scanDir = Directory("${appDir.path}/scans");
        if (!scanDir.existsSync()) {
          scanDir.createSync(recursive: true);
        }

        int added = 0;
        for (final path in result.paths) {
          if (path != null) {
            final srcFile = File(path);
            if (srcFile.existsSync()) {
              final targetPath =
                  "${scanDir.path}/scan_${DateTime.now().millisecondsSinceEpoch}_${_capturedImages.length + added}.jpg";
              final saved = await srcFile.copy(targetPath);
              if (!_capturedImages.contains(saved.path)) {
                _capturedImages.add(saved.path);
                added++;
              }
            }
          }
        }
        if (mounted) {
          setState(() {
            _sheetTabController.animateTo(0);
          });
          _showSnackBar("Imported $added image(s) to scanned document!");
        }
      }
    } catch (e) {
      _showSnackBar("Failed to pick images: $e");
    }
  }

  Future<void> _addSelectedAssetsToScanList() async {
    if (_selectedAssets.isEmpty) return;

    final selectedList = _selectedAssets.toList();
    _showSnackBar("Adding ${selectedList.length} image(s)...");

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final scanDir = Directory("${appDir.path}/scans");
      if (!scanDir.existsSync()) {
        scanDir.createSync(recursive: true);
      }

      int addedCount = 0;
      for (int i = 0; i < selectedList.length; i++) {
        final asset = selectedList[i];
        final File? file = await asset.file ?? await asset.originFile;
        if (file != null && file.existsSync()) {
          final targetPath =
              "${scanDir.path}/scan_${DateTime.now().millisecondsSinceEpoch}_${_capturedImages.length + i}.jpg";
          final savedFile = await file.copy(targetPath);
          if (!_capturedImages.contains(savedFile.path)) {
            _capturedImages.add(savedFile.path);
            addedCount++;
          }
        }
      }

      if (mounted) {
        setState(() {
          _selectedAssets.clear();
          _sheetTabController.animateTo(0);
        });
        _showSnackBar("Added $addedCount image(s) to scanned document!");
      }
    } catch (e) {
      _showSnackBar("Error adding images: $e");
    }
  }

  // --- EXPORT TO PDF ---

  Future<void> _exportToPdf() async {
    if (_capturedImages.isEmpty) {
      _showSnackBar("No scanned images to export.");
      return;
    }

    final nameController = TextEditingController(
      text: "Scanned_Document_${DateTime.now().millisecondsSinceEpoch}",
    );

    final bool? shouldExport = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        constraints: BoxConstraints(minWidth: getWidth(context)),
        shape: RoundedRectangleBorder(borderRadius: allradius(20.r)),
        title: Text(
          "Export to PDF",
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Enter document filename (${_capturedImages.length} pages):",
              style: GoogleFonts.instrumentSans(
                color: Colors.white70,
                fontSize: 13.sp,
              ),
            ),
            SizedBox(height: 12.h),
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                suffixText: ".pdf",
                suffixStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: Colors.white10,
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
            child: const Text(
              "Cancel",
              style: TextStyle(color: Colors.white60),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: royalblue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: allradius(12.r)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Export"),
          ),
        ],
      ),
    );

    if (shouldExport != true) return;

    // Show Progress Dialog
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: allradius(16.r)),
          content: Row(
            children: [
              const CircularProgressIndicator(color: royalblue),
              SizedBox(width: 20.w),
              Expanded(
                child: Text(
                  "Compiling PDF document...",
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 14.sp,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final imageFiles = _capturedImages.map((p) => File(p)).toList();
      final outputFile = await DocumentConverter.convertImagesToPdf(imageFiles);

      String filename = nameController.text.trim();
      if (!filename.toLowerCase().endsWith(".pdf")) {
        filename = "$filename.pdf";
      }

      final bytes = await outputFile.readAsBytes();
      final savedPdf = await StorageService.saveExportedFile(
        fileName: filename,
        bytes: bytes,
      );

      if (mounted) {
        Navigator.pop(context); // Close progress dialog
        _showSnackBar("PDF saved: ${savedPdf.path.split('/').last}");
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PDFReaderPage(pdfFile: savedPdf),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close progress dialog
        _showSnackBar("Failed to export PDF: $e");
      }
    }
  }

  void _handleBackNavigation() {
    if (_isSheetExpanded) {
      _setSheetExpanded(false);
      return;
    }

    if (_capturedImages.isEmpty) {
      Navigator.pop(context);
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        shape: RoundedRectangleBorder(borderRadius: allradius(16.r)),
        title: Text(
          "Discard Scanned Pages?",
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 17.sp,
          ),
        ),
        content: Text(
          "You have ${_capturedImages.length} scanned page${_capturedImages.length > 1 ? 's' : ''}. If you exit now, these scans will be discarded.",
          style: GoogleFonts.instrumentSans(
            color: Colors.white70,
            fontSize: 13.sp,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Cancel",
              style: GoogleFonts.outfit(color: Colors.white60),
            ),
          ),
          TextButton(
            onPressed: () {
              for (final path in _capturedImages) {
                final file = File(path);
                if (file.existsSync()) {
                  file.deleteSync();
                }
              }
              _capturedImages.clear();
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Pop CameraPage
            },
            child: Text(
              "Discard & Exit",
              style: GoogleFonts.outfit(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double w = getWidth(context);
    final double sheetExpandedHeight =
        MediaQuery.of(context).size.height * 0.82;
    const double sheetCollapsedHeight = 130.0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackNavigation();
      },
      child: Theme(
        data: Theme.of(context).copyWith(
          primaryColor: yellow,
          colorScheme: Theme.of(context).colorScheme.copyWith(primary: yellow),
        ),
        child: Scaffold(
          backgroundColor: black,
          body: _isCameraInitialized && _controller != null
              ? SafeArea(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Camera Viewfinder / Preview
                      Container(
                        width: double.infinity,
                        height: double.infinity,
                        decoration: const BoxDecoration(color: Colors.black),
                        clipBehavior: Clip.antiAlias,
                        child: LayoutBuilder(
                          builder: (context, outerConstraints) {
                            final ratioValue = _getCameraAspectRatioValue();

                            Widget buildViewport(BoxConstraints constraints) {
                              return Listener(
                                onPointerDown: (_) => _pointers++,
                                onPointerUp: (_) =>
                                    _pointers = (_pointers - 1).clamp(0, 10),
                                onPointerCancel: (_) =>
                                    _pointers = (_pointers - 1).clamp(0, 10),
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onScaleStart: _handleScaleStart,
                                  onScaleUpdate: _handleScaleUpdate,
                                  onTapUp: (details) =>
                                      _handleTapToFocus(details, constraints),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    fit: StackFit.expand,
                                    children: [
                                      // Native camera stream fitted into viewport
                                      FittedBox(
                                        fit: BoxFit.cover,
                                        child: SizedBox(
                                          width:
                                              _controller!.value.previewSize !=
                                                  null
                                              ? _controller!
                                                    .value
                                                    .previewSize!
                                                    .height
                                              : constraints.maxWidth,
                                          height:
                                              _controller!.value.previewSize !=
                                                  null
                                              ? _controller!
                                                    .value
                                                    .previewSize!
                                                    .width
                                              : constraints.maxHeight,
                                          child: CameraPreview(_controller!),
                                        ),
                                      ),

                                      // Tap to focus ring animation
                                      if (_tapFocusOffset != null)
                                        Positioned(
                                          left: _tapFocusOffset!.dx - 28,
                                          top: _tapFocusOffset!.dy - 28,
                                          child: TweenAnimationBuilder<double>(
                                            tween: Tween(begin: 1.3, end: 1.0),
                                            duration: const Duration(
                                              milliseconds: 200,
                                            ),
                                            builder: (context, val, child) {
                                              return Transform.scale(
                                                scale: val,
                                                child: Container(
                                                  width: 56,
                                                  height: 56,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: yellow,
                                                      width: 1,
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),

                                      // Live Zoom multiplier pill indicator
                                      if (_showZoomBadge ||
                                          _currentScale > 1.05)
                                        Positioned(
                                          bottom: 16.h,
                                          left: 0,
                                          right: 0,
                                          child: Center(
                                            child: AnimatedOpacity(
                                              opacity: _showZoomBadge
                                                  ? 1.0
                                                  : 0.7,
                                              duration: const Duration(
                                                milliseconds: 200,
                                              ),
                                              child: Container(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 14.w,
                                                  vertical: 5.h,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.65),
                                                  borderRadius: allradius(16.r),
                                                  border: Border.all(
                                                    color: Colors.white24,
                                                    width: 1,
                                                  ),
                                                ),
                                                child: Text(
                                                  "${_currentScale.toStringAsFixed(1)}x",
                                                  style: GoogleFonts.outfit(
                                                    color: Colors.white,
                                                    fontSize: 13.sp,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),

                                      // Camera Corner Framing Guides with Auto Crop Mask
                                      Builder(
                                        builder: (context) {
                                          _lastPreviewSize =
                                              constraints.biggest;
                                          final frameRect =
                                              _calculateCropFrameRect(
                                                constraints.biggest,
                                              );

                                          return Stack(
                                            fit: StackFit.expand,
                                            children: [
                                              if (_isAutoCrop)
                                                Positioned.fill(
                                                  child: IgnorePointer(
                                                    child: CustomPaint(
                                                      size: constraints.biggest,
                                                      painter:
                                                          CameraCropMaskPainter(
                                                            frameRect:
                                                                frameRect,
                                                            maskColor: Colors
                                                                .black
                                                                .withValues(
                                                                  alpha: 0.65,
                                                                ),
                                                          ),
                                                    ),
                                                  ),
                                                ),
                                              Positioned(
                                                left: frameRect.left,
                                                top: frameRect.top,
                                                width: frameRect.width,
                                                height: frameRect.height,
                                                child: IgnorePointer(
                                                  child: const CustomPaint(
                                                    size: Size.infinite,
                                                    painter:
                                                        CameraCornerPainter(
                                                          color: Color.fromARGB(
                                                            140,
                                                            255,
                                                            255,
                                                            255,
                                                          ),
                                                          cornerLength: 32.0,
                                                          cornerRadius: 4.0,
                                                          strokeWidth: 1.0,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      ),

                                      // Level stabilizer
                                      if (_isGaugeEnabled)
                                        UnifiedLevelStabilizer(
                                          level: true,
                                          stablize: true,
                                          primaryColor: royalblue,
                                          angleStream:
                                              levelGaugeController.angleStream,
                                          stabilityStream:
                                              stabilizationController
                                                  .stabilityStream,
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            return Center(
                              child: ratioValue != null
                                  ? AspectRatio(
                                      aspectRatio: ratioValue,
                                      child: ClipRect(
                                        child: LayoutBuilder(
                                          builder:
                                              (context, innerConstraints) =>
                                                  buildViewport(
                                                    innerConstraints,
                                                  ),
                                        ),
                                      ),
                                    )
                                  : ClipRect(
                                      child: LayoutBuilder(
                                        builder: (context, innerConstraints) =>
                                            buildViewport(innerConstraints),
                                      ),
                                    ),
                            );
                          },
                        ),
                      ),

                      // Top Bar
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 4.w,
                            vertical: 2.h,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                onPressed: _handleBackNavigation,
                                icon: const Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  color: white,
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildCameraAspectRatioMenu(),
                                  Gap(6.w),
                                  IconButton(
                                    tooltip: _isGaugeEnabled
                                        ? "Disable Level Gauge"
                                        : "Enable Level Gauge",
                                    icon: Icon(
                                      _isGaugeEnabled
                                          ? CommunityMaterialIcons
                                                .compass_outline
                                          : CommunityMaterialIcons
                                                .compass_off_outline,
                                      color: _isGaugeEnabled
                                          ? yellow
                                          : Colors.white60,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _isGaugeEnabled = !_isGaugeEnabled;
                                        if (_isGaugeEnabled) {
                                          levelGaugeController.start();
                                          stabilizationController.start();
                                        } else {
                                          levelGaugeController.stop();
                                          stabilizationController.stop();
                                        }
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Filter Selection Row floating above the collapsed shutter bar
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        left: 0,
                        right: 0,
                        bottom: (_showFilterRow && !_isSheetExpanded)
                            ? (sheetCollapsedHeight.h + 8.h)
                            : -120.h,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: (_showFilterRow && !_isSheetExpanded)
                              ? 1.0
                              : 0.0,
                          child: IgnorePointer(
                            ignoring: !_showFilterRow || _isSheetExpanded,
                            child: _buildFilterRow(),
                          ),
                        ),
                      ),

                      // Expandable Bottom Sheet drawn over the camera preview
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeInOutCubic,
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: _isSheetExpanded
                            ? sheetExpandedHeight
                            : sheetCollapsedHeight.h,
                        child: Container(
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: _isSheetExpanded
                                ? const Color(0xFF141419)
                                : transparent,
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(_isSheetExpanded ? 10.r : 0),
                            ),
                          ),
                          child: _isSheetExpanded
                              ? OverflowBox(
                                  alignment: Alignment.topCenter,
                                  minHeight: sheetExpandedHeight,
                                  maxHeight: sheetExpandedHeight,
                                  minWidth: w,
                                  maxWidth: w,
                                  child: SizedBox(
                                    height: sheetExpandedHeight,
                                    width: w,
                                    child: _buildExpandedSheetContent(
                                      context,
                                      w,
                                    ),
                                  ),
                                )
                              : _buildCollapsedShutterBar(),
                        ),
                      ),
                    ],
                  ),
                )
              : Center(child: CircularProgressIndicator.adaptive()),
        ),
      ),
    );
  }

  // --- COLLAPSED SHUTTER BAR ---
  Widget _buildCollapsedShutterBar() {
    double w = getWidth(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 10, 20, 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Auto Crop Toggle Button
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isAutoCrop = !_isAutoCrop;
                    });
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 5.h,
                    ),
                    decoration: BoxDecoration(
                      color: _isAutoCrop
                          ? royalblue.withValues(alpha: 0.25)
                          : Colors.white.withValues(alpha: 0.12),
                      borderRadius: allradius(16.r),
                      border: Border.all(
                        color: _isAutoCrop ? royalblue : Colors.white24,
                        width: 1.2,
                      ),
                    ),
                    child: Text(
                      "Crop It",
                      style: GoogleFonts.outfit(
                        color: _isAutoCrop ? royalblue : Colors.white70,
                        fontSize: 11.sp,
                        fontWeight: _isAutoCrop
                            ? FontWeight.bold
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                Gap(15.h),
                // Flash button
                IconButton(
                  icon: Icon(_getFlashIcon(), color: Colors.white),
                  onPressed: _cycleFlashMode,
                ),
              ],
            ),
          ),

          SizedBox(
            width: w / 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Arrow up button above shutter with count badge
                GestureDetector(
                  onTap: () => _setSheetExpanded(true),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 14.w,
                      vertical: 5.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: allradius(16.r),
                      border: Border.all(color: Colors.white24, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.keyboard_arrow_up_rounded,
                          color: Colors.white,
                          size: 18.sp,
                        ),
                        if (_capturedImages.isNotEmpty) ...[
                          SizedBox(width: 4.w),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6.w,
                              vertical: 2.h,
                            ),
                            decoration: BoxDecoration(
                              color: royalblue,
                              borderRadius: allradius(10.r),
                            ),
                            child: Text(
                              "${_capturedImages.length}",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Gap(8.h),
                // Shutter button with radial progress overlay
                GestureDetector(
                  onTap: _takePicture,
                  child: SizedBox(
                    width: 65.r,
                    height: 65.r,
                    child: AnimatedBuilder(
                      animation: _shutterProgressController,
                      builder: (context, child) {
                        return CustomPaint(
                          painter: ShutterProgressPainter(
                            progress: _shutterProgressController.value,
                            strokeWidth: 4.r,
                            baseColor: Colors.white,
                            progressColor: royalblue,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Crop Ratios Dropdown / Popup Menu (Opens upwards)
                PopupMenuButton<String>(
                  tooltip: "Crop Ratio",
                  offset: Offset(0, -220.h),
                  color: const Color(0xFF22222A),
                  shape: RoundedRectangleBorder(
                    borderRadius: allradius(14.r),
                    side: const BorderSide(color: Colors.white24, width: 1),
                  ),
                  onSelected: (ratio) {
                    setState(() {
                      _selectedCropRatio = ratio;
                    });
                  },
                  itemBuilder: (context) =>
                      ['Free', '1:1', '4:3', '16:9', 'A4', '3:2'].map((r) {
                        final isSel = _selectedCropRatio == r;
                        return PopupMenuItem<String>(
                          value: r,
                          height: 38.h,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                r,
                                style: GoogleFonts.outfit(
                                  color: isSel ? royalblue : Colors.white,
                                  fontWeight: isSel
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  fontSize: 13.sp,
                                ),
                              ),
                              if (isSel)
                                const Icon(
                                  Icons.check_rounded,
                                  color: royalblue,
                                  size: 16,
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 5.h,
                    ),
                    decoration: BoxDecoration(
                      color: _selectedCropRatio != 'Free'
                          ? royalblue.withValues(alpha: 0.25)
                          : Colors.white.withValues(alpha: 0.12),
                      borderRadius: allradius(16.r),
                      border: Border.all(
                        color: _selectedCropRatio != 'Free'
                            ? royalblue
                            : Colors.white24,
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _selectedCropRatio,
                          style: GoogleFonts.outfit(
                            color: _selectedCropRatio != 'Free'
                                ? royalblue
                                : Colors.white70,
                            fontSize: 11.sp,
                            fontWeight: _selectedCropRatio != 'Free'
                                ? FontWeight.bold
                                : FontWeight.w500,
                          ),
                        ),
                        SizedBox(width: 2.w),
                        Icon(
                          Icons.arrow_drop_up_rounded,
                          color: _selectedCropRatio != 'Free'
                              ? royalblue
                              : Colors.white70,
                          size: 18.sp,
                        ),
                      ],
                    ),
                  ),
                ),
                Gap(15.h),
                // Filter button
                IconButton(
                  tooltip:
                      "Filters${_selectedFilterId != 'none' ? ' (${_selectedFilterItem.name})' : ''}",
                  icon: Icon(
                    CommunityMaterialIcons.image_filter_black_white,
                    color: (_showFilterRow || _selectedFilterId != 'none')
                        ? yellow
                        : Colors.white70,
                  ),
                  onPressed: () {
                    setState(() {
                      _showFilterRow = !_showFilterRow;
                    });
                    if (_showFilterRow) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (_filterPageController.hasClients) {
                          _filterPageController.jumpToPage(
                            _selectedFilterIndex,
                          );
                        }
                      });
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- REALTIME FILTER ROW ---
  Widget _buildFilterRow() {
    return Container(
      height: 94.h,
      margin: EdgeInsets.symmetric(horizontal: 12.w),
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
              setState(() {
                _selectedFilterId = item.id;
              });
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
                          width: 48.r,
                          height: 52.r,
                          decoration: BoxDecoration(
                            color: yellow.withValues(alpha: 0.15),
                            borderRadius: allradius(6.r),
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
                                : File(
                                    _capturedImages.isNotEmpty
                                        ? _capturedImages.last
                                        : "",
                                  ).existsSync()
                                ? Image.file(
                                    File(_capturedImages.last),
                                    fit: BoxFit.cover,
                                    cacheWidth: 120,
                                  )
                                : Icon(
                                    CommunityMaterialIcons
                                        .image_filter_black_white,
                                    color: isSel ? yellow : Colors.white70,
                                    size: 20.r,
                                  ),
                          ),
                        ),
                      ),
                      Gap(6.h),
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          color: isSel ? yellow : Colors.white70,
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
    );
  }

  // --- EXPANDED SHEET CONTENT ---
  Widget _buildExpandedSheetContent(BuildContext context, double w) {
    return Column(
      children: [
        // Top Sheet Header
        Padding(
          padding: EdgeInsets.only(left: 12.w, right: 12.w, top: 8.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                tooltip: "Collapse Sheet",
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.white,
                  size: 28,
                ),
                onPressed: () => _setSheetExpanded(false),
              ),
              Text(
                "Document Board",
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 17.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_capturedImages.isNotEmpty)
                TextButton(
                  onPressed: _clearAllCapturedImages,
                  child: const Text(
                    "Clear",
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else
                const SizedBox(width: 48),
            ],
          ),
        ),

        // Tab Bar
        TabBar(
          controller: _sheetTabController,
          indicatorColor: royalblue,
          indicatorWeight: 5,
          labelColor: Colors.white,
          dividerColor: transparent,
          indicatorSize: TabBarIndicatorSize.tab,
          unselectedLabelColor: Colors.white54,
          labelStyle: GoogleFonts.outfit(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
          ),
          tabs: [
            Tab(text: "Scanned (${_capturedImages.length})"),
            Tab(
              text: _selectedAssets.isNotEmpty
                  ? "Gallery (${_selectedAssets.length} sel)"
                  : "Gallery (${_albumAssets.length})",
            ),
          ],
        ),

        // Tab Bar Views
        Expanded(
          child: TabBarView(
            controller: _sheetTabController,
            children: [
              // Tab 1: Scanned Images Reorderable Grid
              _buildScannedImagesTab(),

              // Tab 2: Gallery Picker Grid
              _buildGalleryPickerTab(),
            ],
          ),
        ),

        // Bottom Export / Action Bar
        Container(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: const Color(0xFF191920),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
          ),
          child: SafeArea(
            top: false,
            child: InkWell(
              onTap: _capturedImages.isNotEmpty ? _exportToPdf : null,
              child: Container(
                width: double.infinity,
                height: 48.h,
                decoration: BoxDecoration(
                  borderRadius: allradius(5),
                  border: Border.all(color: royalblue, width: 2),
                ),
                child: Center(
                  child: Text(
                    _capturedImages.isEmpty
                        ? "Export to PDF"
                        : "Export to PDF (${_capturedImages.length} Pages)",
                    style: GoogleFonts.outfit(
                      color: royalblue,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- TAB 1: SCANNED IMAGES (REORDERABLE GRID) ---
  Widget _buildScannedImagesTab() {
    if (_capturedImages.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24.r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.document_scanner_outlined,
                size: 56.r,
                color: Colors.white24,
              ),
              SizedBox(height: 12.h),
              Text(
                "No scanned pages yet",
                style: GoogleFonts.outfit(
                  color: Colors.white70,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                "Take photos using the camera shutter or import images from the Gallery tab.",
                textAlign: TextAlign.center,
                style: GoogleFonts.instrumentSans(
                  color: Colors.white38,
                  fontSize: 13.sp,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      child: ImageReorderableGrid(
        imagePaths: _capturedImages,
        crossAxisCount: 3,
        crossAxisSpacing: 10.w,
        mainAxisSpacing: 10.h,
        childAspectRatio: 0.72,
        padding: EdgeInsets.zero,
        onReorder: (updated) {
          setState(() {
            _capturedImages.clear();
            _capturedImages.addAll(updated);
          });
        },
        onItemTap: (index, path) => _openEditorForImage(index),
        onEditImage: (index, path) => _openEditorForImage(index),
        onSaveImage: (index, path) => _saveImageToGallery(path),
        onShareImage: (index, path) => _shareImage(path),
        onDeleteImage: (index, path) => _deleteCapturedImage(index),
      ),
    );
  }

  // --- TAB 2: GALLERY PICKER TAB ---
  Widget _buildGalleryPickerTab() {
    if (!_hasGalleryPermission && !_isLoadingGallery) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24.r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.no_photography_outlined,
                size: 52.r,
                color: Colors.white30,
              ),
              SizedBox(height: 12.h),
              Text(
                "Photo Access Required",
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                "PDF Hawk needs permission to access your device photos to select images for scanning.",
                textAlign: TextAlign.center,
                style: GoogleFonts.instrumentSans(
                  color: Colors.white54,
                  fontSize: 12.sp,
                ),
              ),
              SizedBox(height: 16.h),
              ElevatedButton.icon(
                icon: const Icon(Icons.settings_rounded, size: 16),
                label: const Text("Open App Settings"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: royalblue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: allradius(10.r)),
                ),
                onPressed: () {
                  PhotoManager.openSetting();
                },
              ),
              SizedBox(height: 8.h),
              TextButton.icon(
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text("Retry Access"),
                style: TextButton.styleFrom(foregroundColor: royalblue),
                onPressed: _initGalleryAlbums,
              ),
            ],
          ),
        ),
      );
    }

    final albumTitle = _currentAlbum?.name.isEmpty ?? true
        ? "Recent"
        : _currentAlbum!.name;

    return Column(
      children: [
        // Album Selector & Control Toolbar
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          child: Row(
            children: [
              // Album Dropdown Button
              InkWell(
                onTap: _showAlbumSelectionSheet,
                borderRadius: allradius(10.r),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 6.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: allradius(10.r),
                    border: Border.all(color: Colors.white24, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.photo_album_rounded,
                        color: royalblue,
                        size: 15.sp,
                      ),
                      SizedBox(width: 6.w),
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: 130.w),
                        child: Text(
                          albumTitle,
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 12.5.sp,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: 4.w),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.white70,
                        size: 18.sp,
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),

              // Quick Actions: Select/Clear All
              if (_albumAssets.isNotEmpty)
                TextButton(
                  onPressed: () {
                    setState(() {
                      if (_selectedAssets.length == _albumAssets.length) {
                        _selectedAssets.clear();
                      } else {
                        _selectedAssets.addAll(_albumAssets);
                      }
                    });
                  },
                  child: Text(
                    _selectedAssets.length == _albumAssets.length
                        ? "Deselect All"
                        : "Select All",
                    style: GoogleFonts.outfit(
                      color: royalblue,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

              // External Files Picker Fallback
              IconButton(
                tooltip: "Pick from System File Picker",
                icon: const Icon(
                  Icons.folder_open_rounded,
                  color: Colors.white70,
                  size: 20,
                ),
                onPressed: _pickImagesFromCustomPicker,
              ),
            ],
          ),
        ),

        // Gallery Grid View
        Expanded(
          child: _isLoadingGallery && _albumAssets.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(
                    color: royalblue,
                    strokeWidth: 2.5,
                  ),
                )
              : _albumAssets.isEmpty
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.r),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.photo_library_outlined,
                          size: 48.r,
                          color: Colors.white24,
                        ),
                        SizedBox(height: 12.h),
                        Text(
                          "No photos in this album",
                          style: GoogleFonts.outfit(
                            color: Colors.white70,
                            fontSize: 15.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : GridView.builder(
                  controller: _galleryScrollController,
                  padding: EdgeInsets.symmetric(horizontal: 10.w),
                  itemCount:
                      _albumAssets.length + (_isLoadingMoreAssets ? 1 : 0),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 6.w,
                    mainAxisSpacing: 6.h,
                    childAspectRatio: 1.0,
                  ),
                  itemBuilder: (context, index) {
                    if (index >= _albumAssets.length) {
                      return const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: royalblue,
                          ),
                        ),
                      );
                    }

                    final asset = _albumAssets[index];
                    final isSelected = _selectedAssets.contains(asset);

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedAssets.remove(asset);
                          } else {
                            _selectedAssets.add(asset);
                          }
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        decoration: BoxDecoration(
                          borderRadius: allradius(8.r),
                          border: Border.all(
                            color: isSelected ? royalblue : Colors.transparent,
                            width: isSelected ? 2.5 : 0,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: allradius(isSelected ? 6.r : 8.r),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              AssetEntityImage(
                                asset,
                                isOriginal: false,
                                thumbnailSize: const ThumbnailSize.square(240),
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, progress) {
                                  if (progress == null) return child;
                                  return Container(
                                    color: Colors.white10,
                                    child: const Center(
                                      child: SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 1.5,
                                          color: Colors.white24,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              if (isSelected)
                                Container(
                                  color: royalblue.withValues(alpha: 0.35),
                                ),
                              Positioned(
                                top: 5.r,
                                right: 5.r,
                                child: Container(
                                  padding: EdgeInsets.all(1.5.r),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? royalblue
                                        : Colors.black45,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 1.2,
                                    ),
                                  ),
                                  child: Icon(
                                    isSelected ? Icons.check_rounded : null,
                                    color: Colors.white,
                                    size: 14.sp,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),

        // Add Selected Button
        if (_selectedAssets.isNotEmpty)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(
                  "Add ${_selectedAssets.length} to Scanned Pages",
                  style: GoogleFonts.outfit(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: royalblue,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  shape: RoundedRectangleBorder(borderRadius: allradius(12.r)),
                  elevation: 4,
                ),
                onPressed: _addSelectedAssetsToScanList,
              ),
            ),
          ),
      ],
    );
  }

  // --- TOP BAR ASPECT RATIO & HI-RES BUTTONS ---
  // --- ASPECT RATIO ICON & TOP BUTTONS ---
  Widget _buildAspectRatioIcon(
    String ratio, {
    Color color = Colors.white,
    double size = 16,
  }) {
    double w = size;
    double h = size;
    switch (ratio) {
      case '1:1':
        w = size * 0.9;
        h = size * 0.9;
        break;
      case '4:3':
      case '3:4':
        w = size * 0.75;
        h = size;
        break;
      case '16:9':
      case '9:16':
        w = size * 0.56;
        h = size;
        break;
      case 'A4':
        w = size * 0.70;
        h = size;
        break;
      case '3:2':
      case '2:3':
        w = size * 0.67;
        h = size;
        break;
      case 'Full':
      case 'Free':
      default:
        w = size * 0.85;
        h = size;
        break;
    }

    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 1.4),
        borderRadius: BorderRadius.circular(2.r),
      ),
      child: ratio == 'Full' || ratio == 'Free'
          ? Center(
              child: Container(
                width: 2,
                height: 2,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            )
          : null,
    );
  }

  // --- CAMERA ASPECT RATIO MENU & TOP BUTTONS ---
  Widget _buildCameraAspectRatioMenu() {
    return PopupMenuButton<String>(
      tooltip: "Camera Aspect Ratio",
      offset: Offset(0, 42.h),
      color: const Color(0xFF1E1E26),
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: allradius(14.r),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.15), width: 1),
      ),
      onSelected: (ratio) {
        setState(() {
          _cameraAspectRatio = ratio;
        });
      },
      itemBuilder: (context) =>
          [
            {'ratio': '4:3', 'label': '4:3', 'desc': 'Standard'},
            {'ratio': '16:9', 'label': '16:9', 'desc': 'Cinematic'},
            {'ratio': '1:1', 'label': '1:1', 'desc': 'Square'},
            {'ratio': 'Full', 'label': 'Full', 'desc': 'Full Viewfinder'},
          ].map((item) {
            final r = item['ratio']!;
            final isSel = _cameraAspectRatio == r;
            return PopupMenuItem<String>(
              value: r,
              height: 40.h,
              child: Row(
                children: [
                  Container(
                    width: 22.w,
                    alignment: Alignment.center,
                    child: _buildAspectRatioIcon(
                      r,
                      color: isSel ? yellow : Colors.white70,
                      size: 15.r,
                    ),
                  ),
                  Gap(10.w),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          item['label']!,
                          style: GoogleFonts.outfit(
                            color: isSel ? yellow : Colors.white,
                            fontWeight: isSel
                                ? FontWeight.bold
                                : FontWeight.w600,
                            fontSize: 13.sp,
                          ),
                        ),
                        Text(
                          item['desc']!,
                          style: GoogleFonts.outfit(
                            color: isSel
                                ? yellow.withValues(alpha: 0.7)
                                : Colors.white38,
                            fontSize: 11.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Gap(8.w),
                  if (isSel)
                    const Icon(Icons.check_rounded, color: yellow, size: 16)
                  else
                    const SizedBox(width: 16),
                ],
              ),
            );
          }).toList(),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
        // decoration: BoxDecoration(
        //   color: _cameraAspectRatio != 'Full'
        //       ? yellow.withValues(alpha: 0.2)
        //       : Colors.white.withValues(alpha: 0.12),
        //   borderRadius: allradius(16.r),
        //   border: Border.all(
        //     color: _cameraAspectRatio != 'Full' ? yellow : Colors.white24,
        //     width: 1.2,
        //   ),
        // ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildAspectRatioIcon(
              _cameraAspectRatio,
              color: _cameraAspectRatio != 'Full' ? yellow : Colors.white70,
              size: 14.r,
            ),
            SizedBox(width: 5.w),
            Text(
              _cameraAspectRatio,
              style: GoogleFonts.outfit(
                color: _cameraAspectRatio != 'Full' ? yellow : Colors.white70,
                fontSize: 11.5.sp,
                fontWeight: _cameraAspectRatio != 'Full'
                    ? FontWeight.bold
                    : FontWeight.w500,
              ),
            ),
            SizedBox(width: 2.w),
            Icon(
              Icons.arrow_drop_down_rounded,
              color: _cameraAspectRatio != 'Full' ? yellow : Colors.white70,
              size: 18.sp,
            ),
          ],
        ),
      ),
    );
  }
}
