import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';

class LevelGaugeController {
  final _stream = StreamController<double>.broadcast();
  Stream<double> get angleStream => _stream.stream;

  StreamSubscription? _accel;

  double _lastRaw = 0;
  double _smoothAngle = 0;

  /// lower = smoother • higher = more responsive
  final double _alpha = 0.08; // 0.05 = very smooth | 0.15 = faster

  void start() {
    _accel = accelerometerEventStream().listen((event) {
      final ax = event.x;
      final ay = event.y;

      //----------------------------------------------------------------------
      // FIX 1: correct horizon angle = atan2(-ax, ay)
      //       (this keeps horizon horizontal in portrait and landscape)
      //----------------------------------------------------------------------
      double raw = atan2(-ax, ay) * 180 / pi; // degrees

      //----------------------------------------------------------------------
      // FIX 2: unwrap (prevent sudden 180° jumps)
      //----------------------------------------------------------------------
      raw = _unwrapAngle(_lastRaw, raw);
      _lastRaw = raw;

      //----------------------------------------------------------------------
      // FIX 3: heavy smoothing (super stable)
      //----------------------------------------------------------------------
      _smoothAngle = _smoothAngle + _alpha * (raw - _smoothAngle);

      _stream.add(_smoothAngle);
    });
  }

  void stop() {
    _accel?.cancel();
    _stream.close();
  }

  /// Prevent jumps across -180 <-> +180
  double _unwrapAngle(double prev, double next) {
    double diff = next - prev;

    if (diff > 180) next -= 360;
    if (diff < -180) next += 360;

    return next;
  }
}
