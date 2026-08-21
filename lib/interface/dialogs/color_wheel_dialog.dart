/*
 * PDF Hawk - Modern PDF Reader, Writer, Editor & Scanner
 * Copyright (C) 2026 Van Stan / Novaturients
 *
 * This software is licensed under the PolyForm Noncommercial License 1.0.0.
 * You may obtain a copy of the License at https://polyformproject.org/licenses/noncommercial/1.0.0
 */

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdfhawk/data/res/theme.dart';

class ColorWheelDialog extends StatefulWidget {
  final Color initialColor;

  const ColorWheelDialog({super.key, required this.initialColor});

  static Future<Color?> show(BuildContext context, {required Color initialColor}) {
    return showDialog<Color>(
      context: context,
      builder: (ctx) => ColorWheelDialog(initialColor: initialColor),
    );
  }

  @override
  State<ColorWheelDialog> createState() => _ColorWheelDialogState();
}

class _ColorWheelDialogState extends State<ColorWheelDialog> {
  late double _hue; // 0.0 to 360.0
  late double _saturation; // 0.0 to 1.0
  late double _value; // 0.0 to 1.0
  late double _alpha; // 0.0 to 1.0

  static const List<Color> _presets = [
    Color(0xFF2E65F3), // Royal Blue
    Color(0xFFE53935), // Red
    Color(0xFFFF9800), // Orange
    Color(0xFFFFEB3B), // Yellow
    Color(0xFF4CAF50), // Green
    Color(0xFF00BCD4), // Cyan
    Color(0xFF9C27B0), // Purple
    Color(0xFFE91E63), // Pink
    Color(0xFFFFFFFF), // White
    Color(0xFF000000), // Black
  ];

  @override
  void initState() {
    super.initState();
    final hsv = HSVColor.fromColor(widget.initialColor);
    _hue = hsv.hue;
    _saturation = hsv.saturation;
    _value = hsv.value;
    _alpha = hsv.alpha;
  }

  Color get _currentColor {
    return HSVColor.fromAHSV(_alpha, _hue, _saturation, _value).toColor();
  }

