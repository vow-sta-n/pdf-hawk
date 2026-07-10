import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class ScanEditPage extends StatefulWidget {
  final String imagePath;
  final Function(String newPath) onSave;

  const ScanEditPage({
    super.key,
    required this.imagePath,
    required this.onSave,
  });

  @override
  State<ScanEditPage> createState() => _ScanEditPageState();
}

class _ScanEditPageState extends State<ScanEditPage> {
  late String _currentImagePath;
  bool _isGrayscale = false;
  double _contrast = 0.0; // scale from -50 to 50
  int _rotationAngle = 0; // 0, 90, 180, 270
  bool _isProcessing = false;

  // Normalized crop bounds: 0.0 to 1.0
  double _cropLeft = 0.05;
  double _cropTop = 0.05;
  double _cropRight = 0.95;
  double _cropBottom = 0.95;

  @override
  void initState() {
    super.initState();
    _currentImagePath = widget.imagePath;
  }

  Future<void> _applyEditsAndSave() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      // 1. Load original image bytes
      final bytes = await File(widget.imagePath).readAsBytes();
      img.Image? decoded = img.decodeImage(bytes);

      if (decoded == null) {
        throw Exception("Failed to decode image");
      }

      // 2. Perform cropping
      if (_cropLeft > 0.01 || _cropTop > 0.01 || _cropRight < 0.99 || _cropBottom < 0.99) {
        final x = (decoded.width * _cropLeft).round();
        final y = (decoded.height * _cropTop).round();
        final w = (decoded.width * (_cropRight - _cropLeft)).round();
        final h = (decoded.height * (_cropBottom - _cropTop)).round();
        
        final cropped = img.copyCrop(decoded, x: x, y: y, width: w, height: h);
        decoded = cropped;
      }

      // 3. Perform rotation
      if (_rotationAngle != 0) {
        decoded = img.copyRotate(decoded, angle: _rotationAngle);
      }

      // 4. Adjust contrast
      if (_contrast != 0.0) {
        // img.contrast takes a value where 100.0 is baseline, values > 100 increase contrast
        // mapping our slider (-50 to 50) to (50 to 150)
        final contrastVal = 100.0 + _contrast;
        decoded = img.contrast(decoded, contrast: contrastVal);
      }

      // 5. Apply grayscale
      if (_isGrayscale) {
        decoded = img.grayscale(decoded);
      }

      // 6. Encode image to JPG
      final encoded = img.encodeJpg(decoded);

