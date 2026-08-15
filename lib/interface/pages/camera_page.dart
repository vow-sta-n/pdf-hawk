/*
 * PDF Hawk - Modern PDF Reader, Writer, Editor & Scanner
 * Copyright (C) 2026 Van Stan / Novaturients
 *
 * This software is licensed under the PolyForm Noncommercial License 1.0.0.
 * You may obtain a copy of the License at https://polyformproject.org/licenses/noncommercial/1.0.0
 */

import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:camera/camera.dart';
import 'package:pdfhawk/interface/widgets/level_gauge_widget.dart';
import 'package:pdfhawk/data/res/constants.dart';
import 'package:pdfhawk/data/res/theme.dart';
import 'package:pdfhawk/interface/pages/master_pdf_editor_page.dart';

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
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _shutterProgressController.dispose();
    _scanAnimationController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _controller;

    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _onNewCameraSelected(cameraController.description);
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
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } on CameraException catch (e) {
      _showSnackBar("Camera error: ${e.description}");
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
                  decoration: BoxDecoration(
                    color: Colors.black,
                    // borderRadius: BorderRadius.circular(24.r),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _isCameraInitialized && _controller != null
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            CameraPreview(_controller!),

                            // Camera Corner Framing Guides with Live Scanning Shimmer
                            IgnorePointer(
                              child: Container(
                                margin: const EdgeInsets.all(40),
                                width: double.infinity,
                                height: double.infinity,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    // Live scanning shimmer beam during active capture
                                    if (_isTakingPicture)
                                      AnimatedBuilder(
                                        animation: _scanAnimationController,
                                        builder: (context, child) {
                                          return CustomPaint(
                                            painter: _ScannerShimmerPainter(
                                              progress: _scanAnimationController
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
                                      painter: _CameraCornerPainter(
                                        color: Color.fromARGB(
                                          95,
                                          255,
                                          255,
                                          255,
                                        ),
                                        cornerLength: 32.0,
                                        strokeWidth: 1.5,
                                        cornerRadius: 2.0,
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
                              angleStream: levelGaugeController.angleStream,
                              stabilityStream:
                                  stabilizationController.stabilityStream,
                            ),

                            if (_capturedImages.isNotEmpty) ...[
                              Positioned(
                                bottom: 0,
                                child: SizedBox(
                                  width: w,

                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      InkWell(
                                        onTap: () => setState(
                                          () => showImages = !showImages,
                                        ),
                                        child: Container(
                                          width: 100,
                                          decoration: BoxDecoration(
                                            color: black,
                                            borderRadius: BorderRadius.only(
                                              topLeft: Radius.circular(8.r),
                                              topRight: Radius.circular(8.r),
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
                                        duration: Duration(milliseconds: 100),
                                        curve: Curves.easeIn,
                                        padding: EdgeInsets.only(top: 10.h),
                                        color: black,
                                        child: ListView.builder(
                                          scrollDirection: Axis.horizontal,
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 16.w,
                                          ),
                                          itemCount: _capturedImages.length,
                                          itemBuilder: (context, index) {
                                            final path = _capturedImages[index];
                                            return GestureDetector(
                                              onTap: () => _showPreviewDialog(
                                                path,
                                                index,
                                              ),
                                              onLongPress: () =>
                                                  _confirmDeleteImage(index),
                                              child: Container(
                                                width: 50.w,
                                                margin: EdgeInsets.only(
                                                  right: 12.w,
                                                ),
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        4.r,
                                                      ),
                                                  border: Border.all(
                                                    color: Colors.white70,
                                                    width: 1.5,
                                                  ),
                                                  image: DecorationImage(
                                                    image: FileImage(
                                                      File(path),
                                                    ),
                                                    fit: BoxFit.cover,
                                                  ),
                                                ),
                                                child: Align(
                                                  alignment: Alignment.topRight,
                                                  child: Container(
                                                    margin: EdgeInsets.all(4.r),
                                                    padding: EdgeInsets.all(
                                                      2.r,
                                                    ),
                                                    decoration:
                                                        const BoxDecoration(
                                                          color: Colors.black54,
                                                          shape:
                                                              BoxShape.circle,
                                                        ),
                                                    child: Text(
                                                      "${index + 1}",
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 10.sp,
                                                        fontWeight:
                                                            FontWeight.bold,
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
                        )
                      : const Center(
                          child: CircularProgressIndicator(color: royalblue),
                        ),
                ),
              ),
              // Capture Shutter Rows
              Padding(
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
                              painter: _ShutterProgressPainter(
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

/// Custom painter to draw clean corner framing guides for the camera viewfinder
class _CameraCornerPainter extends CustomPainter {
  final Color color;
  final double cornerLength;
  final double strokeWidth;
  final double cornerRadius;

  const _CameraCornerPainter({
    this.color = Colors.white70,
    this.cornerLength = 32.0,
    this.strokeWidth = 2.5,
    this.cornerRadius = 10.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final double effectiveLength = (cornerLength > size.width / 3)
        ? size.width / 3
        : cornerLength;
    final double effectiveRadius = (cornerRadius > effectiveLength / 2)
        ? effectiveLength / 2
        : cornerRadius;

    final path = Path();

    // Top-Left corner
    if (effectiveRadius > 0) {
      path.moveTo(0, effectiveLength);
      path.lineTo(0, effectiveRadius);
      path.arcToPoint(
        Offset(effectiveRadius, 0),
        radius: Radius.circular(effectiveRadius),
      );
      path.lineTo(effectiveLength, 0);
    } else {
      path.moveTo(0, effectiveLength);
      path.lineTo(0, 0);
      path.lineTo(effectiveLength, 0);
    }

    // Top-Right corner
    if (effectiveRadius > 0) {
      path.moveTo(size.width - effectiveLength, 0);
      path.lineTo(size.width - effectiveRadius, 0);
      path.arcToPoint(
        Offset(size.width, effectiveRadius),
        radius: Radius.circular(effectiveRadius),
      );
      path.lineTo(size.width, effectiveLength);
    } else {
      path.moveTo(size.width - effectiveLength, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, effectiveLength);
    }

    // Bottom-Left corner
    if (effectiveRadius > 0) {
      path.moveTo(0, size.height - effectiveLength);
      path.lineTo(0, size.height - effectiveRadius);
      path.arcToPoint(
        Offset(effectiveRadius, size.height),
        radius: Radius.circular(effectiveRadius),
        clockwise: false,
      );
      path.lineTo(effectiveLength, size.height);
    } else {
      path.moveTo(0, size.height - effectiveLength);
      path.lineTo(0, size.height);
      path.lineTo(effectiveLength, size.height);
    }

    // Bottom-Right corner
    if (effectiveRadius > 0) {
      path.moveTo(size.width - effectiveLength, size.height);
      path.lineTo(size.width - effectiveRadius, size.height);
      path.arcToPoint(
        Offset(size.width, size.height - effectiveRadius),
        radius: Radius.circular(effectiveRadius),
        clockwise: false,
      );
      path.lineTo(size.width, size.height - effectiveLength);
    } else {
      path.moveTo(size.width - effectiveLength, size.height);
      path.lineTo(size.width, size.height);
      path.lineTo(size.width, size.height - effectiveLength);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CameraCornerPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.cornerLength != cornerLength ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.cornerRadius != cornerRadius;
  }
}

/// Custom painter to draw the circular shutter button with a radial progress overlay
class _ShutterProgressPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Color baseColor;
  final Color progressColor;

  const _ShutterProgressPainter({
    required this.progress,
    this.strokeWidth = 4.0,
    this.baseColor = Colors.white,
    this.progressColor = royalblue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    if (radius <= 0) return;

    // 1. Base ring
    final basePaint = Paint()
      ..color = baseColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, radius, basePaint);

    // 2. Overlay progress arc starting at 90 degrees (pi/2) going clockwise
    if (progress > 0) {
      final progressPaint = Paint()
        ..color = progressColor
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      const double startAngle = pi / 2; // 90 degree angle (bottom)
      final double sweepAngle = 2 * pi * progress.clamp(0.0, 1.0);

      final rect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawArc(rect, startAngle, sweepAngle, false, progressPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ShutterProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.baseColor != baseColor ||
        oldDelegate.progressColor != progressColor;
  }
}

/// Custom painter to draw a futuristic live scanning shimmer beam across the viewfinder
class _ScannerShimmerPainter extends CustomPainter {
  final double progress;
  final Color glowColor;
  final double cornerRadius;

  const _ScannerShimmerPainter({
    required this.progress,
    this.glowColor = royalblue,
    this.cornerRadius = 2.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final scanY = size.height * progress.clamp(0.0, 1.0);
    const double trailHeight = 70.0;

    canvas.save();
    // Clip within the document bounding box
    canvas.clipRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(cornerRadius),
      ),
    );

    // 1. Ambient scanning tint across document area
    final ambientPaint = Paint()
      ..color = glowColor.withValues(alpha: 0.03)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), ambientPaint);

    // 2. Trailing gradient beam
    final double trailTop = (scanY - trailHeight).clamp(0.0, size.height);
    final double trailBottom = (scanY + 8.0).clamp(0.0, size.height);
    if (trailBottom > trailTop) {
      final trailRect = Rect.fromLTRB(0, trailTop, size.width, trailBottom);
      final trailPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            glowColor.withValues(alpha: 0.0),
            glowColor.withValues(alpha: 0.08),
            glowColor.withValues(alpha: 0.22),
          ],
        ).createShader(trailRect);

      canvas.drawRect(trailRect, trailPaint);
    }

    // 3. Glowing outer laser scan line
    final outerGlowPaint = Paint()
      ..color = glowColor.withValues(alpha: 0.5)
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);

    canvas.drawLine(
      Offset(0, scanY),
      Offset(size.width, scanY),
      outerGlowPaint,
    );

    // 4. Bright gradient core scan line with fading edges
    final coreLinePaint = Paint()
      ..shader = LinearGradient(
        colors: [
          glowColor.withValues(alpha: 0.0),
          glowColor.withValues(alpha: 0.8),
          Colors.white,
          glowColor.withValues(alpha: 0.8),
          glowColor.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.15, 0.5, 0.85, 1.0],
      ).createShader(Rect.fromLTWH(0, scanY, size.width, 2.0))
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(0, scanY), Offset(size.width, scanY), coreLinePaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ScannerShimmerPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.glowColor != glowColor ||
        oldDelegate.cornerRadius != cornerRadius;
  }
}
