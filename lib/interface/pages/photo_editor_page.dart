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
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:pdfhawk/data/res/enum.dart';
import 'package:pdfhawk/interface/painters/crop_overlay_painter.dart';

class PhotoEditorPage extends StatefulWidget {
  final String imagePath;
  final Function(String newPath) onSave;

  const PhotoEditorPage({
    super.key,
    required this.imagePath,
    required this.onSave,
  });

  @override
  State<PhotoEditorPage> createState() => _PhotoEditorPageState();
}

class _PhotoEditorPageState extends State<PhotoEditorPage> {
  late String _currentImagePath;
  bool _isProcessing = false;
  int _activeTab = 0; // 0: Filters, 1: Adjustments, 2: Crop & Rotate

  // Filter Selection
  PhotoFilter _selectedFilter = PhotoFilter.none;

  // Image Adjustments (-50.0 to 50.0)
  double _brightness = 0.0;
  double _contrast = 0.0;
  double _saturation = 0.0;

  // Rotation & Flip
  int _rotationAngle = 0; // 0, 90, 180, 270
  bool _flipHorizontal = false;
  bool _flipVertical = false;

  // Crop Controls (Normalized 0.0 to 1.0)
  bool _isCropActive = true;
  double _cropLeft = 0.05;
  double _cropTop = 0.05;
  double _cropRight = 0.95;
  double _cropBottom = 0.95;
  String _selectedAspectRatio = 'Free';

  @override
  void initState() {
    super.initState();
    _currentImagePath = widget.imagePath;
  }

  void _resetAdjustments() {
    setState(() {
      _brightness = 0.0;
      _contrast = 0.0;
      _saturation = 0.0;
    });
  }

