/*
 * PDF Hawk - Modern PDF Reader, Writer, Editor & Scanner
 * Copyright (C) 2026 Van Stan / Novaturients
 *
 * This software is licensed under the PolyForm Noncommercial License 1.0.0.
 * You may obtain a copy of the License at https://polyformproject.org/licenses/noncommercial/1.0.0
 */

import 'package:flutter/material.dart';
import 'package:pdfhawk/logic/controllers/level_gauge_controller.dart';
import 'package:pdfhawk/logic/controllers/stabilization_controller.dart';

class MyBehaviour extends ScrollBehavior {
  @override
  Widget buildOverscrollIndicator(context, child, details) => child;
}

BorderRadius allradius(double r) => BorderRadius.circular(r);

double getHeight(BuildContext context) => MediaQuery.of(context).size.height;

double getWidth(BuildContext context) => MediaQuery.of(context).size.width;

final previewKey = GlobalKey();

final levelGaugeController = LevelGaugeController();

final stabilizationController = StabilizationController();
