import 'package:flutter/material.dart';
import 'package:pdfhawk/interface/painters/clock_painter.dart';
import 'dart:math';

import 'package:pdfhawk/res/constants.dart';
import 'package:pdfhawk/res/theme.dart';

class UnifiedLevelStabilizer extends StatelessWidget {
  final Stream<double> angleStream; // from LevelGaugeController
  final Stream<double> stabilityStream; // from StabilizationController
  final bool level;
  final bool stablize;
  const UnifiedLevelStabilizer({
    super.key,
    required this.angleStream,
    required this.stabilityStream,
    required this.level,
    required this.stablize,
  });

  @override
  Widget build(BuildContext context) {
    final w = getWidth(context);

    return StreamBuilder<double>(
      stream: angleStream,
      builder: (context, angleSnap) {
        final angle = (angleSnap.data ?? 0);
        return StreamBuilder<double>(
          stream: stabilityStream,
          builder: (context, stabSnap) {
            final motion = stabSnap.data ?? 0;
            // Stabilization indicator color logic
            Color dotColor = kprimary;
            if (motion > 1.0) {
              dotColor = red;
            } else if (motion > 0.5) {
              dotColor = coral;
            } else if (motion > 0.1) {
              dotColor = kprimary;
            }
            return SizedBox(
              height: 200,
              width: w,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer circle
                  Visibility(
                    visible: level,
                    child: SizedBox(
                      width: 200,
                      height: 200,
                      child: CustomPaint(
                        painter: CircleDialPainter(
                          circleColor: Colors.white,
                          tickColor: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  //level
                  Visibility(
                    visible: level,
                    child: Container(
                      width: 140,
                      height: .5,
                      decoration: BoxDecoration(
                        color: white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  // Rotating Horizon Line (cut inside the circle)
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: angle),
                    duration: const Duration(
                      milliseconds: 120,
                    ), // smooth transition
                    curve: Curves.easeOut,
                    builder: (_, animatedAngle, child) {
                      return Transform.rotate(
                        angle: animatedAngle * pi / 180,
                        child: child,
                      );
                    },
                    child: Container(
                      width: 140,
                      height: 2,
                      decoration: BoxDecoration(
                        color: kprimary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  Visibility(
                    visible: level,
                    child: RotatedBox(
                      quarterTurns: 1,
                      child: Container(
                        width: 140, // slightly shorter
                        height: .5,
                        decoration: BoxDecoration(
                          color: white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  // Inner circle (for cleaner visuals)
                  Visibility(
                    visible: stablize,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: white),
                      ),
                    ),
                  ),
                  // Stabilization Dot
                  Visibility(
                    visible: stablize,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: dotColor,
                        boxShadow: [
                          BoxShadow(
                            color: dotColor.withAlpha(127),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
