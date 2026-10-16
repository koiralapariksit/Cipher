import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';

/// Explicit actions emitted by the tilt controller.
enum TiltAction { correct, pass }

/// Deterministic 8-phase state machine states.
enum TiltState {
  inactive,
  calibrating,
  waitingForNeutral,
  armed,
  candidateCorrect,
  candidatePass,
  locked,
  paused,
}

/// Configuration parameters for filtering, validation, and state machine timings.
class TiltConfig {
  /// Time constant tau for the time-aware low-pass filter (seconds).
  final double tau;

  /// Lower plausible total acceleration magnitude (m/s²).
  final double gravityMin;

  /// Upper plausible total acceleration magnitude (m/s²).
  final double gravityMax;

  /// Maximum allowed lateral transverse acceleration |y| before lockout (m/s²).
  final double lateralLockout;

  /// Sample gap threshold that forces neutral re-acquisition (ms).
  final Duration maxSampleGap;

  /// Duration to gather dynamic neutral posture at session start.
  final Duration calibrationDuration;

  /// Maximum acceptable deviation from vertical (0°) during calibration.
  final double calibrationMaxVerticalDeviation;

  /// Neutral deadband half-width in degrees (neutralAngle ± neutralDeadband).
  final double neutralDeadband;

  /// Continuous hold duration within neutral deadband to re-arm.
  final Duration neutralConfirmDuration;

  /// Relative angular deflection needed to enter candidate states (degrees).
  final double triggerAngle;

  /// Continuous hold duration in candidate threshold to trigger an action.
  final Duration gestureConfirmDuration;

  /// Minimum lockout cooldown duration after an action or manual button tap.
  final Duration cooldownDuration;

  const TiltConfig({
    this.tau = 0.10,
    this.gravityMin = 7.0,
    this.gravityMax = 13.0,
    this.lateralLockout = 5.0,
    this.maxSampleGap = const Duration(milliseconds: 250),
    this.calibrationDuration = const Duration(milliseconds: 300),
    this.calibrationMaxVerticalDeviation = 20.0,
    this.neutralDeadband = 15.0,
    this.neutralConfirmDuration = const Duration(milliseconds: 150),
    this.triggerAngle = 38.0,
    this.gestureConfirmDuration = const Duration(milliseconds: 110),
    this.cooldownDuration = const Duration(milliseconds: 380),
  });
}

/// Pure, deterministic tilt controller and signal processing state machine.
class TiltController {
  final TiltConfig config;
  final DateTime Function() _now;

  // ── Signal Filter State ────────────────────────────────────────────────────
  double _filteredX = 0.0;
  double _filteredY = 0.0;
  double _filteredZ = 0.0;
  bool _filterInitialized = false;
  DateTime? _lastSampleTimestamp;

  // ── State Machine ──────────────────────────────────────────────────────────
  TiltState _state = TiltState.inactive;
  TiltState get state => _state;

  double _neutralAngle = 0.0;
  double get neutralAngle => _neutralAngle;

  double _currentAngle = 0.0;
  double get currentAngle => _currentAngle;

  double get relativeAngle => _currentAngle - _neutralAngle;

  double get filteredX => _filteredX;
  double get filteredY => _filteredY;
  double get filteredZ => _filteredZ;

  bool invertTilt;

  // State timers & tracking
  DateTime? _calibrationStart;
  final List<double> _calibrationSamples = [];

  DateTime? _neutralConfirmStart;
  DateTime? _candidateStart;
  DateTime? _lockedStart;

  // ── Output Streams & Callbacks ─────────────────────────────────────────────
  final StreamController<TiltAction> _actionController =
      StreamController<TiltAction>.broadcast();
  Stream<TiltAction> get actionStream => _actionController.stream;

  void Function(TiltAction action)? onAction;
  void Function(double angle, double relativeAngle, TiltState state)?
      onTelemetry;

