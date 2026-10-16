import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

enum TiltZone { uncalibrated, neutral, downCorrect, upPass, invalidOrientation }

class SensorService {
  StreamSubscription<AccelerometerEvent>? _subscription;

  // Low-pass filtered accelerometer values.
  double _gx = 0.0;
  double _gy = 0.0;
  double _gz = 0.0;
  bool _initialized = false;

  // Weight given to the PREVIOUS filtered value. 0.35 means each new sample
  // contributes 65%, so fast head nods register almost immediately.
  static const double _alpha = 0.35;

  TiltZone _zone = TiltZone.uncalibrated;
  int _downFrames = 0;
  int _upFrames = 0;
  int _neutralFrames = 0;
  DateTime _lastTrigger = DateTime.fromMillisecondsSinceEpoch(0);

  // ── 90-Degree Upright Coordinate System ────────────────────────────────────
  // 0°   = Screen flat, facing the floor
  // 90°  = Phone upright on the forehead (landscape, screen facing outward)
  // 180° = Screen flat, facing the ceiling
  //
  // Neutral (safe) zone: 90° ± 22°
  static const double _neutralMinAngle = 68.0;
  static const double _neutralMaxAngle = 112.0;

  // Deliberate 35° tilt from upright required to trigger:
  static const double _downCorrectThreshold = 55.0; // angle <= 55°  -> CORRECT
  static const double _upPassThreshold = 125.0; // angle >= 125° -> PASS

  // Sideways (ear-to-shoulder) lockout, in m/s² on the filtered Y axis.
  static const double _sidewaysLockout = 5.5;

  // Frame counts & cooldown
  static const int _dwellFrames = 2;
  static const int _neutralSettleFrames = 2;
  static const Duration _cooldown = Duration(milliseconds: 400);

  bool invertTilt;
  double currentPitch = 90.0; // 0°–180° angle, used by the debug badge
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
    _neutralFrames = 0;

    _subscription = accelerometerEventStream(
      samplingPeriod: SensorInterval.gameInterval,
    ).listen((AccelerometerEvent event) {
      // ── Low-pass filter (each axis filtered exactly once per sample) ───────
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

      // 1. Sideways tilt lockout (ear-to-shoulder tilt or portrait grip)
      if (_gy.abs() > _sidewaysLockout) {
        _downFrames = 0;
        _upFrames = 0;
        _neutralFrames = 0;
        _zone = TiltZone.invalidOrientation;
        this.onTelemetry?.call(currentPitch, _zone);
        return;
      }

      // 2. Angle on the 0° (floor) -> 90° (upright) -> 180° (ceiling) scale
      final double xMag = _gx.abs();
      final double zVal = invertTilt ? -_gz : _gz;
      final double tiltFromVertical = math.atan2(zVal, xMag) * (180.0 / math.pi);
      final double angle = 90.0 + tiltFromVertical;
      currentPitch = angle;

      final now = DateTime.now();
      final bool cooledDown = now.difference(_lastTrigger) >= _cooldown;
      final bool inNeutralRange =
          angle >= _neutralMinAngle && angle <= _neutralMaxAngle;

      // 3. Neutral return gate: arms the sensor (initially and after a score)
      if (inNeutralRange) {
        _downFrames = 0;
        _upFrames = 0;
        _neutralFrames++;
        if (_neutralFrames >= _neutralSettleFrames && cooledDown) {
          _zone = TiltZone.neutral;
        }
      } else {
        _neutralFrames = 0;
      }

      // 4. Trigger gate: only fires when armed in neutral and tilted past 35°
      if (_zone == TiltZone.neutral && cooledDown) {
        if (angle <= _downCorrectThreshold) {
          // Tilt down -> CORRECT
          _downFrames++;
          _upFrames = 0;
          if (_downFrames >= _dwellFrames) {
            _zone = TiltZone.downCorrect;
            _downFrames = 0;
            _lastTrigger = now;
            onCorrect();
          }
        } else if (angle >= _upPassThreshold) {
          // Tilt up -> PASS
          _upFrames++;
          _downFrames = 0;
          if (_upFrames >= _dwellFrames) {
            _zone = TiltZone.upPass;
            _upFrames = 0;
            _lastTrigger = now;
            onPass();
          }
        } else {
          // Deadband (55°–68° or 112°–125°): do nothing
          _downFrames = 0;
          _upFrames = 0;
        }
      }

      this.onTelemetry?.call(currentPitch, _zone);
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