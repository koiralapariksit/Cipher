import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/deck.dart';
import '../models/game_round.dart';
import '../services/argon_sensor_engine.dart';
import '../services/game_controller.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../theme/deck_colors.dart';
import 'results_screen.dart';

/// Full-screen gameplay:
/// - Strictly locks to landscape orientation on entry; restores portrait on exit.
/// - Keeps screen awake with WakelockPlus.
/// - 3-2-1 "Place on Forehead" countdown with large numerals and haptic ticks.
/// - High-contrast responsive Bricolage Grotesque typography that never clips in landscape.
/// - Razor-sharp 3px word-level feedback container ("Correct: [Word]" / "Pass: [Word]").
/// - ArgonSensorEngine v2: Dynamic Forehead Baseline, Dual-Band Schmitt Hysteresis, Spike Gate.
/// - Live telemetry debug indicator showing Rel Pitch, Baseline, and Engine State.
/// - Lifecycle handling (WidgetsBindingObserver): auto-pause timer and sensors on background/minimize.
/// - Modal "Game Paused" overlay with Resume and Quit to Menu options.
/// - Manual fallback buttons on left (PASS) & right (GOT IT) edges.
class GameplayScreen extends StatefulWidget {
  final Deck deck;
  final int timerSeconds;

  const GameplayScreen({
    super.key,
    required this.deck,
    required this.timerSeconds,
  });

  @override
  State<GameplayScreen> createState() => _GameplayScreenState();
}

