/*
 * PDF Hawk - Modern PDF Reader, Writer, Editor & Scanner
 * Copyright (C) 2026 Van Stan / Novaturients
 *
 * This software is licensed under the PolyForm Noncommercial License 1.0.0.
 * You may obtain a copy of the License at https://polyformproject.org/licenses/noncommercial/1.0.0
 */

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

/// Defines an individual step/target in a tutorial coach mark tour.
class TutorialStep {
  final GlobalKey? keyTarget;
  final TargetPosition? targetPosition;
  final String? identify;
  final String title;
  final String description;
  final IconData icon;
  final ShapeLightFocus shape;
  final double? radius;
  final ContentAlign align;
  final String? customStepLabel;

  TutorialStep({
    this.keyTarget,
    this.targetPosition,
    this.identify,
    required this.title,
    required this.description,
    required this.icon,
    this.shape = ShapeLightFocus.RRect,
    this.radius,
    this.align = ContentAlign.bottom,
    this.customStepLabel,
  });
}

/// Global helper function to launch interactive tutorial tours across the app.
void showAppTutorial({
  required BuildContext context,
  required List<TutorialStep> steps,
  VoidCallback? onFinish,
  VoidCallback? onSkip,
  double opacityShadow = 0.88,
  int pulseAnimationDurationMs = 600,
}) {
  final validSteps = steps
      .where((s) =>
          s.targetPosition != null || (s.keyTarget?.currentContext != null))
      .toList();
  if (validSteps.isEmpty) return;

  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  final highlightBorder = BorderSide(
    color: theme.colorScheme.primary,
    width: 2.5,
  );

  final totalSteps = validSteps.length;
  final targets = <TargetFocus>[];

  for (int i = 0; i < totalSteps; i++) {
    final step = validSteps[i];
    final stepNumber = i + 1;
    final isLast = stepNumber == totalSteps;
    final stepLabel =
        step.customStepLabel ?? "Step $stepNumber of $totalSteps";

    targets.add(
      TargetFocus(
        identify: step.identify ?? "step_$stepNumber",
        keyTarget: step.keyTarget,
        targetPosition: step.targetPosition,
        shape: step.shape,
        radius:
            step.radius ?? (step.shape == ShapeLightFocus.RRect ? 14.r : null),
        borderSide: highlightBorder,
        contents: [
          TargetContent(
            align: step.align,
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            builder: (context, controller) => TutorialCardWidget(
              step: stepLabel,
              title: step.title,
              description: step.description,
              icon: step.icon,
              controller: controller,
              isDark: isDark,
              theme: theme,
              isLast: isLast,
            ),
          ),
        ],
      ),
    );
  }

  TutorialCoachMark(
    targets: targets,
    colorShadow: isDark ? const Color(0xFF000000) : Colors.black,
    opacityShadow: isDark ? opacityShadow : 0.80,
    hideSkip: true,
    paddingFocus: 8,
    pulseEnable: true,
    pulseAnimationDuration: Duration(milliseconds: pulseAnimationDurationMs),
    onFinish: onFinish,
    onSkip: () {
      onSkip?.call();
      return true;
    },
  ).show(context: context);
}

class TutorialCardWidget extends StatelessWidget {
  final String step;
  final String title;
  final String description;
  final IconData icon;
  final TutorialCoachMarkController controller;
  final bool isDark;
  final ThemeData? theme;
  final bool isLast;

  const TutorialCardWidget({
    super.key,
    required this.step,
    required this.title,
    required this.description,
    required this.icon,
    required this.controller,
    required this.isDark,
    this.theme,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTheme = theme ?? Theme.of(context);
    final primaryColor = effectiveTheme.colorScheme.primary;

    return Container(
      padding: EdgeInsets.all(18.r),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.25),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: isDark
              ? primaryColor.withValues(alpha: 0.35)
              : Colors.black12,
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 22.sp,
                  color: primaryColor,
                ),
              ),
              Gap(10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.toUpperCase(),
                      style: GoogleFonts.instrumentSans(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: primaryColor,
                      ),
                    ),
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 17.sp,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Gap(12.h),
          Text(
            description,
            style: GoogleFonts.instrumentSans(
              fontSize: 13.sp,
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
              height: 1.4,
            ),
          ),
          Gap(16.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () => controller.skip(),
                child: Text(
                  "SKIP",
                  style: GoogleFonts.outfit(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => isLast ? controller.skip() : controller.next(),
                iconAlignment: IconAlignment.end,
                icon: Icon(
                  isLast ? Icons.check_rounded : Icons.arrow_forward_rounded,
                  size: 16.sp,
                  color: Colors.white,
                ),
                label: Text(
                  isLast ? "GOT IT" : "NEXT",
                  style: GoogleFonts.outfit(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 8.h,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
