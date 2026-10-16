import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'tilt_controller.dart';

export 'tilt_controller.dart';

/// Service managing hardware accelerometer subscription and feeding samples
/// into the deterministic [TiltController].
class SensorService {
  StreamSubscription<AccelerometerEvent>? _subscription;
  late final TiltController _controller;

  TiltController get controller => _controller;
  TiltState get state => _controller.state;

  bool get invertTilt => _controller.invertTilt;
  set invertTilt(bool val) => _controller.invertTilt = val;

  double get currentPitch => _controller.currentAngle;
  double get relativeAngle => _controller.relativeAngle;

  void Function(double angle, double relativeAngle, TiltState state)?
      onTelemetry;

  SensorService({
    TiltConfig config = const TiltConfig(),
    bool invertTilt = false,
  }) {
    _controller = TiltController(
      config: config,
      invertTilt: invertTilt,
    );
  }

  void startListening({
    required VoidCallback onCorrect,
    required VoidCallback onPass,
    void Function(double angle, double relativeAngle, TiltState state)?
        onTelemetry,
  }) {
    this.onTelemetry = onTelemetry;
    stopListening();

    _controller.onAction = (action) {
      if (action == TiltAction.correct) {
        onCorrect();
      } else if (action == TiltAction.pass) {
        onPass();
      }
    };

    _controller.onTelemetry = (angle, relative, state) {
      this.onTelemetry?.call(angle, relative, state);
    };

    _controller.start();

    _subscription = accelerometerEventStream(
      samplingPeriod: SensorInterval.gameInterval,
    ).listen((AccelerometerEvent event) {
      _controller.processSample(event.x, event.y, event.z);
    });
  }

  /// Lock sensor state immediately (used when a manual button tap occurs).
  void lockManually() {
    _controller.lockManually();
  }

  /// Pause motion processing (e.g. gameplay pause overlay).
  void pause() {
    _controller.pause();
  }

  /// Resume motion processing (requires neutral re-arm).
  void resume() {
    _controller.resume();
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    _controller.reset();
  }

  void dispose() {
    stopListening();
    _controller.dispose();
  }
}