class _GameplayScreenState extends State<GameplayScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final GameController _controller;
  late final ArgonSensorEngine _engine;
  final StorageService _storage = StorageService();

  // Visual feedback flash state
  Color? _flashColor;
  String? _flashLabel;
  Timer? _flashTimer;

  bool _isNavigatingToResults = false;

  // Real-time sensor debug telemetry notifier
  final ValueNotifier<({double relPitch, double basePitch, TiltState state})>
      _sensorDebugNotifier = ValueNotifier((
    relPitch: 0.0,
    basePitch: 0.0,
    state: TiltState.uncalibrated,
  ));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 1. Strict Landscape Lock (strictly landscapeLeft to ensure fixed axis signs)
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
    ]);

    // 2. Hide System UI & Enable Wakelock
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WakelockPlus.enable();

    // 3. Setup Game Controller
    _controller = GameController(
      deck: widget.deck,
      timerSeconds: widget.timerSeconds,
    );
    _controller.onStateChanged = () {
      if (mounted) setState(() {});
    };
    _controller.onCountdownTick = (count) {
      if (_storage.settings.vibrationEnabled) {
        HapticFeedback.lightImpact();
      }
      if (_storage.settings.soundEnabled) {
        SystemSound.play(SystemSoundType.click);
      }
    };
    _controller.onGameFinished = _onGameFinished;

    // 4. Setup Argon Sensor Engine with saved invertTilt preference
    _engine = ArgonSensorEngine(
      invertZAxis: _storage.settings.invertTilt,
      onActionTriggered: _handleEngineAction,
      onTelemetryUpdate: (relPitch, basePitch, state) {
        _sensorDebugNotifier.value = (
          relPitch: relPitch,
          basePitch: basePitch,
          state: state,
        );
      },
    );

    _engine.start();
    _controller.start();
  }

  void _handleEngineAction(TiltAction action) {
    if (_controller.phase == GamePhase.playing) {
      final word = _controller.currentWord;
      final cardIdx = _controller.cardIndex;
      final sessionId = _controller.roundSessionId;
      final isCorrect = action == TiltAction.correct;
      _triggerFeedback(isCorrect: isCorrect, word: word);
      if (isCorrect) {
        _controller.markCorrect(
          expectedCardIndex: cardIdx,
          expectedSessionId: sessionId,
        );
      } else {
        _controller.markPass(
          expectedCardIndex: cardIdx,
          expectedSessionId: sessionId,
        );
      }
    }
  }

  void _triggerFeedback({required bool isCorrect, required String word}) {
    if (_storage.settings.vibrationEnabled) {
      if (isCorrect) {
        HapticFeedback.heavyImpact();
      } else {
        HapticFeedback.mediumImpact();
      }
    }

    if (_storage.settings.soundEnabled) {
      if (isCorrect) {
        SystemSound.play(SystemSoundType.click);
      } else {
        SystemSound.play(SystemSoundType.alert);
      }
    }

    _flashTimer?.cancel();
    setState(() {
      _flashColor = isCorrect ? kLime : kOrange;
      _flashLabel = isCorrect ? 'Correct: $word' : 'Pass: $word';
    });

    _flashTimer = Timer(const Duration(milliseconds: 550), () {
      if (mounted) {
        setState(() {
          _flashColor = null;
          _flashLabel = null;
        });
      }
    });
  }

  void _toggleSound() async {
    final nextSound = !_storage.settings.soundEnabled;
    await _storage.updateSettings(_storage.settings.copyWith(soundEnabled: nextSound));
    if (mounted) setState(() {});
  }

  // ── Lifecycle Handling ───────────────────────────────────────────────────
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      // Pause timers and sensor processing when leaving
      _engine.stop();
      _controller.pause();
    } else if (state == AppLifecycleState.resumed) {
      // Remain paused until user explicitly taps to resume
      if (_controller.phase != GamePhase.finished) {
        _controller.pause();
      }
    }
  }

  void _resumeFromPause() {
    _controller.resume();
    _engine.start();
  }

  void _quitToMenu() {
    _engine.stop();
    _controller.dispose();
    Navigator.of(context).pop();
  }

  void _onGameFinished(GameRound round) {
    if (_isNavigatingToResults) return;
    _isNavigatingToResults = true;

    _engine.stop();

    if (_storage.settings.vibrationEnabled) {
      HapticFeedback.vibrate();
    }
    if (_storage.settings.soundEnabled) {
      SystemSound.play(SystemSoundType.alert);
    }

    // Persist round history
    _storage.addRoundHistory(round);

    // Brief delay so player sees completion screen
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ResultsScreen(
            round: round,
            deck: widget.deck,
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _flashTimer?.cancel();
    _engine.stop();
    _sensorDebugNotifier.dispose();
    _controller.dispose();

    // Restore Portrait Orientation
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    // Restore System UI & Release Wakelock
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    WakelockPlus.disable();

    super.dispose();
  }

  void _handleManualCorrect() {
    if (_controller.phase == GamePhase.playing) {
      _engine.reset();
      final word = _controller.currentWord;
      final cardIdx = _controller.cardIndex;
      final sessionId = _controller.roundSessionId;
      _triggerFeedback(isCorrect: true, word: word);
      _controller.markCorrect(
        expectedCardIndex: cardIdx,
        expectedSessionId: sessionId,
      );
    }
  }

  void _handleManualPass() {
    if (_controller.phase == GamePhase.playing) {
      _engine.reset();
      final word = _controller.currentWord;
      final cardIdx = _controller.cardIndex;
      final sessionId = _controller.roundSessionId;
      _triggerFeedback(isCorrect: false, word: word);
      _controller.markPass(
        expectedCardIndex: cardIdx,
        expectedSessionId: sessionId,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appBgBottom,
      body: Container(
        decoration: appBackgroundDecoration,
        child: Stack(
          children: [
            // Base game screen body
            SafeArea(
              child: _buildBody(),
            ),

            // Razor-sharp 3px Word-level Feedback Indicator Overlay
            if (_flashLabel != null)
              Positioned(
                top: 56,
                left: 120,
                right: 120,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    decoration: BoxDecoration(
                      color: _flashColor ?? appTile,
                      borderRadius: BorderRadius.circular(appRadius),
                      border: Border.all(
                        color: kInk.withValues(alpha: 0.25),
                        width: 1.0,
                      ),
                    ),
                    child: Text(
                      _flashLabel!,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: appFont(
                        18,
                        weight: FontWeight.w700,
                        color: _flashColor != null ? kInk : appText,
                        spacing: -0.2,
                      ),
                    ),
                  ),
                ),
              ),

            // Live Telemetry HUD at bottom (Rel Pitch, Baseline, Engine State)
            Positioned(
              bottom: 6,
              left: 0,
              right: 0,
              child: ValueListenableBuilder<({double relPitch, double basePitch, TiltState state})>(
                valueListenable: _sensorDebugNotifier,
                builder: (context, data, _) {
                  final isNeutral = data.state == TiltState.neutralReady;
                  final isHoldingCorrect = data.state == TiltState.holdingCorrect;
                  final isHoldingPass = data.state == TiltState.holdingPass;
                  final isUncalibrated = data.state == TiltState.uncalibrated;

                  final Color badgeColor = isHoldingCorrect
                      ? kLime
                      : (isHoldingPass
                          ? kOrange
                          : (isNeutral
                              ? appText
                              : (isUncalibrated
                                  ? kOrange.withValues(alpha: 0.8)
                                  : appTextDim)));

                  final relSign = data.relPitch >= 0 ? '+' : '';
                  final baseSign = data.basePitch >= 0 ? '+' : '';
                  final stateLabel = switch (data.state) {
                    TiltState.uncalibrated => 'UNCALIBRATED',
                    TiltState.neutralReady => 'NEUTRAL READY',
                    TiltState.holdingCorrect => 'HOLDING CORRECT',
                    TiltState.holdingPass => 'HOLDING PASS',
                    TiltState.waitForNeutral => 'WAIT FOR NEUTRAL',
                  };

                  return Center(
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 3),
                        decoration: BoxDecoration(
                          color: appField,
                          borderRadius: BorderRadius.circular(appRadius),
                          border: Border.all(
                            color: badgeColor.withValues(alpha: 0.45),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          'REL PITCH: $relSign${data.relPitch.toStringAsFixed(1)}°  |  BASELINE: $baseSign${data.basePitch.toStringAsFixed(1)}°  |  STATE: $stateLabel',
                          style: appFont(
                            11,
                            color: badgeColor,
                            weight: FontWeight.w600,
                            spacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Full-screen Paused Modal Overlay
            if (_controller.phase == GamePhase.paused) _buildPauseOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_controller.phase) {
      case GamePhase.idle:
        return const Center(
          child: CircularProgressIndicator(color: appText),
        );
      case GamePhase.countdown:
        return _buildCountdown();
      case GamePhase.playing:
      case GamePhase.paused:
        return _buildPlaying();
      case GamePhase.finished:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "TIME'S UP!",
                style: appFont(
                  52,
                  weight: FontWeight.w700,
                  spacing: -1.0,
                  color: appText,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Calculating results...',
                style: appFont(16, color: appTextDim),
              ),
            ],
          ),
        );
    }
  }

  // ── Countdown Phase: 3-2-1 "Place on Forehead" ───────────────────────────
  Widget _buildCountdown() {
    final deckColor = deckColorFor(widget.deck);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: deckColor,
              borderRadius: BorderRadius.circular(appRadius),
              border: Border.all(color: kInk.withValues(alpha: 0.15), width: 1.0),
            ),
            child: Text(
              widget.deck.name,
              style: appFont(14, weight: FontWeight.w700, color: kInk),
            ),
          ),
          const SizedBox(height: 8),
          // Large countdown numeral in Bricolage Grotesque
          Text(
            '${_controller.countdownValue}',
            style: appFont(
              100,
              weight: FontWeight.w700,
              color: appText,
              spacing: -2.0,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
            decoration: BoxDecoration(
              color: appField,
              borderRadius: BorderRadius.circular(appRadius),
              border: Border.all(color: appLine, width: 0.8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.phone_android_rounded,
                    color: appTextDim, size: 18),
                const SizedBox(width: 8),
                Text(
                  'PLACE ON FOREHEAD',
                  style: appFont(
                    13,
                    weight: FontWeight.w600,
                    spacing: 0.8,
                    color: appText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Active Gameplay View: Ergonomic Landscape Layout ─────────────────────
  Widget _buildPlaying() {
    final showButtons = _storage.settings.showManualButtons;
    final deckColor = deckColorFor(widget.deck);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        children: [
          // Top Bar: Timer, Deck Badge, Score Badge, Invert Button, Pause Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildPillTimer(_controller.timeRemaining),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: deckColor,
                  borderRadius: BorderRadius.circular(appRadius),
                  border: Border.all(color: kInk.withValues(alpha: 0.15), width: 1.0),
                ),
                child: Text(
                  widget.deck.name,
                  style: appFont(14,
                      weight: FontWeight.w700, color: kInk),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildScoreBadge(_controller.score),
                  const SizedBox(width: 8),
                  AppIconButton(
                    icon: _storage.settings.soundEnabled
                        ? Icons.volume_up_rounded
                        : Icons.volume_off_rounded,
                    tooltip: _storage.settings.soundEnabled
                        ? 'Mute Sound Effects'
                        : 'Enable Sound Effects',
                    size: 36,
                    iconColor: _storage.settings.soundEnabled ? appText : appTextDim,
                    onTap: _toggleSound,
                  ),
                  const SizedBox(width: 8),
                  AppIconButton(
                    icon: Icons.pause_rounded,
                    tooltip: 'Pause game',
                    size: 36,
                    iconColor: appTextDim,
                    onTap: () {
                      _engine.stop();
                      _controller.pause();
                    },
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Main Center Area: Left Thumb Button + Word Card + Right Thumb Button
          Expanded(
            child: Row(
              children: [
                // Left Thumb PASS Button
                if (showButtons)
                  _ThumbButton(
                    label: 'PASS',
                    sublabel: 'Tilt Up ↑',
                    accentColor: kOrange,
                    icon: Icons.close_rounded,
                    onTap: _handleManualPass,
                  ),

                // Center Word Display
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: deckColor,
                      borderRadius: BorderRadius.circular(appRadius),
                      border: Border.all(color: kInk.withValues(alpha: 0.15), width: 1.0),
                    ),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 820),
                          child: Text(
                            _controller.currentWord,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            style: appFont(
                              56,
                              weight: FontWeight.w800,
                              color: kInk,
                              spacing: -1.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Right Thumb GOT IT Button
                if (showButtons)
                  _ThumbButton(
                    label: 'GOT IT',
                    sublabel: 'Tilt Down ↓',
                    accentColor: kLime,
                    icon: Icons.check_rounded,
                    onTap: _handleManualCorrect,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPillTimer(int seconds) {
    final isUrgent = seconds <= 10;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: isUrgent ? appPass.withValues(alpha: 0.2) : appField,
        borderRadius: BorderRadius.circular(appRadius),
        border: Border.all(
          color: isUrgent ? appPass : appLine,
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isUrgent ? Icons.timer_rounded : Icons.timer_outlined,
            size: 16,
            color: isUrgent ? appPass : appTextDim,
          ),
          const SizedBox(width: 6),
          Text(
            '${seconds}s',
            style: appFont(
              15,
              weight: FontWeight.w600,
              color: isUrgent ? appPass : appText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreBadge(int score) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: appField,
        borderRadius: BorderRadius.circular(appRadius),
        border: Border.all(color: appLine, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 16, color: appText),
          const SizedBox(width: 6),
          Text(
            '$score',
            style: appFont(15, weight: FontWeight.w600, color: appText),
          ),
        ],
      ),
    );
  }

  // ── Full-screen Pause Modal Overlay ──────────────────────────────────────
  Widget _buildPauseOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      alignment: Alignment.center,
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: appBgMid,
          borderRadius: BorderRadius.circular(appRadius),
          border: Border.all(color: appLine, width: 0.8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: appTile,
                borderRadius: BorderRadius.circular(appRadius),
                border: Border.all(color: appLine, width: 0.8),
              ),
              child: const Icon(
                Icons.pause_rounded,
                size: 24,
                color: appText,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Game Paused',
              style: appFont(
                22,
                weight: FontWeight.w700,
                spacing: -0.5,
                color: appText,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Game timer and motion sensors are suspended.',
              textAlign: TextAlign.center,
              style: appFont(13, color: appTextDim),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _quitToMenu,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        color: appTile,
                        borderRadius: BorderRadius.circular(appRadius),
                        border: Border.all(color: appLine, width: 0.8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Quit to Menu',
                        style: appFont(
                          13,
                          weight: FontWeight.w600,
                          color: appTextDim,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: _resumeFromPause,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        color: kYellow,
                        borderRadius: BorderRadius.circular(appRadius),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Resume',
                        style: appFont(
                          13,
                          weight: FontWeight.w700,
                          color: kInk,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Left/Right Thumb Buttons ────────────────────────────────────────────────

class _ThumbButton extends StatelessWidget {
  final String label;
  final String sublabel;
  final Color accentColor;
  final IconData icon;
  final VoidCallback onTap;

  const _ThumbButton({
    required this.label,
    required this.sublabel,
    required this.accentColor,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 90,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: appTile,
            borderRadius: BorderRadius.circular(appRadius),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.5),
              width: 0.8,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(appRadius),
                  color: accentColor.withValues(alpha: 0.15),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.5),
                    width: 0.8,
                  ),
                ),
                child: Icon(icon, size: 18, color: accentColor),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: appFont(
                  12,
                  weight: FontWeight.w600,
                  spacing: 0.5,
                  color: accentColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sublabel,
                textAlign: TextAlign.center,
                style: appFont(
                  10,
                  weight: FontWeight.w400,
                  color: appTextDim,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