      // 7. Save to a temporary file
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
        "${tempDir.path}/scanned_edit_${DateTime.now().millisecondsSinceEpoch}.jpg",
      );
      await tempFile.writeAsBytes(encoded);

      widget.onSave(tempFile.path);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to save edits: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.grey.shade900,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          "Edit Scanned Page",
          style: GoogleFonts.outfit(color: Colors.white, fontSize: 18.sp),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
            onPressed: _isProcessing ? null : _applyEditsAndSave,
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Main Image editing Canvas with Crop handles overlay
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(24.r),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Stack(
                        children: [
                          // Base image rotated using Transform.rotate (for visual preview)
                          Center(
                            child: ColorFiltered(
                              colorFilter: _isGrayscale
                                  ? const ColorFilter.matrix(<double>[
                                      0.2126, 0.7152, 0.0722, 0, 0,
                                      0.2126, 0.7152, 0.0722, 0, 0,
                                      0.2126, 0.7152, 0.0722, 0, 0,
                                      0,      0,      0,      1, 0,
                                    ])
                                  : const ColorFilter.mode(
                                      Colors.transparent,
                                      BlendMode.dst,
                                    ),
                              child: Transform.rotate(
                                angle: _rotationAngle * (3.1415926535 / 180),
                                child: Image.file(
                                  File(_currentImagePath),
                                  fit: BoxFit.contain,
                                  width: constraints.maxWidth,
                                  height: constraints.maxHeight,
                                ),
                              ),
                            ),
                          ),

                          // Draggable Crop Area Overlay
                          _buildCropOverlay(constraints),
                        ],
                      );
                    },
                  ),
                ),
              ),

              // Bottom control sheet
              Container(
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0D0D0D) : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24.r),
                    topRight: Radius.circular(24.r),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Contrast Slider control row
                    Row(
                      children: [
                        Icon(
                          Icons.contrast_rounded,
                          size: 20.r,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                        SizedBox(width: 12.w),
                        Text(
                          "Contrast",
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black87,
                            fontSize: 14.sp,
                          ),
                        ),
                        Expanded(
                          child: Slider(
                            value: _contrast,
                            min: -50.0,
                            max: 50.0,
                            activeColor: theme.colorScheme.primary,
                            onChanged: (val) {
                              setState(() {
                                _contrast = val;
                              });
                            },
                          ),
                        ),
                        Text(
                          "${_contrast.round()}",
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black87,
                            fontSize: 12.sp,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 12.h),

                    // Grayscale filter toggle + rotation rows
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // B&W Filter toggle button
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _isGrayscale = !_isGrayscale;
                            });
                          },
                          icon: Icon(
                            _isGrayscale ? Icons.filter_b_and_w : Icons.filter_b_and_w_outlined,
                            color: _isGrayscale ? theme.colorScheme.primary : Colors.grey,
                          ),
                          label: Text(
                            "Black & White",
                            style: TextStyle(
                              color: _isGrayscale ? theme.colorScheme.primary : Colors.grey,
                              fontSize: 13.sp,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: _isGrayscale ? theme.colorScheme.primary : Colors.grey.shade400,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                          ),
                        ),

                        // Rotate 90 button
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _rotationAngle = (_rotationAngle + 90) % 360;
                            });
                          },
                          icon: const Icon(Icons.rotate_right_rounded, color: Colors.grey),
                          label: const Text(
                            "Rotate 90°",
                            style: TextStyle(color: Colors.grey),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.grey.shade400),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Loading overlay
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCropOverlay(BoxConstraints constraints) {
    final width = constraints.maxWidth;
    final height = constraints.maxHeight;

    // Convert normalized margins to double coordinates
    final l = _cropLeft * width;
    final t = _cropTop * height;
    final r = _cropRight * width;
    final b = _cropBottom * height;

    const handleRadius = 14.0;

    return Stack(
      children: [
        // Custom Painter to darken outside cropped area and draw crop rectangle grid
        Positioned.fill(
          child: CustomPaint(
            painter: CropOverlayPainter(
              cropRect: Rect.fromLTRB(l, t, r, b),
            ),
          ),
        ),

        // Top Left Handle
        Positioned(
          left: l - handleRadius,
          top: t - handleRadius,
          child: GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                final newLeft = (l + details.delta.dx) / width;
                final newTop = (t + details.delta.dy) / height;

                if (newLeft > 0.0 && newLeft < _cropRight - 0.1) {
                  _cropLeft = newLeft;
                }
                if (newTop > 0.0 && newTop < _cropBottom - 0.1) {
                  _cropTop = newTop;
                }
              });
            },
            child: _buildHandleCircle(),
          ),
        ),

        // Top Right Handle
        Positioned(
          left: r - handleRadius,
          top: t - handleRadius,
          child: GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                final newRight = (r + details.delta.dx) / width;
                final newTop = (t + details.delta.dy) / height;

                if (newRight < 1.0 && newRight > _cropLeft + 0.1) {
                  _cropRight = newRight;
                }
                if (newTop > 0.0 && newTop < _cropBottom - 0.1) {
                  _cropTop = newTop;
                }
              });
            },
            child: _buildHandleCircle(),
          ),
        ),

        // Bottom Left Handle
        Positioned(
          left: l - handleRadius,
          top: b - handleRadius,
          child: GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                final newLeft = (l + details.delta.dx) / width;
                final newBottom = (b + details.delta.dy) / height;

                if (newLeft > 0.0 && newLeft < _cropRight - 0.1) {
                  _cropLeft = newLeft;
                }
                if (newBottom < 1.0 && newBottom > _cropTop + 0.1) {
                  _cropBottom = newBottom;
                }
              });
            },
            child: _buildHandleCircle(),
          ),
        ),

        // Bottom Right Handle
        Positioned(
          left: r - handleRadius,
          top: b - handleRadius,
          child: GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                final newRight = (r + details.delta.dx) / width;
                final newBottom = (b + details.delta.dy) / height;

                if (newRight < 1.0 && newRight > _cropLeft + 0.1) {
                  _cropRight = newRight;
                }
                if (newBottom < 1.0 && newBottom > _cropTop + 0.1) {
                  _cropBottom = newBottom;
                }
              });
            },
            child: _buildHandleCircle(),
          ),
        ),
      ],
    );
  }

  Widget _buildHandleCircle() {
    return Container(
      width: 28.r,
      height: 28.r,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 10.r,
          height: 10.r,
          decoration: const BoxDecoration(
            color: Colors.red,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class CropOverlayPainter extends CustomPainter {
  final Rect cropRect;

  CropOverlayPainter({required this.cropRect});

  @override
  void paint(Canvas canvas, Size size) {
    final paintDim = Paint()
      ..color = Colors.black.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;

    // Darken areas outside the crop rectangle
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()..addRect(cropRect),
      ),
      paintDim,
    );

    // Draw Crop rectangle border
    final paintBorder = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawRect(cropRect, paintBorder);

    // Draw Grid guidelines (3x3 grid lines inside crop area)
    final paintGrid = Paint()
      ..color = Colors.white24
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    final wThird = cropRect.width / 3;
    final hThird = cropRect.height / 3;

    // Vertical grid lines
    canvas.drawLine(
      Offset(cropRect.left + wThird, cropRect.top),
      Offset(cropRect.left + wThird, cropRect.bottom),
      paintGrid,
    );
    canvas.drawLine(
      Offset(cropRect.left + wThird * 2, cropRect.top),
      Offset(cropRect.left + wThird * 2, cropRect.bottom),
      paintGrid,
    );

    // Horizontal grid lines
    canvas.drawLine(
      Offset(cropRect.left, cropRect.top + hThird),
      Offset(cropRect.right, cropRect.top + hThird),
      paintGrid,
    );
    canvas.drawLine(
      Offset(cropRect.left, cropRect.top + hThird * 2),
      Offset(cropRect.right, cropRect.top + hThird * 2),
      paintGrid,
    );
  }

  @override
  bool shouldRepaint(covariant CropOverlayPainter oldDelegate) {
    return oldDelegate.cropRect != cropRect;
  }
}
