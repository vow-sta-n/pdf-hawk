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
  StreamController<double>? _stream;
  Stream<double> get stabilityStream => _stream?.stream ?? const Stream.empty();

  StreamSubscription? _gyro;
  StreamSubscription? _accel;
  double _smooth = 0;
  final double _alpha = 0.25; // responsive smoothing factor

  double _lastAx = 0;
  double _lastAy = 0;
  double _lastAz = 0;
  bool _hasInitialAccel = false;

  void start() {
    stop();
    _stream = StreamController<double>.broadcast();
    _smooth = 0;
    _hasInitialAccel = false;

    // 1. Gyroscope stream (rotational velocity in rad/s)
    try {
      _gyro = gyroscopeEventStream().listen(
        (event) {
          final magnitude = sqrt(
            event.x * event.x +
            event.y * event.y +
            event.z * event.z,
          );
          _addMotionSample(magnitude);
        },
        onError: (_) {},
      );
    } catch (_) {}

    // 2. Accelerometer stream (fallback & linear/tilt motion)
    try {
      _accel = accelerometerEventStream().listen(
        (event) {
          if (!_hasInitialAccel) {
            _lastAx = event.x;
            _lastAy = event.y;
            _lastAz = event.z;
            _hasInitialAccel = true;
            return;
          }

          final dx = event.x - _lastAx;
          final dy = event.y - _lastAy;
          final dz = event.z - _lastAz;
          _lastAx = event.x;
          _lastAy = event.y;
          _lastAz = event.z;

          // Normalized acceleration delta
          final delta = sqrt(dx * dx + dy * dy + dz * dz) * 0.35;
          _addMotionSample(delta);
        },
        onError: (_) {},
      );
    } catch (_) {}
  }

  void _addMotionSample(double magnitude) {
    _smooth = (_alpha * magnitude) + ((1 - _alpha) * _smooth);
    if (_stream != null && !_stream!.isClosed) {
      _stream!.add(_smooth);
    }
  }

  void stop() {
    _gyro?.cancel();
    _gyro = null;
    _accel?.cancel();
    _accel = null;
    if (_stream != null && !_stream!.isClosed) {
      _stream!.close();
    }
    _stream = null;
  }
}