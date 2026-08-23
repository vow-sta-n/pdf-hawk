/*
 * PDF Hawk - Modern PDF Reader, Writer, Editor & Scanner
 * Copyright (C) 2026 Van Stan / Novaturients
 *
 * This software is licensed under the PolyForm Noncommercial License 1.0.0.
 * You may obtain a copy of the License at https://polyformproject.org/licenses/noncommercial/1.0.0
 */

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';

class ColorWheelDialog extends StatefulWidget {
  final Color initialColor;
  final ValueChanged<Color> onColorSelected;

  const ColorWheelDialog({
    super.key,
    required this.initialColor,
    required this.onColorSelected,
  });

  static Future<Color?> show(BuildContext context, {required Color initialColor}) {
    return showDialog<Color>(
      context: context,
      barrierDismissible: true,
      builder: (context) => ColorWheelDialog(
        initialColor: initialColor,
        onColorSelected: (color) {},
      ),
    );
  }

  @override
  State<ColorWheelDialog> createState() => _ColorWheelDialogState();
}

class _ColorWheelDialogState extends State<ColorWheelDialog> {
  late double _hue; // 0..360
  late double _saturation; // 0.25..1.0 (restricted from white/gray)
  late double _value; // 0.35..0.95 (restricted from black/near-white)

  @override
  void initState() {
    super.initState();
    final hsv = HSVColor.fromColor(widget.initialColor);
    _hue = hsv.hue;
    // Clamp saturation & value so custom color cannot be black, white, or shade of gray
    _saturation = hsv.saturation.clamp(0.25, 1.0);
    _value = hsv.value.clamp(0.35, 0.95);
  }

  Color get _currentColor {
    return HSVColor.fromAHSV(1.0, _hue, _saturation, _value).toColor();
  }

  void _onPanUpdate(Offset localPosition, double size) {
    final center = Offset(size / 2, size / 2);
    final dx = localPosition.dx - center.dx;
    final dy = localPosition.dy - center.dy;
    final distance = math.sqrt(dx * dx + dy * dy);
    final maxRadius = size / 2;

    // Calculate Hue in degrees (0..360)
    var angle = math.atan2(dy, dx) * 180 / math.pi;
    if (angle < 0) angle += 360;

    // Calculate Saturation (0.25..1.0 to prevent pure white/gray)
    final rawSat = (distance / maxRadius).clamp(0.0, 1.0);
    final sat = 0.25 + (rawSat * 0.75);

    setState(() {
      _hue = angle;
      _saturation = sat;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final wheelSize = 220.r;
    final selectedColor = _currentColor;
    final hexCode = '#${selectedColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E1E24) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
      insetPadding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
      child: Padding(
        padding: EdgeInsets.all(20.r),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Custom Primary Color",
                  style: GoogleFonts.outfit(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: selectedColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(
                      color: selectedColor.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    hexCode,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      color: selectedColor,
                    ),
                  ),
                ),
              ],
            ),
            Gap(16.h),

            // Color Wheel Container
            GestureDetector(
              onPanStart: (details) => _onPanUpdate(details.localPosition, wheelSize),
              onPanUpdate: (details) => _onPanUpdate(details.localPosition, wheelSize),
              onTapDown: (details) => _onPanUpdate(details.localPosition, wheelSize),
              child: SizedBox(
                width: wheelSize,
                height: wheelSize,
                child: CustomPaint(
                  painter: _ColorWheelPainter(
                    hue: _hue,
                    saturation: _saturation,
                    value: _value,
                  ),
                ),
              ),
            ),
            Gap(16.h),

            // Brightness / Tone Slider (Constrained to avoid pitch black / washed white)
            Row(
              children: [
                Icon(
                  Icons.brightness_medium_rounded,
                  size: 20.sp,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
                Gap(8.w),
                Expanded(
                  child: SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: selectedColor,
                      inactiveTrackColor: isDark ? Colors.white24 : Colors.black12,
                      thumbColor: selectedColor,
                      overlayColor: selectedColor.withValues(alpha: 0.2),
                      trackHeight: 6.h,
                    ),
                    child: Slider(
                      value: _value,
                      min: 0.35, // Disallow near-black
                      max: 0.95, // Disallow washed-out white
                      onChanged: (val) {
                        setState(() {
                          _value = val;
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
            Gap(8.h),

            // Current Preview Chip
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 32.r,
                  height: 32.r,
                  decoration: BoxDecoration(
                    color: selectedColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: selectedColor.withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                ),
                Gap(10.w),
                Text(
                  "Vibrant & Accessible Tone",
                  style: GoogleFonts.instrumentSans(
                    fontSize: 12.5.sp,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            Gap(20.h),

            // Dialog Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? Colors.white70 : Colors.black87,
                      side: BorderSide(
                        color: isDark ? Colors.white24 : Colors.black12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                    ),
                    child: Text(
                      "Cancel",
                      style: GoogleFonts.instrumentSans(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                Gap(12.w),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, selectedColor),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: selectedColor,
                      foregroundColor: ThemeData.estimateBrightnessForColor(selectedColor) == Brightness.dark
                          ? Colors.white
                          : Colors.black87,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                    ),
                    child: Text(
                      "Set Primary",
                      style: GoogleFonts.instrumentSans(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorWheelPainter extends CustomPainter {
  final double hue;
  final double saturation;
  final double value;

  _ColorWheelPainter({
    required this.hue,
    required this.saturation,
    required this.value,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final sweepGradient = SweepGradient(
      colors: const [
        Color(0xFFFF0000), // Red
        Color(0xFFFFFF00), // Yellow
        Color(0xFF00FF00), // Green
        Color(0xFF00FFFF), // Cyan
        Color(0xFF0000FF), // Blue
        Color(0xFFFF00FF), // Magenta
        Color(0xFFFF0000), // Red wrap
      ],
      stops: const [0.0, 0.166, 0.333, 0.5, 0.666, 0.833, 1.0],
    );

    final radialGradient = RadialGradient(
      colors: [
        Colors.white,
        Colors.white.withValues(alpha: 0.0),
      ],
      stops: const [0.0, 1.0],
    );

    final sweepPaint = Paint()
      ..shader = sweepGradient.createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, sweepPaint);

    final radialPaint = Paint()
      ..shader = radialGradient.createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, radialPaint);

    // Overlay darkness if value < 1.0
    if (value < 1.0) {
      final darkPaint = Paint()
        ..color = Colors.black.withValues(alpha: (1.0 - value) * 0.7)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, radius, darkPaint);
    }

    // Outer border
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(center, radius, borderPaint);

    // Indicator position based on hue & saturation
    final rad = hue * math.pi / 180;
    // Map saturation (0.25..1.0) back to visual radius (0..radius)
    final visualDist = ((saturation - 0.25) / 0.75).clamp(0.0, 1.0) * (radius - 12);
    final indicatorX = center.dx + visualDist * math.cos(rad);
    final indicatorY = center.dy + visualDist * math.sin(rad);

    final indicatorCenter = Offset(indicatorX, indicatorY);
    final currentColor = HSVColor.fromAHSV(1.0, hue, saturation, value).toColor();

    // Draw Indicator
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(indicatorCenter, 11, shadowPaint);

    final outerRing = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(indicatorCenter, 10, outerRing);

    final innerFill = Paint()
      ..color = currentColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(indicatorCenter, 8.5, innerFill);
  }

  @override
  bool shouldRepaint(covariant _ColorWheelPainter oldDelegate) {
    return oldDelegate.hue != hue ||
        oldDelegate.saturation != saturation ||
        oldDelegate.value != value;
  }
}
