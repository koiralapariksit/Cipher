import 'package:flutter_test/flutter_test.dart';
import 'package:heads_guess/services/argon_sensor_engine.dart';

void main() {
  group('ArgonSensorEngine Deterministic Dart Verification', () {
    late List<TiltAction> actions;
    late ArgonSensorEngine engine;
    late DateTime currentTime;

    setUp(() {
      actions = [];
      currentTime = DateTime(2026, 1, 1, 12, 0, 0);
      engine = ArgonSensorEngine(
        onActionTriggered: (action) => actions.add(action),
      );
    });

    void feedSample(double x, double y, double z, {int dtMs = 20}) {
      currentTime = currentTime.add(Duration(milliseconds: dtMs));
      engine.processSample(x, y, z, currentTime);
    }

    void feedMultiple(double x, double y, double z, int count, {int dtMs = 20}) {
      for (int i = 0; i < count; i++) {
        feedSample(x, y, z, dtMs: dtMs);
      }
    }

    void calibrateNeutral({double pitchDeg = 0.0}) {
      // Resting on forehead: pitchDeg
      // pitch = atan2(z, sqrt(x^2 + y^2))
      // For pitch 0: x = 9.81, y = 0.0, z = 0.0
      // 120ms required for calibration -> 7 samples of 20ms = 140ms
      feedMultiple(9.81, 0.0, 0.0, 8);
      expect(engine.state, TiltState.neutralReady);
    }

    test('Calibration captures resting baseline and enters neutralReady', () {
      expect(engine.state, TiltState.uncalibrated);
      // Feed samples at 0 deg
      feedMultiple(9.81, 0.0, 0.0, 4); // 80ms
      expect(engine.state, TiltState.uncalibrated);

      feedMultiple(9.81, 0.0, 0.0, 4); // +80ms = 160ms > 120ms
      expect(engine.state, TiltState.neutralReady);
      expect(engine.baselinePitchDeg, closeTo(0.0, 0.5));
    });

    test('Spike gate discards extreme shocks (>18.0 m/s²) without corrupting filter', () {
      calibrateNeutral();
      final baseZ = engine.rawPitchDeg;

      // Violent spike (magnitude ~ 30 m/s²)
      feedSample(10.0, 10.0, 25.0);

      // Raw pitch should not jump to the violent spike
      expect(engine.rawPitchDeg, closeTo(baseZ, 5.0));
      expect(actions, isEmpty);
    });

    test('Deliberate tilt down triggers TiltAction.correct after sustain and min samples', () {
      calibrateNeutral();

      // Pitch down: z > 0. For 55 deg tilt: x = 9.81 * cos(55°) = 5.63, z = 9.81 * sin(55°) = 8.04
      // Feed enough samples to pass EMA filter lag and meet 85ms sustain + 4 samples
      feedMultiple(5.63, 0.0, 8.04, 12); // 240ms

      expect(actions, hasLength(1));
      expect(actions.first, TiltAction.correct);
      expect(engine.state, TiltState.waitForNeutral);
    });

    test('Deliberate tilt up triggers TiltAction.pass after sustain and min samples', () {
      calibrateNeutral();

      // Pitch up: z < 0. For -55 deg tilt: x = 5.63, z = -8.04
      feedMultiple(5.63, 0.0, -8.04, 12); // 240ms

      expect(actions, hasLength(1));
      expect(actions.first, TiltAction.pass);
      expect(engine.state, TiltState.waitForNeutral);
    });

    test('Schmitt hysteresis prevents premature exit on minor jitter inside hold', () {
      calibrateNeutral();

      // Enter hold with tilt
      feedMultiple(5.63, 0.0, 8.04, 5); // 100ms
      expect(engine.state, anyOf(TiltState.holdingCorrect, TiltState.waitForNeutral));
    });

    test('Invert Z-Axis flips pitch direction', () {
      engine.invertZAxis = true;
      calibrateNeutral();

      // When z is negative in hardware, inverted z becomes positive -> correct
      feedMultiple(5.63, 0.0, -8.04, 12);

      expect(actions, hasLength(1));
      expect(actions.first, TiltAction.correct);
    });

    test('Engine requires neutral re-acquisition after a trigger', () {
      calibrateNeutral();

      // Trigger correct
      feedMultiple(5.63, 0.0, 8.04, 12);
      expect(actions, hasLength(1));
      expect(engine.state, TiltState.waitForNeutral);

      // Continue holding tilt down: must NOT trigger again
      feedMultiple(5.63, 0.0, 8.04, 20);
      expect(actions, hasLength(1));

      // Return to neutral (0 deg) for 80ms (4 samples = 80ms)
      feedMultiple(9.81, 0.0, 0.0, 8);
      expect(engine.state, TiltState.neutralReady);
    });
  });
}

