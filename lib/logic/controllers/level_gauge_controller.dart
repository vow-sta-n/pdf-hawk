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

class LevelGaugeController {
  StreamController<double>? _stream;
  Stream<double> get angleStream => _stream?.stream ?? const Stream.empty();

  StreamSubscription? _accel;

  double _lastRaw = 0;
  double _smoothAngle = 0;

  /// lower = smoother • higher = more responsive
  final double _alpha = 0.08; // 0.05 = very smooth | 0.15 = faster

  void start() {
    stop();
    _stream = StreamController<double>.broadcast();
    _accel = accelerometerEventStream().listen(
      (event) {
        final ax = event.x;
        final ay = event.y;

        // Correct horizon angle = atan2(-ax, ay)
        double raw = atan2(-ax, ay) * 180 / pi; // degrees

        // Unwrap (prevent sudden 180° jumps)
        raw = _unwrapAngle(_lastRaw, raw);
        _lastRaw = raw;

        // Heavy smoothing
        _smoothAngle = _smoothAngle + _alpha * (raw - _smoothAngle);

        if (_stream != null && !_stream!.isClosed) {
          _stream!.add(_smoothAngle);
        }
      },
      onError: (error) {
        // Ignore sensor errors gracefully
      },
    );
  }

  void stop() {
    _accel?.cancel();
    _accel = null;
    if (_stream != null && !_stream!.isClosed) {
      _stream!.close();
    }
    _stream = null;
  }

  /// Prevent jumps across -180 <-> +180
  double _unwrapAngle(double prev, double next) {
    double diff = next - prev;

    if (diff > 180) next -= 360;
    if (diff < -180) next += 360;

    return next;
  }
}
