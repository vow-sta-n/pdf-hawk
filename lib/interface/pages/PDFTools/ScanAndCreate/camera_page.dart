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
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_image_filters/flutter_image_filters.dart';
import 'package:pdfhawk/data/models/editor_filter_item.dart';
import 'package:pdfhawk/data/res/theme.dart';
import 'package:pdfhawk/data/res/utils.dart';
import 'package:pdfhawk/interface/globals/curved_list.dart';
import 'package:pdfhawk/interface/pages/PDFTools/ScanAndCreate/document_board_bottom_sheet.dart';
import 'package:pdfhawk/interface/painters/camera_corner_painter.dart';
import 'package:pdfhawk/interface/painters/camera_crop_mask_painter.dart';
import 'package:pdfhawk/interface/painters/shutter_progress_painter.dart';

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
  int _currentIndex = 1;
  String _selectedFilterId = 'none';
  List<EditorFilterItem> get _filters => kAppEditorFilters;
  EditorFilterItem get _selectedFilterItem =>
      getEditorFilterItem(_selectedFilterId);
  int get _selectedFilterIndex {
    final idx = _filters.indexWhere((f) => f.id == _selectedFilterId);
    return idx >= 0 ? idx : 0;
  }

  static const List<String> _cropRatios = [
    'None',
    'Free',
    '1:1',
    '4:3',
    '16:9',
    'A4',
    '3:2',
  ];
  String _selectedCropRatio = 'Free';
  int get _selectedCropIndex {
    final idx = _cropRatios.indexOf(_selectedCropRatio);
    return idx >= 0 ? idx : 1;
  }

  Size _lastPreviewSize = const Size(360, 640);
  double _minAvailableZoom = 1.0;
  double _maxAvailableZoom = 1.0;
  bool _showZoomBadge = false;
  double _currentScale = 1.0;
  double _baseScale = 1.0;
  Offset? _tapFocusOffset;
  Timer? _focusResetTimer;
  Timer? _zoomBadgeTimer;
  int _pointers = 0;
  late PageController _carouselController;
  late PageController _filterListController;
  late PageController _cropListController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _shutterProgressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scanAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _filterListController = PageController(
      viewportFraction: 0.25,
      initialPage: 0,
    );
    _carouselController = PageController(
      viewportFraction: 0.25,
      initialPage: 1,
    );
    _cropListController = PageController(
      viewportFraction: 0.25,
      initialPage: _selectedCropIndex,
    );
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focusResetTimer?.cancel();
    _zoomBadgeTimer?.cancel();
    _controller?.dispose();
    _shutterProgressController.dispose();
    _scanAnimationController.dispose();
    _filterListController.dispose();
    _carouselController.dispose();
    _cropListController.dispose();
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
      if (cameraController != null && cameraController.value.isInitialized) {
        cameraController.dispose();
      }
    } else if (state == AppLifecycleState.resumed) {
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

  /// Returns 2.5:4 portrait aspect ratio (2.5 / 4 = 0.625) as default camera aspect ratio.
  double _getCameraAspectRatio() {
    return 2.5 / 4;
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
      case 'None':
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

      img.Image processedImage = decoded;

      // 2. Crop to match the 4:3 or device default camera aspect ratio if necessary
      final cameraRatio = _getCameraAspectRatio();
      final imgW = processedImage.width;
      final imgH = processedImage.height;
      final currentRatio = imgW / imgH;
      if ((currentRatio - cameraRatio).abs() > 0.02) {
        int cropW = imgW;
        int cropH = (cropW / cameraRatio).round();
        if (cropH > imgH) {
          cropH = imgH;
          cropW = (cropH * cameraRatio).round();
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

      // 3. Apply Crop Ratio when crop is enabled (not 'None')
      if (_selectedCropRatio != 'None') {
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

  void _openDocumentBoard() {
    final controller = _controller;
    if (controller != null && controller.value.isInitialized) {
      try {
        controller.pausePreview();
      } catch (e) {
        debugPrint("Error pausing camera preview: $e");
      }
    }

    bottomSheet(
      context,
      DocumentBoardBottomSheet(
        capturedImages: _capturedImages,
        onImagesUpdated: (updated) {
          setState(() {
            _capturedImages.clear();
            _capturedImages.addAll(updated);
          });
        },
      ),
      onClose: () {
        final controller = _controller;
        if (controller != null && controller.value.isInitialized) {
          try {
            controller.resumePreview();
          } catch (e) {
            debugPrint("Error resuming camera preview: $e");
          }
        }
      },
    );
  }

  IconData _getFlashIcon() {
    switch (_flashMode) {
      case FlashMode.off:
        return CommunityMaterialIcons.flash_off;
      case FlashMode.always:
        return CommunityMaterialIcons.flash_circle;
      case FlashMode.auto:
        return CommunityMaterialIcons.flash_auto;
      case FlashMode.torch:
        return CommunityMaterialIcons.flash;
    }
  }

  void _handleBackNavigation() {
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
                            final cameraRatio = _getCameraAspectRatio();

                            return Center(
                              child: AspectRatio(
                                aspectRatio: cameraRatio,
                                child: ClipRect(
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      return Listener(
                                        onPointerDown: (_) => _pointers++,
                                        onPointerUp: (_) => _pointers =
                                            (_pointers - 1).clamp(0, 10),
                                        onPointerCancel: (_) => _pointers =
                                            (_pointers - 1).clamp(0, 10),
                                        child: GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onScaleStart: _handleScaleStart,
                                          onScaleUpdate: _handleScaleUpdate,
                                          onTapUp: (details) =>
                                              _handleTapToFocus(
                                                details,
                                                constraints,
                                              ),
                                          child: Stack(
                                            alignment: Alignment.center,
                                            fit: StackFit.expand,
                                            children: [
                                              // Native camera stream fitted into viewport
                                              FittedBox(
                                                fit: BoxFit.cover,
                                                child: SizedBox(
                                                  width:
                                                      _controller!
                                                              .value
                                                              .previewSize !=
                                                          null
                                                      ? _controller!
                                                            .value
                                                            .previewSize!
                                                            .height
                                                      : constraints.maxWidth,
                                                  height:
                                                      _controller!
                                                              .value
                                                              .previewSize !=
                                                          null
                                                      ? _controller!
                                                            .value
                                                            .previewSize!
                                                            .width
                                                      : constraints.maxHeight,
                                                  child:
                                                      _buildLiveCameraPreview(),
                                                ),
                                              ),

                                              // Tap to focus ring animation
                                              if (_tapFocusOffset != null)
                                                Positioned(
                                                  left:
                                                      _tapFocusOffset!.dx - 28,
                                                  top: _tapFocusOffset!.dy - 28,
                                                  child: TweenAnimationBuilder<double>(
                                                    tween: Tween(
                                                      begin: 1.3,
                                                      end: 1.0,
                                                    ),
                                                    duration: const Duration(
                                                      milliseconds: 200,
                                                    ),
                                                    builder: (context, val, child) {
                                                      return Transform.scale(
                                                        scale: val,
                                                        child: Container(
                                                          width: 56,
                                                          height: 56,
                                                          decoration:
                                                              BoxDecoration(
                                                                shape: BoxShape
                                                                    .circle,
                                                                border:
                                                                    Border.all(
                                                                      color:
                                                                          yellow,
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
                                                        padding:
                                                            EdgeInsets.symmetric(
                                                              horizontal: 14.w,
                                                              vertical: 5.h,
                                                            ),
                                                        decoration:
                                                            BoxDecoration(
                                                              color: Colors
                                                                  .black
                                                                  .withValues(
                                                                    alpha: 0.65,
                                                                  ),
                                                              borderRadius:
                                                                  allradius(
                                                                    16.r,
                                                                  ),
                                                              border: Border.all(
                                                                color: Colors
                                                                    .white24,
                                                                width: 1,
                                                              ),
                                                            ),
                                                        child: Text(
                                                          "${_currentScale.toStringAsFixed(1)}x",
                                                          style:
                                                              GoogleFonts.outfit(
                                                                color: Colors
                                                                    .white,
                                                                fontSize: 13.sp,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
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
                                                      if (_selectedCropRatio !=
                                                          'None')
                                                        Positioned.fill(
                                                          child: IgnorePointer(
                                                            child: CustomPaint(
                                                              size: constraints
                                                                  .biggest,
                                                              painter: CameraCropMaskPainter(
                                                                frameRect:
                                                                    frameRect,
                                                                maskColor: Colors
                                                                    .black
                                                                    .withValues(
                                                                      alpha:
                                                                          0.65,
                                                                    ),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      Positioned(
                                                        left: frameRect.left,
                                                        top: frameRect.top,
                                                        width: frameRect.width,
                                                        height:
                                                            frameRect.height,
                                                        child: IgnorePointer(
                                                          child: const CustomPaint(
                                                            size: Size.infinite,
                                                            painter:
                                                                CameraCornerPainter(
                                                                  color:
                                                                      Color.fromARGB(
                                                                        140,
                                                                        255,
                                                                        255,
                                                                        255,
                                                                      ),
                                                                  cornerLength:
                                                                      32.0,
                                                                  cornerRadius:
                                                                      4.0,
                                                                  strokeWidth:
                                                                      1.0,
                                                                ),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      // Top Bar
                      Positioned(
                        top: -20,
                        left: 0,
                        right: 0,
                        child: curvedMenu(
                          60,
                          MediaQuery.of(context).size.width,
                        ),
                      ),

                      // Filter Selection Row
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 40,
                        child: filterRow(MediaQuery.of(context).size.width),
                      ),

                      // Crop Ratio Selection Row
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 40,
                        child: cropRow(MediaQuery.of(context).size.width),
                      ),

                      // Shutter bar at bottom
                      Positioned(
                        left: 20,
                        right: 20,
                        bottom: -10,
                        height: sheetCollapsedHeight.h,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Spacer(),

                            SizedBox(
                              width: getWidth(context) / 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Arrow up button above shutter with count badge
                                  GestureDetector(
                                    onTap: _openDocumentBoard,
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 14.w,
                                        vertical: 5.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.12,
                                        ),
                                        borderRadius: allradius(16.r),
                                        border: Border.all(
                                          color: Colors.white24,
                                          width: 1,
                                        ),
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
                                                color: yellow,
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
                                              progress:
                                                  _shutterProgressController
                                                      .value,
                                              strokeWidth: 4.r,
                                              baseColor: Colors.white,
                                              progressColor: yellow,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const Spacer(),
                          ],
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

  Widget _buildLiveCameraPreview() {
    final preview = CameraPreview(_controller!);
    final colorFilter = _selectedFilterItem.colorFilter;
    if (colorFilter == null) {
      return preview;
    }
    return ColorFiltered(colorFilter: colorFilter, child: preview);
  }

  Widget curvedMenu(double h, double w) {
    return SizedBox(
      height: h,
      width: w,
      child: Stack(
        children: [
          Positioned(
            bottom: -15,
            child: SizedBox(
              height: h,
              width: w,
              child: CurvedCarousel(
                pageController: _carouselController,
                initialIndex: 1,
                curveScale: 5.8,
                onChangeStart: (ik) {
                  setState(() {
                    _currentIndex = ik;
                  });
                },
                onChangeEnd: (ik) {
                  setState(() {
                    _currentIndex = ik;
                  });
                  if (ik == 1) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_filterListController.hasClients) {
                        _filterListController.jumpToPage(_selectedFilterIndex);
                      }
                    });
                  } else if (ik == 2) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_cropListController.hasClients) {
                        _cropListController.jumpToPage(_selectedCropIndex);
                      }
                    });
                  }
                },
                itemBuilder: (context, i, ik) {
                  return tools(i, ik);
                },
                itemCount: 3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget tools(int i, int ki) {
    Widget template({
      required VoidCallback onTap,
      required IconData icon,
      bool isActive = false,
      String? tooltip,
    }) {
      final button = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (ki == i) {
            onTap();
          } else {
            _carouselController.animateToPage(
              i,
              duration: const Duration(milliseconds: 200),
              curve: Curves.ease,
            );
            onTap();
          }
        },
        child: SizedBox.square(
          dimension: 50,
          child: Center(
            child: Icon(
              icon,
              size: 20.sp,
              color: isActive ? yellow : (ki == i ? yellow : Colors.white60),
            ),
          ),
        ),
      );

      if (tooltip != null) {
        return Tooltip(message: tooltip, child: button);
      }
      return button;
    }

    final List<Widget> temp = [
      template(
        onTap: _cycleFlashMode,
        icon: _getFlashIcon(),
        isActive: _flashMode != FlashMode.off,
        tooltip: "Flash ${_flashMode.name}",
      ),
      template(
        onTap: () {
          if (_currentIndex != 1) {
            setState(() {
              _currentIndex = 1;
            });
          }
          if (_filterListController.hasClients) {
            _filterListController.jumpToPage(_selectedFilterIndex);
          }
        },
        icon: CommunityMaterialIcons.function_variant,
        isActive: _currentIndex == 1 || _selectedFilterId != 'none',
        tooltip:
            "Filters${_selectedFilterId != 'none' ? ' (${_selectedFilterItem.name})' : ''}",
      ),
      template(
        onTap: () {
          if (_currentIndex != 2) {
            setState(() {
              _currentIndex = 2;
            });
          }
          if (_cropListController.hasClients) {
            _cropListController.jumpToPage(_selectedCropIndex);
          }
        },
        icon: Icons.crop,
        isActive: _currentIndex == 2 || _selectedCropRatio != 'None',
        tooltip: _selectedCropRatio != 'None'
            ? "Crop: $_selectedCropRatio"
            : "Crop",
      ),
    ];

    if (i >= 0 && i < temp.length) {
      return temp[i];
    }
    return const SizedBox.shrink();
  }

  Widget filterRow(double w) {
    final isVisible = _currentIndex == 1;
    return Visibility(
      visible: isVisible,
      maintainState: true,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: isVisible ? 1 : 0,
        child: SizedBox(
          height: 100,
          width: w,
          child: Center(
            child: CurvedCarousel(
              scaleMiddleItem: false,
              curveScale: 9,
              onChangeStart: (ik) {},
              onChangeEnd: (ik) {
                if (ik >= 0 && ik < _filters.length) {
                  setState(() {
                    _selectedFilterId = _filters[ik].id;
                  });
                }
              },
              tiltItemWithCurve: false,
              pageController: _filterListController,
              initialIndex: _selectedFilterIndex,
              itemBuilder: (context, ind, i) {
                final isSelected = ind == _selectedFilterIndex;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    _filterListController.animateToPage(
                      ind,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.ease,
                    );
                    setState(() {
                      _selectedFilterId = _filters[ind].id;
                    });
                  },
                  child: SizedBox(
                    height: 30,
                    child: Center(
                      child: Container(
                        height: 30,
                        padding: const EdgeInsets.fromLTRB(5, 8, 5, 8),
                        decoration: BoxDecoration(
                          color: isSelected ? yellow : transparent,
                          borderRadius: allradius(4),
                        ),
                        child: Center(
                          child: Text(
                            _filters[ind].name
                                .toUpperCase()
                                .replaceAll('ADDICTIVE', '')
                                .replaceAll(' ', ''),
                            maxLines: 1,
                            style: GoogleFonts.lato(
                              fontSize: 10.sp,
                              color: isSelected ? black : yellow,
                              height: 1,
                              fontWeight: isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
              itemCount: _filters.length,
            ),
          ),
        ),
      ),
    );
  }

  Widget cropRow(double w) {
    final isVisible = _currentIndex == 2;
    return Visibility(
      visible: isVisible,
      maintainState: true,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: isVisible ? 1 : 0,
        child: SizedBox(
          height: 100,
          width: w,
          child: Center(
            child: CurvedCarousel(
              scaleMiddleItem: false,
              curveScale: 9,
              onChangeStart: (ik) {},
              onChangeEnd: (ik) {
                if (ik >= 0 && ik < _cropRatios.length) {
                  setState(() {
                    _selectedCropRatio = _cropRatios[ik];
                  });
                }
              },
              tiltItemWithCurve: false,
              pageController: _cropListController,
              initialIndex: _selectedCropIndex,
              itemBuilder: (context, ind, i) {
                final isSelected = ind == _selectedCropIndex;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    _cropListController.animateToPage(
                      ind,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.ease,
                    );
                    setState(() {
                      _selectedCropRatio = _cropRatios[ind];
                    });
                  },
                  child: SizedBox(
                    height: 30,
                    child: Center(
                      child: Container(
                        height: 30,
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: isSelected ? yellow : transparent,
                          borderRadius: allradius(4),
                        ),
                        child: Center(
                          child: Text(
                            _cropRatios[ind].toUpperCase(),
                            maxLines: 1,
                            style: GoogleFonts.lato(
                              fontSize: 10.sp,
                              color: isSelected ? black : yellow,
                              height: 1,
                              fontWeight: isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
              itemCount: _cropRatios.length,
            ),
          ),
        ),
      ),
    );
  }
}
