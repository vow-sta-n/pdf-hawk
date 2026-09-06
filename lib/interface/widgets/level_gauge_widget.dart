/*
 * PDF Hawk - Modern PDF Reader, Writer, Editor & Scanner
 * Copyright (C) 2026 Van Stan / Novaturients
 *
 * This software is licensed under the PolyForm Noncommercial License 1.0.0.
 * You may obtain a copy of the License at https://polyformproject.org/licenses/noncommercial/1.0.0
 */

import 'package:flutter/material.dart';
import 'package:pdfhawk/interface/painters/clock_painter.dart';
import 'dart:math';

import 'package:pdfhawk/data/res/constants.dart';
import 'package:pdfhawk/data/res/theme.dart';

class UnifiedLevelStabilizer extends StatelessWidget {
  final Stream<double> angleStream; // from LevelGaugeController
  final Stream<double> stabilityStream; // from StabilizationController
  final bool level;
  final bool stablize;
  final Color? primaryColor;
  const UnifiedLevelStabilizer({
    super.key,
    required this.angleStream,
    required this.stabilityStream,
    required this.level,
    required this.stablize,
    this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final w = getWidth(context);
    final effectivePrimary = primaryColor ?? kprimary;

    return StreamBuilder<double>(
      stream: angleStream,
      builder: (context, angleSnap) {
        final angle = (angleSnap.data ?? 0);
        return StreamBuilder<double>(
          stream: stabilityStream,
          initialData: 0.0,
          builder: (context, stabSnap) {
            final motion = stabSnap.data ?? 0;
            // Stabilization indicator color logic:
            // - Stable (still): Green
            // - Moderate motion: Yellow
            // - Shaky / Rapid motion: Red
            Color dotColor;
            if (motion > 0.6) {
              dotColor = red;
            } else if (motion > 0.2) {
              dotColor = yellow;
            } else {
              dotColor = green;
            }
            return IgnorePointer(
              ignoring: true,
              child: SizedBox(
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
                          borderRadius: allradius(4),
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
                          color: effectivePrimary,
                          borderRadius: allradius(4),
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
                            borderRadius: allradius(4),
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
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
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
              ),
            );
          },
        );
      },
    );
  }
}
