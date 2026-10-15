import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

enum TiltZone { uncalibrated, neutral, downCorrect, upPass, invalidOrientation }

class SensorService {
  StreamSubscription<AccelerometerEvent>? _subscription;

  double _gx = 0.0;
  double _gy = 0.0;
  double _gz = 0.0;
  bool _initialized = false;
  static const double _alpha = 0.80;

  TiltZone _zone = TiltZone.uncalibrated;
  int _downFrames = 0;
  int _upFrames = 0;
  DateTime _lastTrigger = DateTime.fromMillisecondsSinceEpoch(0);

  // Thresholds in degrees
  static const double _downThreshold = -42.0; // Screen faces floor -> CORRECT
  static const double _upThreshold = 42.0;    // Screen faces ceiling -> PASS
  static const double _neutralLimit = 20.0;   // Must return within [-20°, +20°]
  static const int _dwellFrames = 3;          // ~60ms intentional hold
  static const Duration _cooldown = Duration(milliseconds: 700);

  bool invertTilt = false;
  double currentPitch = 0.0;
  TiltZone get currentZone => _zone;

  void Function(double pitch, TiltZone zone)? onTelemetry;

  SensorService({this.invertTilt = false});

  void startListening({
    required VoidCallback onCorrect,
    required VoidCallback onPass,
    void Function(double pitch, TiltZone zone)? onTelemetry,
  }) {
    this.onTelemetry = onTelemetry;
    stopListening();
    _initialized = false;
    _zone = TiltZone.uncalibrated;
    _downFrames = 0;
    _upFrames = 0;

    _subscription = accelerometerEventStream(
      samplingPeriod: SensorInterval.gameInterval,
    ).listen((AccelerometerEvent event) {
      if (!_initialized) {
        _gx = event.x;
        _gy = event.y;
        _gz = event.z;
        _initialized = true;
      } else {
        _gx = _alpha * _gx + (1.0 - _alpha) * event.x;
        _gy = _alpha * _gy + (1.0 - _alpha) * event.y;
        _gz = _alpha * _gz + (1.0 - _alpha) * event.z;
      }

      // 1. Lateral Left/Right Tilt Lockout:
      // In landscape mode, Y-axis is horizontal (ear-to-ear).
      // If |_gy| > 4.5 m/s², the phone is tilted left/right or held in portrait.
      if (_gy.abs() > 4.5) {
        _downFrames = 0;
        _upFrames = 0;
        _zone = TiltZone.invalidOrientation;
        onTelemetry?.call(currentPitch, _zone);
        return; // Do nothing on left/right tilt
      }

      // 2. Compute pitch angle in the X-Z nod plane
      final double xMag = _gx.abs();
      final double zVal = invertTilt ? -_gz : _gz;
      final double pitch = math.atan2(zVal, xMag) * (180.0 / math.pi);
      currentPitch = pitch;

      final now = DateTime.now();

      // 3. Neutral Reset Gate: phone must be returned upright on forehead
      if (pitch.abs() <= _neutralLimit && xMag >= 5.0) {
        _zone = TiltZone.neutral;
        _downFrames = 0;
        _upFrames = 0;
      }
      // 4. Trigger Gate: only fire if armed in neutral zone and past cooldown
      else if (_zone == TiltZone.neutral &&
          now.difference(_lastTrigger) >= _cooldown) {
        if (pitch <= _downThreshold) {
          _downFrames++;
          _upFrames = 0;
          if (_downFrames >= _dwellFrames) {
            _zone = TiltZone.downCorrect;
            _downFrames = 0;
            _lastTrigger = now;
            onCorrect();
          }
        } else if (pitch >= _upThreshold) {
          _upFrames++;
          _downFrames = 0;
          if (_upFrames >= _dwellFrames) {
            _zone = TiltZone.upPass;
            _upFrames = 0;
            _lastTrigger = now;
            onPass();
          }
        } else {
          _downFrames = 0;
          _upFrames = 0;
        }
      }

      onTelemetry?.call(currentPitch, _zone);
    });
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }

  void dispose() {
    stopListening();
  }
}