  void _resetCrop() {
    setState(() {
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

  Future<void> _applyEditsAndSave() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final bytes = await File(widget.imagePath).readAsBytes();
      img.Image? decoded = img.decodeImage(bytes);

      if (decoded == null) {
        throw Exception("Failed to decode photo");
      }

      // 1. Perform Crop
      if (_cropLeft > 0.01 ||
          _cropTop > 0.01 ||
          _cropRight < 0.99 ||
          _cropBottom < 0.99) {
        final x = (decoded.width * _cropLeft).round();
        final y = (decoded.height * _cropTop).round();
        final w = (decoded.width * (_cropRight - _cropLeft)).round();
        final h = (decoded.height * (_cropBottom - _cropTop)).round();
        if (w > 10 && h > 10) {
          decoded = img.copyCrop(
            decoded,
            x: x.clamp(0, decoded.width - 1),
            y: y.clamp(0, decoded.height - 1),
            width: w.clamp(1, decoded.width - x),
            height: h.clamp(1, decoded.height - y),
          );
        }
      }

      // 2. Perform Rotation
      if (_rotationAngle != 0) {
        decoded = img.copyRotate(decoded, angle: _rotationAngle);
      }

      // 3. Perform Flips
      if (_flipHorizontal) {
        decoded = img.flipHorizontal(decoded);
      }
      if (_flipVertical) {
        decoded = img.flipVertical(decoded);
      }

      // 4. Perform Adjustments (Contrast / Saturation / Brightness)
      if (_contrast != 0.0) {
        final contrastVal = 100.0 + _contrast;
        decoded = img.contrast(decoded, contrast: contrastVal);
      }
      if (_saturation != 0.0 || _brightness != 0.0) {
        final satVal = 1.0 + (_saturation / 50.0);
        final amountVal = _brightness / 50.0;
        decoded = img.adjustColor(
          decoded,
          saturation: satVal,
          amount: amountVal,
        );
      }

      // 5. Perform Filters
      switch (_selectedFilter) {
        case PhotoFilter.grayscale:
          decoded = img.grayscale(decoded);
          break;
        case PhotoFilter.magicScan:
          decoded = img.grayscale(decoded);
          decoded = img.contrast(decoded, contrast: 160.0);
          break;
        case PhotoFilter.sepia:
          decoded = img.sepia(decoded);
          break;
        case PhotoFilter.invert:
          decoded = img.invert(decoded);
          break;
        case PhotoFilter.vivid:
          decoded = img.contrast(decoded, contrast: 125.0);
          decoded = img.adjustColor(decoded, saturation: 1.3);
          break;
        case PhotoFilter.vintage:
          decoded = img.sepia(decoded, amount: 0.5);
          decoded = img.contrast(decoded, contrast: 110.0);
          break;
        case PhotoFilter.none:
          break;
      }

      // 6. Encode image to JPG & Save
      final encoded = img.encodeJpg(decoded, quality: 92);
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
        "${tempDir.path}/photo_edit_${DateTime.now().millisecondsSinceEpoch}.jpg",
      );
      await tempFile.writeAsBytes(encoded);

      widget.onSave(tempFile.path);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to apply photo edits: $e")),
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

  // --- FILTER COLOR MATRICES FOR LIVE PREVIEW ---
  ColorFilter _getFilterColorFilter() {
    switch (_selectedFilter) {
      case PhotoFilter.grayscale:
        return const ColorFilter.matrix(<double>[
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]);
      case PhotoFilter.magicScan:
        return const ColorFilter.matrix(<double>[
          0.6,
          0.6,
          0.6,
          0,
          -40,
          0.6,
          0.6,
          0.6,
          0,
          -40,
          0.6,
          0.6,
          0.6,
          0,
          -40,
          0,
          0,
          0,
          1,
          0,
        ]);
      case PhotoFilter.sepia:
        return const ColorFilter.matrix(<double>[
          0.393,
          0.769,
          0.189,
          0,
          0,
          0.349,
          0.686,
          0.168,
          0,
          0,
          0.272,
          0.534,
          0.131,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]);
      case PhotoFilter.invert:
        return const ColorFilter.matrix(<double>[
          -1,
          0,
          0,
          0,
          255,
          0,
          -1,
          0,
          0,
          255,
          0,
          0,
          -1,
          0,
          255,
          0,
          0,
          0,
          1,
          0,
        ]);
      case PhotoFilter.vivid:
        return const ColorFilter.matrix(<double>[
          1.2,
          0,
          0,
          0,
          0,
          0,
          1.1,
          0,
          0,
          0,
          0,
          0,
          1.3,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]);
      case PhotoFilter.vintage:
        return const ColorFilter.matrix(<double>[
          1.1,
          0.1,
          0,
          0,
          10,
          0,
          1.0,
          0,
          0,
          5,
          0,
          0,
          0.8,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]);
      case PhotoFilter.none:
        return const ColorFilter.mode(Colors.transparent, BlendMode.dst);
    }
  }

  ColorFilter _getAdjustmentColorFilter() {
    final b = _brightness * 2.55; // convert -50..50 to -127..127
    final c = 1.0 + (_contrast / 50.0); // convert -50..50 to 0.0..2.0
    final s = 1.0 + (_saturation / 50.0); // saturation multiplier

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFF141414),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          "Photo Editor",
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: "Reset All",
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: () {
              setState(() {
                _selectedFilter = PhotoFilter.none;
                _brightness = 0.0;
                _contrast = 0.0;
                _saturation = 0.0;
                _rotationAngle = 0;
                _flipHorizontal = false;
                _flipVertical = false;
                _resetCrop();
              });
            },
          ),
          IconButton(
            tooltip: "Save & Apply",
            icon: const Icon(
              Icons.check_circle_rounded,
              color: Colors.tealAccent,
              size: 28,
            ),
            onPressed: _isProcessing ? null : _applyEditsAndSave,
          ),
          SizedBox(width: 8.w),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Main Image Editing View Canvas
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(16.r),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Stack(
                        children: [
                          Center(
                            child: ColorFiltered(
                              colorFilter: _getFilterColorFilter(),
                              child: ColorFiltered(
                                colorFilter: _getAdjustmentColorFilter(),
                                child: Transform(
                                  alignment: Alignment.center,
                                  transform: Matrix4.identity()
                                    ..rotateZ(_rotationAngle * (pi / 180))
                                    // ignore: deprecated_member_use
                                    ..scale(
                                      _flipHorizontal ? -1.0 : 1.0,
                                      _flipVertical ? -1.0 : 1.0,
                                    ),
                                  child: Image.file(
                                    File(_currentImagePath),
                                    fit: BoxFit.contain,
                                    width: constraints.maxWidth,
                                    height: constraints.maxHeight,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Draggable Crop Area Overlay
                          if (_isCropActive) _buildCropOverlay(constraints),
                        ],
                      );
                    },
                  ),
                ),
              ),

              // Bottom Control Panel
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(24.r),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 16,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Tab Selector Navigation Bar
                    Padding(
                      padding: EdgeInsets.only(top: 12.h, bottom: 8.h),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildTabButton(
                            0,
                            "Filters",
                            Icons.auto_awesome_rounded,
                          ),
                          _buildTabButton(1, "Adjust", Icons.tune_rounded),
                          _buildTabButton(
                            2,
                            "Crop & Rotate",
                            Icons.crop_rotate_rounded,
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Colors.white12),

                    // Active Tab Panel Content
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _buildActiveTabContent(theme, isDark),
                    ),
                    SizedBox(height: 16.h),
                  ],
                ),
              ),
            ],
          ),

          // Loading Spinner Overlay
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.tealAccent),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, String label, IconData icon) {
    final isSelected = _activeTab == index;
    final color = isSelected ? Colors.tealAccent : Colors.grey;

    return InkWell(
      onTap: () {
        setState(() {
          _activeTab = index;
        });
      },
      borderRadius: BorderRadius.circular(12.r),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22.r),
            SizedBox(height: 4.h),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12.sp,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTabContent(ThemeData theme, bool isDark) {
    switch (_activeTab) {
      case 0:
        return _buildFiltersTab(isDark);
      case 1:
        return _buildAdjustmentsTab(theme, isDark);
      case 2:
        return _buildCropRotateTab(theme, isDark);
      default:
        return const SizedBox.shrink();
    }
  }

  // --- TAB 1: FILTERS ---
  Widget _buildFiltersTab(bool isDark) {
    final filters = [
      {'filter': PhotoFilter.none, 'name': 'Original'},
      {'filter': PhotoFilter.magicScan, 'name': 'Magic Scan'},
      {'filter': PhotoFilter.grayscale, 'name': 'B&W'},
      {'filter': PhotoFilter.sepia, 'name': 'Sepia'},
      {'filter': PhotoFilter.vivid, 'name': 'Vivid'},
      {'filter': PhotoFilter.vintage, 'name': 'Vintage'},
      {'filter': PhotoFilter.invert, 'name': 'Invert'},
    ];

    return Container(
      height: 100.h,
      padding: EdgeInsets.symmetric(vertical: 12.h),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final item = filters[index];
          final filter = item['filter'] as PhotoFilter;
          final name = item['name'] as String;
          final isSel = _selectedFilter == filter;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedFilter = filter;
              });
            },
            child: Container(
              margin: EdgeInsets.only(right: 12.w),
              padding: EdgeInsets.all(8.r),
              decoration: BoxDecoration(
                color: isSel
                    ? Colors.teal.withValues(alpha: 0.2)
                    : (isDark ? Colors.white10 : Colors.grey.shade100),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: isSel ? Colors.tealAccent : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    filter == PhotoFilter.magicScan
                        ? Icons.document_scanner_rounded
                        : Icons.photo_filter_rounded,
                    color: isSel ? Colors.tealAccent : Colors.white70,
                    size: 24.r,
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    name,
                    style: TextStyle(
                      color: isSel ? Colors.tealAccent : Colors.white70,
                      fontSize: 11.sp,
                      fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // --- TAB 2: ADJUSTMENTS ---
  Widget _buildAdjustmentsTab(ThemeData theme, bool isDark) {
    final textColor = isDark ? Colors.white70 : Colors.black87;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
      child: Column(
        children: [
          _buildSliderRow(
            "Brightness",
            Icons.wb_sunny_rounded,
            _brightness,
            textColor,
            (val) => setState(() => _brightness = val),
          ),
          _buildSliderRow(
            "Contrast",
            Icons.contrast_rounded,
            _contrast,
            textColor,
            (val) => setState(() => _contrast = val),
          ),
          _buildSliderRow(
            "Saturation",
            Icons.color_lens_rounded,
            _saturation,
            textColor,
            (val) => setState(() => _saturation = val),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _resetAdjustments,
              icon: const Icon(Icons.undo_rounded, size: 16),
              label: const Text("Reset Sliders"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliderRow(
    String label,
    IconData icon,
    double value,
    Color textColor,
    ValueChanged<double> onChanged,
  ) {
    return Row(
      children: [
        Icon(icon, size: 18.r, color: textColor),
        SizedBox(width: 8.w),
        SizedBox(
          width: 80.w,
          child: Text(
            label,
            style: TextStyle(color: textColor, fontSize: 13.sp),
          ),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: -50.0,
            max: 50.0,
            activeColor: Colors.tealAccent,
            inactiveColor: Colors.white24,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 32.w,
          child: Text(
            "${value.round()}",
            textAlign: TextAlign.end,
            style: TextStyle(color: textColor, fontSize: 12.sp),
          ),
        ),
      ],
    );
  }

  // --- TAB 3: CROP & ROTATE ---
  Widget _buildCropRotateTab(ThemeData theme, bool isDark) {
    final aspectRatios = ['Free', '1:1', '4:3', '16:9', 'A4'];

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Column(
        children: [
          // Action Buttons: Rotate 90, Flip H, Flip V, Crop Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                tooltip: "Rotate 90°",
                icon: const Icon(
                  Icons.rotate_right_rounded,
                  color: Colors.white,
                ),
                onPressed: () {
                  setState(() {
                    _rotationAngle = (_rotationAngle + 90) % 360;
                  });
                },
              ),
              IconButton(
                tooltip: "Flip Horizontal",
                icon: Icon(
                  Icons.flip_rounded,
                  color: _flipHorizontal ? Colors.tealAccent : Colors.white,
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
                  color: _flipVertical ? Colors.tealAccent : Colors.white,
                ),
                onPressed: () {
                  setState(() {
                    _flipVertical = !_flipVertical;
                  });
                },
              ),
              IconButton(
                tooltip: _isCropActive ? "Hide Crop Box" : "Show Crop Box",
                icon: Icon(
                  Icons.crop_rounded,
                  color: _isCropActive ? Colors.tealAccent : Colors.white54,
                ),
                onPressed: () {
                  setState(() {
                    _isCropActive = !_isCropActive;
                  });
                },
              ),
              IconButton(
                tooltip: "Reset Crop",
                icon: const Icon(
                  Icons.restart_alt_rounded,
                  color: Colors.white,
                ),
                onPressed: _resetCrop,
              ),
            ],
          ),
          SizedBox(height: 8.h),

          // Aspect Ratio Choice Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: aspectRatios.map((ratio) {
                final isSel = _selectedAspectRatio == ratio;
                return Padding(
                  padding: EdgeInsets.only(right: 8.w),
                  child: ChoiceChip(
                    label: Text(ratio),
                    selected: isSel,
                    selectedColor: Colors.tealAccent,
                    labelStyle: TextStyle(
                      color: isSel ? Colors.black : Colors.white,
                      fontSize: 12.sp,
                      fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (_) => _applyAspectRatio(ratio),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
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

    const handleRadius = 14.0;

    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: CropOverlayPainter(cropRect: Rect.fromLTRB(l, t, r, b)),
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
          BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Center(
        child: Container(
          width: 10.r,
          height: 10.r,
          decoration: const BoxDecoration(
            color: Colors.teal,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
