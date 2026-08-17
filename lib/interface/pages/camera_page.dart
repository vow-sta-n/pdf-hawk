/*
 * PDF Hawk - Modern PDF Reader, Writer, Editor & Scanner
 * Copyright (C) 2026 Van Stan / Novaturients
 *
 * This software is licensed under the PolyForm Noncommercial License 1.0.0.
 * You may obtain a copy of the License at https://polyformproject.org/licenses/noncommercial/1.0.0
 */

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:camera/camera.dart';
import 'package:pdfhawk/interface/widgets/level_gauge_widget.dart';
import 'package:pdfhawk/data/res/constants.dart';
import 'package:pdfhawk/data/res/theme.dart';
import 'package:pdfhawk/interface/pages/master_pdf_editor_page.dart';
import 'package:pdfhawk/interface/painters/camera_corner_painter.dart';
import 'package:pdfhawk/interface/painters/scanner_shimmer_painter.dart';
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
  int _selectedCameraIndex = 0;
  bool _isTakingPicture = false;
  bool showImages = false;
  late final AnimationController _shutterProgressController;
  late final AnimationController _scanAnimationController;

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
    _initializeCamera();
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
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _controller;

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      levelGaugeController.stop();
      stabilizationController.stop();
      if (cameraController != null && cameraController.value.isInitialized) {
        cameraController.dispose();
      }
    } else if (state == AppLifecycleState.resumed) {
      levelGaugeController.start();
      stabilizationController.start();
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
      }
    } catch (e) {
      _showSnackBar("Error listing cameras: $e");
    }
  }

  Future<void> _onNewCameraSelected(CameraDescription cameraDescription) async {
    if (_controller != null) {
      await _controller!.dispose();
    }

    final CameraController cameraController = CameraController(
      cameraDescription,
      ResolutionPreset.max, // Ultra-high resolution
      enableAudio: false,
    );

    _controller = cameraController;

    cameraController.addListener(() {
      if (mounted) setState(() {});
    });

    try {
      await cameraController.initialize();
      await cameraController.setFlashMode(_flashMode);

      final minZoom = await cameraController.getMinZoomLevel();
      final maxZoom = await cameraController.getMaxZoomLevel();

      _minAvailableZoom = minZoom;
      _maxAvailableZoom = maxZoom.clamp(1.0, 8.0);
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
    // Only adjust zoom if 2 fingers are touching the screen (pinch gesture)
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
    _shutterProgressController.reset();
    _shutterProgressController.animateTo(
      0.9,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
    );

    try {
      final file = await _controller!.takePicture();
      await _shutterProgressController.animateTo(
        1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeIn,
      );
      await Future.delayed(const Duration(milliseconds: 80));

      if (mounted) {
        setState(() {
          _capturedImages.add(file.path);
        });
      }
    } on CameraException catch (e) {
      _showSnackBar("Error taking picture: ${e.description}");
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
      setState(() {
        _flashMode = nextMode;
      });
      _showSnackBar(
        "Flash: ${nextMode.toString().split('.').last.toUpperCase()}",
      );
    } catch (e) {
      _showSnackBar("Failed to set flash mode: $e");
    }
  }

  void _showSnackBar(String text) {
    if (!mounted) return;
    debugPrint(text);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: royalblue,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
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

  void _showPreviewDialog(String imagePath, int index) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16.r),
              child: Image.file(File(imagePath), fit: BoxFit.contain),
            ),
            Positioned(
              top: 10.h,
              right: 10.w,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            Positioned(
              top: 10.h,
              left: 10.w,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: Icon(Icons.delete, color: red, size: 18.sp),
                  onPressed: () => _confirmDeleteImage(index),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteImage(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Scanned Image?"),
        content: const Text(
          "Are you sure you want to discard this captured image?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                final path = _capturedImages.removeAt(index);
                final file = File(path);
                if (file.existsSync()) {
                  file.deleteSync();
                }
              });
              Navigator.pop(context);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double w = getWidth(context);
    return Theme(
      data: Theme.of(context).copyWith(
        primaryColor: royalblue,
        colorScheme: Theme.of(context).colorScheme.copyWith(primary: royalblue),
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              // Top Bar
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        // Discard all captured images
                        for (final path in _capturedImages) {
                          final file = File(path);
                          if (file.existsSync()) {
                            file.deleteSync();
                          }
                        }
                        Navigator.pop(context);
                      },
                    ),
                    Text(
                      "Scan Document",
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    // Spacer or toggle camera
                    _cameras.length > 1
                        ? IconButton(
                            icon: const Icon(
                              Icons.flip_camera_ios_rounded,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              _selectedCameraIndex =
                                  (_selectedCameraIndex + 1) % _cameras.length;
                              _onNewCameraSelected(
                                _cameras[_selectedCameraIndex],
                              );
                            },
                          )
                        : const SizedBox(width: 48),
                  ],
                ),
              ),

              // Camera Viewfinder / Preview
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(color: Colors.black),
                  clipBehavior: Clip.antiAlias,
                  child: _isCameraInitialized && _controller != null
                      ? LayoutBuilder(
                          builder: (context, constraints) {
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
                                  fit: StackFit.expand,
                                  children: [
                                    CameraPreview(_controller!),

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
                                                    color: royalblue,
                                                    width: 1.8,
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),

                                    // Live Zoom multiplier pill indicator
                                    if (_showZoomBadge || _currentScale > 1.05)
                                      Positioned(
                                        bottom: 16.h,
                                        left: 0,
                                        right: 0,
                                        child: Center(
                                          child: AnimatedOpacity(
                                            opacity: _showZoomBadge ? 1.0 : 0.7,
                                            duration: const Duration(
                                              milliseconds: 200,
                                            ),
                                            child: Container(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 14.w,
                                                vertical: 5.h,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withValues(
                                                  alpha: 0.65,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(16.r),
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

                                    // Camera Corner Framing Guides with Live Scanning Shimmer
                                    IgnorePointer(
                                      child: Container(
                                        width: double.infinity,
                                        height: double.infinity,
                                        margin: const EdgeInsets.all(40),
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            // Live scanning shimmer beam during active capture
                                            if (_isTakingPicture)
                                              AnimatedBuilder(
                                                animation:
                                                    _scanAnimationController,
                                                builder: (context, child) {
                                                  return CustomPaint(
                                                    painter: ScannerShimmerPainter(
                                                      progress:
                                                          _scanAnimationController
                                                              .value,
                                                      glowColor: royalblue,
                                                      cornerRadius: 2.0,
                                                    ),
                                                  );
                                                },
                                              ),

                                            // Corner guides
                                            const CustomPaint(
                                              size: Size.infinite,
                                              painter: CameraCornerPainter(
                                                color: Color.fromARGB(
                                                  95,
                                                  255,
                                                  255,
                                                  255,
                                                ),
                                                cornerLength: 32.0,
                                                cornerRadius: 2.0,
                                                strokeWidth: 1.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    //level
                                    UnifiedLevelStabilizer(
                                      level: true,
                                      stablize: true,
                                      primaryColor: royalblue,
                                      angleStream:
                                          levelGaugeController.angleStream,
                                      stabilityStream: stabilizationController
                                          .stabilityStream,
                                    ),

                                    if (_capturedImages.isNotEmpty) ...[
                                      Positioned(
                                        bottom: 0,
                                        child: SizedBox(
                                          width: w,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              InkWell(
                                                onTap: () => setState(
                                                  () =>
                                                      showImages = !showImages,
                                                ),
                                                child: Container(
                                                  width: 100,
                                                  decoration: BoxDecoration(
                                                    color: black,
                                                    borderRadius:
                                                        BorderRadius.only(
                                                          topLeft:
                                                              Radius.circular(
                                                                8.r,
                                                              ),
                                                          topRight:
                                                              Radius.circular(
                                                                8.r,
                                                              ),
                                                        ),
                                                  ),
                                                  child: Center(
                                                    child: AnimatedRotation(
                                                      turns: showImages ? 1 : 0,
                                                      duration: Duration(
                                                        milliseconds: 600,
                                                      ),
                                                      child: Icon(
                                                        showImages
                                                            ? Icons
                                                                  .keyboard_arrow_down_rounded
                                                            : Icons
                                                                  .keyboard_arrow_up_outlined,
                                                        color: white,
                                                        size: 20.sp,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              AnimatedContainer(
                                                height: showImages ? 70.h : 0.h,
                                                width: w,
                                                duration: Duration(
                                                  milliseconds: 100,
                                                ),
                                                curve: Curves.easeIn,
                                                padding: EdgeInsets.only(
                                                  top: 10.h,
                                                ),
                                                color: black,
                                                child: ListView.builder(
                                                  scrollDirection:
                                                      Axis.horizontal,
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal: 16.w,
                                                  ),
                                                  itemCount:
                                                      _capturedImages.length,
                                                  itemBuilder: (context, index) {
                                                    final path =
                                                        _capturedImages[index];
                                                    return GestureDetector(
                                                      onTap: () =>
                                                          _showPreviewDialog(
                                                            path,
                                                            index,
                                                          ),
                                                      onLongPress: () =>
                                                          _confirmDeleteImage(
                                                            index,
                                                          ),
                                                      child: Container(
                                                        width: 50.w,
                                                        margin: EdgeInsets.only(
                                                          right: 12.w,
                                                        ),
                                                        decoration: BoxDecoration(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                1.r,
                                                              ),
                                                          border: Border.all(
                                                            color:
                                                                Colors.white70,
                                                            width: 1.5,
                                                          ),
                                                          image:
                                                              DecorationImage(
                                                                image:
                                                                    FileImage(
                                                                      File(
                                                                        path,
                                                                      ),
                                                                    ),
                                                                fit: BoxFit
                                                                    .cover,
                                                              ),
                                                        ),
                                                        child: Align(
                                                          alignment: Alignment
                                                              .topRight,
                                                          child: Container(
                                                            margin:
                                                                EdgeInsets.all(
                                                                  4.r,
                                                                ),
                                                            padding:
                                                                EdgeInsets.all(
                                                                  2.r,
                                                                ),
                                                            decoration:
                                                                const BoxDecoration(
                                                                  color: Colors
                                                                      .black54,
                                                                  shape: BoxShape
                                                                      .circle,
                                                                ),
                                                            child: Text(
                                                              "${index + 1}",
                                                              style: TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontSize: 10.sp,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        )
                      : const Center(
                          child: CircularProgressIndicator(color: royalblue),
                        ),
                ),
              ),
              // Capture Shutter Rows
              Container(
                height: null,
                decoration: BoxDecoration(color: black),
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Flash button
                    CircleAvatar(
                      radius: 26.r,
                      backgroundColor: Colors.white10,
                      child: IconButton(
                        icon: Icon(_getFlashIcon(), color: Colors.white),
                        onPressed: _cycleFlashMode,
                      ),
                    ),

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

                    // Finish / Check circle button
                    CircleAvatar(
                      radius: 26.r,
                      backgroundColor: _capturedImages.isNotEmpty
                          ? royalblue
                          : Colors.white10,
                      child: IconButton(
                        icon: Icon(
                          Icons.check_circle_rounded,
                          color: _capturedImages.isNotEmpty
                              ? Colors.white
                              : Colors.white60,
                          size: 28.r,
                        ),
                        onPressed: _capturedImages.isNotEmpty
                            ? () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => MasterPdfEditorPage(
                                      initialImagePaths: _capturedImages,
                                    ),
                                  ),
                                );
                              }
                            : null,
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
}
