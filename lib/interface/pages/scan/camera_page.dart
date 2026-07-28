import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:camera/camera.dart';
import 'package:pdfhawk/interface/pages/Scan/scan_rearrange_page.dart';
import 'package:pdfhawk/interface/widgets/level_gauge_widget.dart';
import 'package:pdfhawk/res/constants.dart';
import 'package:pdfhawk/res/theme.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  final List<String> _capturedImages = [];
  FlashMode _flashMode = FlashMode.off;
  int _selectedCameraIndex = 0;
  bool _isTakingPicture = false;
  bool showImages = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
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

    try {
      final file = await _controller!.takePicture();
      setState(() {
        _capturedImages.add(file.path);
      });
      _showSnackBar("Captured successfully!");
    } on CameraException catch (e) {
      _showSnackBar("Error taking picture: ${e.description}");
    } finally {
      setState(() {
        _isTakingPicture = false;
      });
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
      SnackBar(content: Text(text), duration: const Duration(seconds: 1)),
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
    return Scaffold(
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

                          // Perfect Square/Rectangle Guide Grid lines
                          Container(
                            height: double.infinity,
                            margin: EdgeInsets.all(40),
                            child: Column(
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: Colors.white60,
                                              width: 0.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: Colors.white60,
                                              width: 0.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: Colors.white60,
                                              width: 0.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: Colors.white60,
                                              width: 0.5,
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
                          //level
                          UnifiedLevelStabilizer(
                            level: true,
                            stablize: true,
                            angleStream: levelGaugeController.angleStream,
                            stabilityStream:
                                stabilizationController.stabilityStream,
                          ),
                          // Active capture state
                          if (_isTakingPicture)
                            Container(
                              color: Colors.black45,
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          if (_capturedImages.isNotEmpty) ...[
                            Positioned(
                              bottom: 0,
                              child: SizedBox(
                                width: w,

                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
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
                                            onTap: () =>
                                                _showPreviewDialog(path, index),
                                            onLongPress: () =>
                                                _confirmDeleteImage(index),
                                            child: Container(
                                              width: 50.w,
                                              margin: EdgeInsets.only(
                                                right: 12.w,
                                              ),
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(4.r),
                                                border: Border.all(
                                                  color: Colors.white70,
                                                  width: 1.5,
                                                ),
                                                image: DecorationImage(
                                                  image: FileImage(File(path)),
                                                  fit: BoxFit.cover,
                                                ),
                                              ),
                                              child: Align(
                                                alignment: Alignment.topRight,
                                                child: Container(
                                                  margin: EdgeInsets.all(4.r),
                                                  padding: EdgeInsets.all(2.r),
                                                  decoration:
                                                      const BoxDecoration(
                                                        color: Colors.black54,
                                                        shape: BoxShape.circle,
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
                        child: CircularProgressIndicator(color: Colors.white),
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

                  // Shutter button
                  GestureDetector(
                    onTap: _takePicture,
                    child: Container(
                      width: 72.r,
                      height: 72.r,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4.r),
                      ),
                      child: Container(
                        margin: EdgeInsets.all(4.r),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),

                  // Finish / Check circle button
                  CircleAvatar(
                    radius: 26.r,
                    backgroundColor: _capturedImages.isNotEmpty
                        ? Colors.green
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
                                  builder: (context) => ScanRearrangePage(
                                    imagePaths: _capturedImages,
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
    );
  }
}
