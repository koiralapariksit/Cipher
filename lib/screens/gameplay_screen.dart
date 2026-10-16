import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/deck.dart';
import '../models/game_round.dart';
import '../services/game_controller.dart';
import '../services/sensor_service.dart';
import '../services/storage_service.dart';
import '../theme/luxury_theme.dart';
import 'results_screen.dart';

/// Full-screen gameplay:
/// - Strictly locks to landscape orientation on entry; restores portrait on exit.
/// - Keeps screen awake with WakelockPlus.
/// - 3-2-1 "Place on Forehead" countdown with large numerals and haptic ticks.
/// - High-contrast responsive Jost typography that never clips in landscape.
/// - Subtle visual feedback: Emerald on Correct (+1), Amber on Pass (0).
/// - Exact 3-axis forehead sensor tilt with low-pass gravity filter and lockout.
/// - Live telemetry debug indicator showing pitch angle degrees and TiltZone.
/// - Lifecycle handling (WidgetsBindingObserver): auto-pause timer and sensors on background/minimize.
/// - Modal "Game Paused" overlay with Resume and Quit to Menu options.
/// - Tilt axis invert toggle in the top bar.
/// - Luxury manual fallback buttons on left (PASS) & right (CORRECT) edges.
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
  late final SensorService _sensor;
  final StorageService _storage = StorageService();

  // Visual feedback flash animation
  Color? _flashColor;
  String? _flashLabel;
  Timer? _flashTimer;

  bool _isNavigatingToResults = false;

  // Real-time sensor debug telemetry notifier
  final ValueNotifier<({double pitch, TiltZone zone})> _sensorDebugNotifier =
      ValueNotifier((pitch: 0.0, zone: TiltZone.uncalibrated));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 1. Strict Landscape Lock
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
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
    };
    _controller.onGameFinished = _onGameFinished;

    // 4. Setup Sensor Service (single listener started here)
    _sensor = SensorService();

    _startSensor();
    _controller.start();
  }

  void _startSensor() {
    _sensor.startListening(
      onCorrect: () {
        if (_controller.phase == GamePhase.playing) {
          final word = _controller.currentWord;
          _triggerFeedback(isCorrect: true, word: word);
          _controller.markCorrect();
        }
      },
      onPass: () {
        if (_controller.phase == GamePhase.playing) {
          final word = _controller.currentWord;
          _triggerFeedback(isCorrect: false, word: word);
          _controller.markPass();
        }
      },
      onTelemetry: (pitch, zone) {
        _sensorDebugNotifier.value = (pitch: pitch, zone: zone);
      },
    );
  }

  void _triggerFeedback({required bool isCorrect, required String word}) {
    if (_storage.settings.vibrationEnabled) {
      if (isCorrect) {
        HapticFeedback.heavyImpact();
      } else {
        HapticFeedback.mediumImpact();
      }
    }

    _flashTimer?.cancel();
    setState(() {
      _flashColor = isCorrect ? kCorrectGreen : kPassAmber;
      _flashLabel = isCorrect ? 'Correct: $word' : 'Pass: $word';
    });

    _flashTimer = Timer(const Duration(milliseconds: 450), () {
      if (mounted) {
        setState(() {
          _flashColor = null;
          _flashLabel = null;
        });
      }
    });
  }

  void _toggleInvertTilt() {
    setState(() {
      _sensor.invertTilt = !_sensor.invertTilt;
    });
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _sensor.invertTilt ? 'Tilt Axis Inverted' : 'Normal Tilt Axis',
          style: luxuryFont(13, color: kText),
        ),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: kGold.withValues(alpha: 0.4), width: 0.8),
        ),
        backgroundColor: kPanelTop,
      ),
    );
  }

  // ── Lifecycle Handling ───────────────────────────────────────────────────
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      // Pause timers and stop accelerometer when leaving
      _sensor.stopListening();
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
    _startSensor();
  }

  void _quitToMenu() {
    _sensor.stopListening();
    _controller.dispose();
    Navigator.of(context).pop();
  }

  void _onGameFinished(GameRound round) {
    if (_isNavigatingToResults) return;
    _isNavigatingToResults = true;

    _sensor.stopListening();

    if (_storage.settings.vibrationEnabled) {
      HapticFeedback.vibrate();
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
    _sensor.stopListening();
    _sensor.dispose();
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
      final word = _controller.currentWord;
      _triggerFeedback(isCorrect: true, word: word);
      _controller.markCorrect();
    }
  }

  void _handleManualPass() {
    if (_controller.phase == GamePhase.playing) {
      final word = _controller.currentWord;
      _triggerFeedback(isCorrect: false, word: word);
      _controller.markPass();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBlack,
      body: Stack(
        children: [
          // Base game screen body
          SafeArea(
            child: _buildBody(),
          ),

          // Refined Visual Flash Overlay (Emerald for Correct, Amber for Pass)
          if (_flashColor != null)
            Positioned.fill(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  color: _flashColor!.withValues(alpha: 0.90),
                ),
                alignment: Alignment.center,
                child: Text(
                  _flashLabel ?? '',
                  textAlign: TextAlign.center,
                  style: luxuryFont(
                    54,
                    weight: FontWeight.w500,
                    spacing: 2.0,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

          // Live Tilt Debug Indicator (Centered Subtle Low-Profile Luxury Pill)
          Positioned(
            bottom: 6,
            left: 0,
            right: 0,
            child: ValueListenableBuilder<({double pitch, TiltZone zone})>(
              valueListenable: _sensorDebugNotifier,
              builder: (context, data, _) {
                final isNeutral = data.zone == TiltZone.neutral;
                final isCorrect = data.zone == TiltZone.downCorrect;
                final isPass = data.zone == TiltZone.upPass;
                final isInvalid = data.zone == TiltZone.invalidOrientation;

                final Color badgeColor = isCorrect
                    ? kCorrectGreen
                    : (isPass
                        ? kPassAmber
                        : (isNeutral
                            ? kGold
                            : (isInvalid ? const Color(0xFFEF4444) : kTextDim)));

                return Center(
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: luxuryPanel(
                        radius: 6,
                        borderColor: badgeColor.withValues(alpha: 0.45),
                      ),
                      child: Text(
                        'Pitch: ${data.pitch.toStringAsFixed(0)}° • ${data.zone.name.toUpperCase()}',
                        style: luxuryFont(
                          11,
                          color: badgeColor,
                          weight: FontWeight.w500,
                          spacing: 0.5,
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
    );
  }

  Widget _buildBody() {
    switch (_controller.phase) {
      case GamePhase.idle:
        return const Center(
          child: CircularProgressIndicator(color: kGold),
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
                style: luxuryFont(
                  52,
                  weight: FontWeight.w300,
                  spacing: 2.0,
                  color: kGold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Calculating results...',
                style: luxuryFont(16, color: kTextDim),
              ),
            ],
          ),
        );
    }
  }

  // ── Countdown Phase: 3-2-1 "Place on Forehead" ───────────────────────────
  Widget _buildCountdown() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: luxuryPanel(radius: 8, highlight: true),
            child: Text(
              widget.deck.name.toUpperCase(),
              style: luxuryFont(15, weight: FontWeight.w500, spacing: 1.5, color: kGold),
            ),
          ),
          const SizedBox(height: 10),
          // Large countdown numeral in Jost
          Text(
            '${_controller.countdownValue}',
            style: luxuryFont(
              100,
              weight: FontWeight.w300,
              color: kGold,
              spacing: -1.0,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: luxuryPanel(radius: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.phone_android_rounded,
                    color: kGold, size: 20),
                const SizedBox(width: 8),
                Text(
                  'PLACE ON FOREHEAD',
                  style: luxuryFont(
                    13,
                    weight: FontWeight.w500,
                    spacing: 1.8,
                    color: kText,
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
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: luxuryPanel(radius: 8),
                child: Text(
                  widget.deck.name,
                  style: luxuryFont(14,
                      weight: FontWeight.w500, color: kText),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildScoreBadge(_controller.score),
                  const SizedBox(width: 8),
                  LuxuryRoundButton(
                    icon: Icons.swap_vert_rounded,
                    tooltip: 'Invert Tilt Axis',
                    size: 38,
                    iconColor: _sensor.invertTilt ? kPassAmber : kGold,
                    onTap: _toggleInvertTilt,
                  ),
                  const SizedBox(width: 8),
                  LuxuryRoundButton(
                    icon: Icons.pause_rounded,
                    tooltip: 'Pause game',
                    size: 38,
                    onTap: () {
                      _sensor.stopListening();
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
                  _LuxuryThumbButton(
                    label: 'PASS',
                    sublabel: 'Tilt Up ↑',
                    accentColor: kPassAmber,
                    icon: Icons.close_rounded,
                    onTap: _handleManualPass,
                  ),

                // Center Word Display
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    decoration: luxuryPanel(radius: 8, highlight: true),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 820),
                          child: Text(
                            _controller.currentWord,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            style: luxuryFont(
                              54,
                              weight: FontWeight.w400,
                              color: kText,
                              spacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Right Thumb CORRECT Button
                if (showButtons)
                  _LuxuryThumbButton(
                    label: 'CORRECT',
                    sublabel: 'Tilt Down ↓',
                    accentColor: kCorrectGreen,
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: luxuryPanel(
        radius: 8,
        borderColor: isUrgent ? kPassAmber : kGold.withValues(alpha: 0.8),
        fillTop: isUrgent ? const Color(0xFF2E150A) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isUrgent ? Icons.timer_rounded : Icons.timer_outlined,
            size: 16,
            color: isUrgent ? kPassAmber : kGold,
          ),
          const SizedBox(width: 6),
          Text(
            '${seconds}s',
            style: luxuryFont(
              16,
              weight: FontWeight.w500,
              color: isUrgent ? kPassAmber : kGold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreBadge(int score) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: luxuryPanel(radius: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 18, color: kGold),
          const SizedBox(width: 6),
          Text(
            '$score',
            style: luxuryFont(16, weight: FontWeight.w500, color: kGold),
          ),
        ],
      ),
    );
  }

  // ── Full-screen Pause Modal Overlay ──────────────────────────────────────
  Widget _buildPauseOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.90),
      alignment: Alignment.center,
      child: Container(
        width: 440,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 28),
        decoration: luxuryPanel(radius: 8, highlight: true),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: luxuryPanel(radius: 8, highlight: true),
              child: const Icon(
                Icons.pause_rounded,
                size: 30,
                color: kGold,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'GAME PAUSED',
              style: luxuryFont(
                24,
                weight: FontWeight.w300,
                spacing: 2.0,
                color: kGold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Game timer and motion sensors are suspended.',
              textAlign: TextAlign.center,
              style: luxuryFont(13, color: kTextDim),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _quitToMenu,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: luxuryPanel(radius: 8),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.arrow_back_rounded,
                              color: kPassAmber, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'QUIT TO MENU',
                            style: luxuryFont(
                              12,
                              weight: FontWeight.w500,
                              spacing: 1.0,
                              color: kPassAmber,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: _resumeFromPause,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: luxuryPanel(
                        radius: 8,
                        highlight: true,
                        fillTop: const Color(0xFF241F14),
                        fillBottom: const Color(0xFF14110A),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.play_arrow_rounded,
                              color: kGold, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            'RESUME',
                            style: luxuryFont(
                              13,
                              weight: FontWeight.w500,
                              spacing: 1.2,
                              color: kGold,
                            ),
                          ),
                        ],
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

// ── Luxury Left/Right Thumb Buttons ─────────────────────────────────────────

class _LuxuryThumbButton extends StatelessWidget {
  final String label;
  final String sublabel;
  final Color accentColor;
  final IconData icon;
  final VoidCallback onTap;

  const _LuxuryThumbButton({
    required this.label,
    required this.sublabel,
    required this.accentColor,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 95,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: luxuryPanel(
            radius: 8,
            borderColor: accentColor.withValues(alpha: 0.65),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: accentColor.withValues(alpha: 0.15),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.6),
                    width: 1,
                  ),
                ),
                child: Icon(icon, size: 20, color: accentColor),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: luxuryFont(
                  13,
                  weight: FontWeight.w500,
                  spacing: 1.0,
                  color: accentColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sublabel,
                textAlign: TextAlign.center,
                style: luxuryFont(
                  10,
                  weight: FontWeight.w400,
                  color: kTextDim,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