  void _onWheelPan(Offset localPos, double radius) {
    final center = Offset(radius, radius);
    final dx = localPos.dx - center.dx;
    final dy = localPos.dy - center.dy;
    final distance = sqrt(dx * dx + dy * dy);

    double newSat = (distance / radius).clamp(0.0, 1.0);
    double rad = atan2(dy, dx);
    double deg = (rad * 180 / pi);
    if (deg < 0) deg += 360;

    setState(() {
      _hue = deg;
      _saturation = newSat;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentColor = _currentColor;
    const wheelSize = 170.0;
    const wheelRadius = wheelSize / 2;

    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      titlePadding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 8.h),
      contentPadding: EdgeInsets.symmetric(horizontal: 20.w),
      actionsPadding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 14.h),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Color Palette",
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          Container(
            width: 32.r,
            height: 32.r,
            decoration: BoxDecoration(
              color: currentColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: currentColor.withValues(alpha: 0.4),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Gap(8),
            // Color Wheel Canvas
            Center(
              child: GestureDetector(
                onPanStart: (details) => _onWheelPan(details.localPosition, wheelRadius),
                onPanUpdate: (details) => _onWheelPan(details.localPosition, wheelRadius),
                onTapDown: (details) => _onWheelPan(details.localPosition, wheelRadius),
                child: SizedBox(
                  width: wheelSize,
                  height: wheelSize,
                  child: CustomPaint(
                    size: const Size(wheelSize, wheelSize),
                    painter: _ColorWheelPainter(
                      hue: _hue,
                      saturation: _saturation,
                      brightness: _value,
                    ),
                  ),
                ),
              ),
            ),
            Gap(14),

            // Brightness Slider
            Row(
              children: [
                Icon(Icons.wb_sunny_rounded, size: 16.r, color: Colors.white70),
                Gap(8),
                Expanded(
                  child: SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 3.5,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      activeTrackColor: royalblue,
                      inactiveTrackColor: Colors.white24,
                      thumbColor: Colors.white,
                    ),
                    child: Slider(
                      value: _value,
                      min: 0.0,
                      max: 1.0,
                      onChanged: (val) => setState(() => _value = val),
                    ),
                  ),
                ),
                SizedBox(
                  width: 32.w,
                  child: Text(
                    "${(_value * 100).round()}%",
                    textAlign: TextAlign.end,
                    style: TextStyle(color: Colors.white70, fontSize: 10.sp),
                  ),
                ),
              ],
            ),

            // Opacity Slider
            Row(
              children: [
                Icon(Icons.opacity_rounded, size: 16.r, color: Colors.white70),
                Gap(8),
                Expanded(
                  child: SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 3.5,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      activeTrackColor: royalblue,
                      inactiveTrackColor: Colors.white24,
                      thumbColor: Colors.white,
                    ),
                    child: Slider(
                      value: _alpha,
                      min: 0.05,
                      max: 1.0,
                      onChanged: (val) => setState(() => _alpha = val),
                    ),
                  ),
                ),
                SizedBox(
                  width: 32.w,
                  child: Text(
                    "${(_alpha * 100).round()}%",
                    textAlign: TextAlign.end,
                    style: TextStyle(color: Colors.white70, fontSize: 10.sp),
                  ),
                ),
              ],
            ),
            Gap(8),

            // Preset Swatches Row
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: _presets.map((color) {
                final isSel = (color.toARGB32() == currentColor.toARGB32());
                return GestureDetector(
                  onTap: () {
                    final hsv = HSVColor.fromColor(color);
                    setState(() {
                      _hue = hsv.hue;
                      _saturation = hsv.saturation;
                      _value = hsv.value;
                      _alpha = 1.0;
                    });
                  },
                  child: Container(
                    width: 24.r,
                    height: 24.r,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSel ? royalblue : Colors.white24,
                        width: isSel ? 2.5 : 1.0,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            Gap(6),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            "Cancel",
            style: TextStyle(color: Colors.white60, fontSize: 13.sp),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: royalblue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
          ),
          onPressed: () => Navigator.pop(context, currentColor),
          child: const Text("Select"),
        ),
      ],
    );
  }
}

class _ColorWheelPainter extends CustomPainter {
  final double hue;
  final double saturation;
  final double brightness;

  _ColorWheelPainter({
    required this.hue,
    required this.saturation,
    required this.brightness,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;

    // 1. Sweep gradient for hue spectrum
    final sweepGradient = SweepGradient(
      colors: const [
        Color(0xFFFF0000), // Red
        Color(0xFFFFFF00), // Yellow
        Color(0xFF00FF00), // Green
        Color(0xFF00FFFF), // Cyan
        Color(0xFF0000FF), // Blue
        Color(0xFFFF00FF), // Magenta
        Color(0xFFFF0000), // Red
      ],
    );

    final wheelPaint = Paint()
      ..shader = sweepGradient.createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, wheelPaint);

    // 2. Radial gradient for saturation (white center to transparent rim)
    final radialGradient = RadialGradient(
      colors: [
        HSVColor.fromAHSV(1.0, 0, 0, brightness).toColor(),
        Colors.transparent,
      ],
    );

    final satPaint = Paint()
      ..shader = radialGradient.createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, satPaint);

    // 3. Dark overlay for brightness reduction
    if (brightness < 1.0) {
      final darkPaint = Paint()
        ..color = Colors.black.withValues(alpha: 1.0 - brightness)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, radius, darkPaint);
    }

    // 4. Draw pointer thumb circle
    final rad = hue * pi / 180;
    final thumbDist = saturation * radius;
    final thumbPos = Offset(
      center.dx + thumbDist * cos(rad),
      center.dy + thumbDist * sin(rad),
    );

    final thumbGlow = Paint()
      ..color = Colors.black45
      ..style = PaintingStyle.fill;
    canvas.drawCircle(thumbPos, 9, thumbGlow);

    final thumbPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(thumbPos, 7.5, thumbPaint);
  }

  @override
  bool shouldRepaint(covariant _ColorWheelPainter oldDelegate) {
    return oldDelegate.hue != hue ||
        oldDelegate.saturation != saturation ||
        oldDelegate.brightness != brightness;
  }
}
