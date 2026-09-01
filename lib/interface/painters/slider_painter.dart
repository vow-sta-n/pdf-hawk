import 'package:flutter/material.dart';
import 'package:pdfhawk/data/res/theme.dart';

class CenteredSliderTrackShape extends SliderTrackShape
    with BaseSliderTrackShape {
  final Color positiveColor;
  final Color negativeColor;
  final Color inactiveColor;

  const CenteredSliderTrackShape({
    this.positiveColor = yellow,
    this.negativeColor = Colors.amberAccent,
    this.inactiveColor = const Color(0x33FFFFFF),
  });

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 0,
  }) {
    if (sliderTheme.trackHeight == null || sliderTheme.trackHeight! <= 0) {
      return;
    }

    final Rect trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );

    final double trackHeight = sliderTheme.trackHeight!;
    final double centerTrackX = trackRect.left + (trackRect.width / 2);
    final double thumbX = thumbCenter.dx;

    final Paint inactivePaint = Paint()
      ..color = inactiveColor
      ..style = PaintingStyle.fill;

    // 1. Draw inactive background track for the entire width
    final RRect backgroundRRect = RRect.fromRectAndRadius(
      trackRect,
      Radius.circular(trackHeight / 2),
    );
    context.canvas.drawRRect(backgroundRRect, inactivePaint);

    // 2. Draw active track segment from center (0) to thumb if value != 0
    if ((thumbX - centerTrackX).abs() > 1.0) {
      final bool isPositive = thumbX > centerTrackX;
      final Color activeColor = isPositive ? positiveColor : negativeColor;

      final double activeLeft = isPositive ? centerTrackX : thumbX;
      final double activeRight = isPositive ? thumbX : centerTrackX;

      final Rect activeRect = Rect.fromLTRB(
        activeLeft,
        trackRect.top - (additionalActiveTrackHeight / 2),
        activeRight,
        trackRect.bottom + (additionalActiveTrackHeight / 2),
      );

      final Paint activePaint = Paint()
        ..color = activeColor
        ..style = PaintingStyle.fill;

      context.canvas.drawRRect(
        RRect.fromRectAndRadius(activeRect, Radius.circular(trackHeight / 2)),
        activePaint,
      );
    }

    // 3. Subtle center tick indicator (at 0)
    final Paint centerTickPaint = Paint()
      ..color = Colors.white54
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    context.canvas.drawLine(
      Offset(centerTrackX, trackRect.top - 2.5),
      Offset(centerTrackX, trackRect.bottom + 2.5),
      centerTickPaint,
    );
  }
}
