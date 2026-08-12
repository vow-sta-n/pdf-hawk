/*
 * PDF Hawk - Modern PDF Reader, Writer, Editor & Scanner
 * Copyright (C) 2026 Van Stan / Novaturients
 *
 * This software is licensed under the PolyForm Noncommercial License 1.0.0.
 * You may obtain a copy of the License at https://polyformproject.org/licenses/noncommercial/1.0.0
 */

import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';

class StabilizationController {
  final _stream = StreamController<double>.broadcast();
  Stream<double> get stabilityStream => _stream.stream;

  StreamSubscription? _gyro;
  double _smooth = 0;
  final double _alpha = 0.1; // smoothing factor

  void start() {
    _gyro = gyroscopeEventStream().listen((event) {
      // event.x, event.y, event.z → rotational velocity (rad/s)
      double magnitude = sqrt(
        event.x * event.x +
        event.y * event.y +
        event.z * event.z,
      );

      // Smooth motion value for stability indicator
      _smooth = (_alpha * magnitude) + ((1 - _alpha) * _smooth);

      _stream.add(_smooth);
    });
  }

  void stop() {
    _gyro?.cancel();
    _stream.close();
  }
}