  TiltController({
    this.config = const TiltConfig(),
    this.invertTilt = false,
    DateTime Function()? nowProvider,
  }) : _now = nowProvider ?? DateTime.now;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  /// Start the controller. Begins calibration window.
  void start({DateTime? startTime}) {
    final now = startTime ?? _now();
    _filterInitialized = false;
    _lastSampleTimestamp = null;
    _calibrationSamples.clear();
    _calibrationStart = now;
    _neutralConfirmStart = null;
    _candidateStart = null;
    _lockedStart = null;
    _neutralAngle = 0.0;
    _currentAngle = 0.0;

    _state = TiltState.calibrating;
    _notifyTelemetry();
  }

  /// Pause motion processing (e.g. game paused or app backgrounded).
  void pause() {
    if (_state == TiltState.inactive) return;
    _state = TiltState.paused;
    _candidateStart = null;
    _neutralConfirmStart = null;
    _notifyTelemetry();
  }

  /// Resume motion processing. Requires re-acquisition of neutral deadband.
  void resume() {
    if (_state != TiltState.paused) return;
    _state = TiltState.waitingForNeutral;
    _neutralConfirmStart = null;
    _candidateStart = null;
    _notifyTelemetry();
  }

  /// Immediately puts state machine into locked state (e.g. from manual button press).
  /// Prevents head recoil or concurrent nods from double-scoring.
  void lockManually({DateTime? timestamp}) {
    final now = timestamp ?? _now();
    _state = TiltState.locked;
    _lockedStart = now;
    _candidateStart = null;
    _neutralConfirmStart = null;
    _notifyTelemetry();
  }

  /// Completely resets state to inactive.
  void reset() {
    _state = TiltState.inactive;
    _filterInitialized = false;
    _lastSampleTimestamp = null;
    _calibrationSamples.clear();
    _neutralConfirmStart = null;
    _candidateStart = null;
    _lockedStart = null;
    _notifyTelemetry();
  }

  // ── Signal Processing & State Updates ──────────────────────────────────────

  /// Ingests a raw accelerometer sample (x, y, z in m/s²) and steps the state machine.
  void processSample(
    double rawX,
    double rawY,
    double rawZ, [
    DateTime? timestamp,
  ]) {
    final now = timestamp ?? _now();

    if (_state == TiltState.inactive || _state == TiltState.paused) {
      return;
    }

    // 1. Sanity Checks: reject non-finite numbers
    if (!rawX.isFinite || !rawY.isFinite || !rawZ.isFinite) {
      return;
    }

    // 2. Magnitude Check: plausible gravity window (7.0 - 13.0 m/s²)
    final double rawMagnitude =
        math.sqrt(rawX * rawX + rawY * rawY + rawZ * rawZ);
    final bool validMagnitude = rawMagnitude >= config.gravityMin &&
        rawMagnitude <= config.gravityMax;

    // 3. Time-Aware Low-Pass Filter
    if (!_filterInitialized) {
      _filteredX = rawX;
      _filteredY = rawY;
      _filteredZ = rawZ;
      _filterInitialized = true;
      _lastSampleTimestamp = now;
    } else {
      final double dt =
          now.difference(_lastSampleTimestamp!).inMicroseconds / 1000000.0;
      _lastSampleTimestamp = now;

      // Long gaps (> 250ms) invalidate continuity
      if (dt > config.maxSampleGap.inMilliseconds / 1000.0) {
        _candidateStart = null;
        _neutralConfirmStart = null;
        if (_state == TiltState.armed ||
            _state == TiltState.candidateCorrect ||
            _state == TiltState.candidatePass) {
          _state = TiltState.waitingForNeutral;
        }
        _filteredX = rawX;
        _filteredY = rawY;
        _filteredZ = rawZ;
      } else if (dt > 0.0) {
        final double alpha = 1.0 - math.exp(-dt / config.tau);
        _filteredX += alpha * (rawX - _filteredX);
        _filteredY += alpha * (rawY - _filteredY);
        _filteredZ += alpha * (rawZ - _filteredZ);
      }
    }

    // 4. Calculate Mathematical Screen-Normal Pitch Angle
    // Pure formulation: atan2(Z, sqrt(X² + Y²)) in degrees
    final double planar = math.sqrt(_filteredX * _filteredX + _filteredY * _filteredY);
    final double zVal = invertTilt ? -_filteredZ : _filteredZ;
    _currentAngle = math.atan2(zVal, planar) * (180.0 / math.pi);

    // 5. Lateral Ear-to-Shoulder Lockout Check
    final bool lateralViolation = _filteredY.abs() > config.lateralLockout;

    // Evaluate state machine transitions
    _stepStateMachine(now, validMagnitude, lateralViolation);
    _notifyTelemetry();
  }

