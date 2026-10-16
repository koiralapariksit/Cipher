import 'package:flutter_test/flutter_test.dart';
import 'package:heads_guess/services/tilt_controller.dart';

void main() {
  group('TiltController deterministic state machine', () {
    late DateTime simulatedTime;
    late List<TiltAction> emittedActions;
    late TiltController controller;

    setUp(() {
      simulatedTime = DateTime(2026, 1, 1, 12, 0, 0);
      emittedActions = [];
      controller = TiltController(
        config: const TiltConfig(
          tau: 0.10,
          calibrationDuration: Duration(milliseconds: 300),
          neutralConfirmDuration: Duration(milliseconds: 150),
          gestureConfirmDuration: Duration(milliseconds: 100),
          cooldownDuration: Duration(milliseconds: 300),
          triggerAngle: 38.0,
          neutralDeadband: 15.0,
        ),
        nowProvider: () => simulatedTime,
      );
      controller.onAction = (action) => emittedActions.add(action);
      controller.start();
    });

    tearDown(() {
      controller.dispose();
    });

    /// Feeds samples with simulated timestamps advances.
    void feedSamples({
      required double x,
      required double y,
      required double z,
      required int count,
      Duration step = const Duration(milliseconds: 10),
    }) {
      for (int i = 0; i < count; i++) {
        simulatedTime = simulatedTime.add(step);
        controller.processSample(x, y, z);
      }
    }

    /// Complete calibration phase at neutral resting posture (x=0, y=0, z=0, gravity purely downwards or outward).
    /// For forehead vertical, phone is upright landscape: gravity is along X or Y in phone plane, Z is near 0.
    /// E.g. x = 9.80, y = 0.0, z = 0.0 -> pitch = 0.0 degrees.
    void calibrateToNeutral() {
      // Feed 35 samples for calibration (350ms > 300ms calibrationDuration)
      feedSamples(x: 9.80, y: 0.0, z: 0.0, count: 35);
      expect(controller.state, TiltState.waitingForNeutral);

      // Feed 20 samples for neutral confirmation (200ms > 150ms neutralConfirmDuration)
      feedSamples(x: 9.80, y: 0.0, z: 0.0, count: 20);
      expect(controller.state, TiltState.armed);
    }

    test('Test 1: Steady neutral emits zero actions', () {
      calibrateToNeutral();
      emittedActions.clear();

      // Feed 100 samples at steady neutral
      feedSamples(x: 9.80, y: 0.0, z: 0.0, count: 100);

      expect(emittedActions, isEmpty);
      expect(controller.state, TiltState.armed);
    });

    test('Test 2: Accidental head wobbles (±15°) emit zero actions', () {
      calibrateToNeutral();
      emittedActions.clear();

      // Moderate deflections under trigger threshold (38°)
      // z = 2.0 with x = 9.5 -> atan2(2.0, 9.5) = ~11.8°
      feedSamples(x: 9.50, y: 0.0, z: 2.0, count: 20);
      expect(emittedActions, isEmpty);

      // z = -2.0 with x = 9.5 -> ~-11.8°
      feedSamples(x: 9.50, y: 0.0, z: -2.0, count: 20);
      expect(emittedActions, isEmpty);

      // z = 3.5 with x = 9.1 -> atan2(3.5, 9.1) = ~21.0° (under 38°)
      feedSamples(x: 9.10, y: 0.0, z: 3.5, count: 20);
      expect(emittedActions, isEmpty);

      // Return to neutral
      feedSamples(x: 9.80, y: 0.0, z: 0.0, count: 20);
      expect(emittedActions, isEmpty);
      expect(controller.state, TiltState.armed);
    });

    test('Test 3: Deliberate tilt down held for 120ms emits exactly 1 TiltAction.correct', () {
      calibrateToNeutral();
      emittedActions.clear();

      // Tilt screen towards floor: z is strong positive.
      // E.g., z = 8.5, x = 4.0 -> atan2(8.5, 4.0) = ~64.8°
      // With tau=0.10s, after ~100-150ms the filtered angle exceeds 38°,
      // then requires 100ms gesture confirmation. Total ~25-30 samples (250-300ms).
      feedSamples(x: 4.0, y: 0.0, z: 8.50, count: 30);

      expect(emittedActions, [TiltAction.correct]);
      expect(controller.state, TiltState.locked);
    });

    test('Test 4: Continuing to hold tilt down for 3 seconds emits NO additional actions', () {
      calibrateToNeutral();
      emittedActions.clear();

      // Trigger correct action
      feedSamples(x: 4.0, y: 0.0, z: 8.50, count: 30);
      expect(emittedActions.length, 1);
      expect(emittedActions.first, TiltAction.correct);

      // Hold tilt down for 300 samples (3.0 seconds)
      feedSamples(x: 4.0, y: 0.0, z: 8.50, count: 300);

      // Still exactly 1 action emitted (lockout prevents re-triggering until neutral re-acquisition)
      expect(emittedActions.length, 1);
      expect(controller.state, TiltState.locked);
    });

    test('Test 5: Snapping back to neutral emits zero actions and re-arms', () {
      calibrateToNeutral();
      emittedActions.clear();

      // Trigger correct action
      feedSamples(x: 4.0, y: 0.0, z: 8.50, count: 30);
      expect(emittedActions, [TiltAction.correct]);
      expect(controller.state, TiltState.locked);

      // Advance past cooldown (300ms) and hold neutral (150ms confirm duration)
      // Total 50 samples (500ms in neutral)
      feedSamples(x: 9.80, y: 0.0, z: 0.0, count: 50);

      // Confirm re-armed without any spurious action
      expect(emittedActions.length, 1);
      expect(controller.state, TiltState.armed);
    });

    test('Test 6: Deliberate tilt up held for 120ms emits exactly 1 TiltAction.pass', () {
      calibrateToNeutral();
      emittedActions.clear();

      // Tilt screen towards ceiling: z is strong negative.
      // E.g., z = -8.5, x = 4.0 -> atan2(-8.5, 4.0) = ~-64.8° < -38.0°
      feedSamples(x: 4.0, y: 0.0, z: -8.50, count: 30);

      expect(emittedActions, [TiltAction.pass]);
      expect(controller.state, TiltState.locked);
    });

    test('Test 7: Spikes under 80ms are discarded without action', () {
      calibrateToNeutral();
      emittedActions.clear();

      // Brief nod down for 50ms (5 samples) then back to neutral
      feedSamples(x: 4.0, y: 0.0, z: 8.50, count: 5);
      expect(controller.state, anyOf(TiltState.candidateCorrect, TiltState.armed));

      // Return to neutral immediately
      feedSamples(x: 9.80, y: 0.0, z: 0.0, count: 20);

      expect(emittedActions, isEmpty);
      expect(controller.state, TiltState.armed);
    });

    test('Test 8: Rapid alternations between tilt directions cancel candidate states cleanly', () {
      calibrateToNeutral();
      emittedActions.clear();

      // Tilt down for 40ms (below threshold)
      feedSamples(x: 4.0, y: 0.0, z: 8.50, count: 4);
      // Immediately alternate to tilt up for 40ms
      feedSamples(x: 4.0, y: 0.0, z: -8.50, count: 4);
      // Back to tilt down for 40ms
      feedSamples(x: 4.0, y: 0.0, z: 8.50, count: 4);

      expect(emittedActions, isEmpty);

      // Return to neutral
      feedSamples(x: 9.80, y: 0.0, z: 0.0, count: 30);
      expect(emittedActions, isEmpty);
      expect(controller.state, TiltState.armed);
    });

    test('Test 9: Cooldown expiration without returning to neutral remains locked', () {
      calibrateToNeutral();
      emittedActions.clear();

      // Trigger correct action
      feedSamples(x: 4.0, y: 0.0, z: 8.50, count: 30);
      expect(emittedActions, [TiltAction.correct]);
      expect(controller.state, TiltState.locked);

      // Stay tilted down for 500ms (cooldown is 300ms)
      feedSamples(x: 4.0, y: 0.0, z: 8.50, count: 50);

      // Even though cooldown expired, state MUST remain locked because player hasn't returned to neutral
      expect(controller.state, TiltState.locked);
      expect(emittedActions.length, 1);
    });

    test('Test 10: Pausing resets candidate states and mandates neutral re-acquisition', () {
      calibrateToNeutral();
      emittedActions.clear();

      // Enter candidate tilt state
      feedSamples(x: 4.0, y: 0.0, z: 8.50, count: 5);

      // Pause controller
      controller.pause();
      expect(controller.state, TiltState.paused);

      // Process samples while paused
      feedSamples(x: 4.0, y: 0.0, z: 8.50, count: 20);
      expect(emittedActions, isEmpty);

      // Resume controller
      controller.resume();
      expect(controller.state, TiltState.waitingForNeutral);

      // While still tilted, cannot arm
      feedSamples(x: 4.0, y: 0.0, z: 8.50, count: 20);
      expect(controller.state, TiltState.waitingForNeutral);
      expect(emittedActions, isEmpty);

      // Return to neutral for 400ms (filter settling + 150ms neutral confirmation)
      feedSamples(x: 9.80, y: 0.0, z: 0.0, count: 40);
      expect(controller.state, TiltState.armed);
      expect(emittedActions, isEmpty);
    });
  });
}

