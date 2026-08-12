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