  void _stepStateMachine(
    DateTime now,
    bool validMagnitude,
    bool lateralViolation,
  ) {
    switch (_state) {
      case TiltState.inactive:
      case TiltState.paused:
        break;

      case TiltState.calibrating:
        if (validMagnitude && !lateralViolation) {
          _calibrationSamples.add(_currentAngle);
        }
        final elapsed = now.difference(_calibrationStart!);
        if (elapsed >= config.calibrationDuration) {
          if (_calibrationSamples.isNotEmpty) {
            final double sum =
                _calibrationSamples.reduce((a, b) => a + b);
            final double avg = sum / _calibrationSamples.length;
            if (avg.abs() <= config.calibrationMaxVerticalDeviation) {
              _neutralAngle = avg;
            } else {
              _neutralAngle = 0.0;
            }
          } else {
            _neutralAngle = 0.0;
          }
          _state = TiltState.waitingForNeutral;
          _neutralConfirmStart = null;
        }
        break;

      case TiltState.waitingForNeutral:
        if (!validMagnitude || lateralViolation) {
          _neutralConfirmStart = null;
          return;
        }
        final bool inDeadband =
            relativeAngle.abs() <= config.neutralDeadband;
        if (inDeadband) {
          _neutralConfirmStart ??= now;
          if (now.difference(_neutralConfirmStart!) >=
              config.neutralConfirmDuration) {
            _state = TiltState.armed;
            _neutralConfirmStart = null;
          }
        } else {
          _neutralConfirmStart = null;
        }
        break;

      case TiltState.armed:
        if (!validMagnitude || lateralViolation) {
          return;
        }
        if (relativeAngle >= config.triggerAngle) {
          _state = TiltState.candidateCorrect;
          _candidateStart = now;
        } else if (relativeAngle <= -config.triggerAngle) {
          _state = TiltState.candidatePass;
          _candidateStart = now;
        }
        break;

      case TiltState.candidateCorrect:
        // Must stay in qualifying angle without lateral violation
        if (!validMagnitude ||
            lateralViolation ||
            relativeAngle < config.triggerAngle) {
          _state = TiltState.armed;
          _candidateStart = null;
          return;
        }
        if (now.difference(_candidateStart!) >=
            config.gestureConfirmDuration) {
          // Guaranteed transition to locked BEFORE dispatching event
          _state = TiltState.locked;
          _lockedStart = now;
          _candidateStart = null;
          _emitAction(TiltAction.correct);
        }
        break;

      case TiltState.candidatePass:
        // Must stay in qualifying angle without lateral violation
        if (!validMagnitude ||
            lateralViolation ||
            relativeAngle > -config.triggerAngle) {
          _state = TiltState.armed;
          _candidateStart = null;
          return;
        }
        if (now.difference(_candidateStart!) >=
            config.gestureConfirmDuration) {
          // Guaranteed transition to locked BEFORE dispatching event
          _state = TiltState.locked;
          _lockedStart = now;
          _candidateStart = null;
          _emitAction(TiltAction.pass);
        }
        break;

      case TiltState.locked:
        final bool cooldownElapsed =
            now.difference(_lockedStart!) >= config.cooldownDuration;
        final bool inDeadband =
            validMagnitude &&
            !lateralViolation &&
            relativeAngle.abs() <= config.neutralDeadband;

        // Transition from locked to waitingForNeutral requires BOTH conditions
        if (cooldownElapsed && inDeadband) {
          _state = TiltState.waitingForNeutral;
          _neutralConfirmStart = now;
          _lockedStart = null;
        }
        break;
    }
  }

  void _emitAction(TiltAction action) {
    _actionController.add(action);
    onAction?.call(action);
  }

  void _notifyTelemetry() {
    onTelemetry?.call(_currentAngle, relativeAngle, _state);
  }

  void dispose() {
    _actionController.close();
  }
}
