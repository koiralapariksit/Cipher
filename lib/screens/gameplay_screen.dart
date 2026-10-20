import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/deck.dart';
import '../models/game_round.dart';
import '../services/argon_sensor_engine.dart';
import '../services/game_controller.dart';
import '../services/storage_service.dart';
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

  @override
  Widget build(BuildContext context) {
    final deckColor = deckColorFor(widget.deck);

    return Scaffold(
      backgroundColor: deckColor,
      body: Stack(
        children: [
          // Base game screen body
          SafeArea(
            child: _buildBody(),
          ),

          // Neo-brutalist Word-level Feedback Indicator Overlay
          if (_flashLabel != null)
            Positioned(
              top: 54,
              left: 120,
              right: 120,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  decoration: BoxDecoration(
                    color: _flashColor ?? kCream,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: kInk, width: 2.5),
                    boxShadow: kHardShadow,
                  ),
                  child: Text(
                    _flashLabel!,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.bowlbyOne(
                      fontSize: 18,
                      color: kInk,
                    ),
                  ),
                ),
              ),
            ),

          // Subtle tilt hint at bottom
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: Center(
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 5),
                  decoration: BoxDecoration(
                    color: kInk,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: kInk, width: 1.5),
                    boxShadow: kSmallShadow,
                  ),
                  child: Text(
                    _storage.settings.invertTilt
                        ? 'TILT DOWN = GOT IT!  •  TILT UP = PASS'
                        : 'TILT DOWN = PASS  •  TILT UP = GOT IT!',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: kCream,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
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
          child: CircularProgressIndicator(color: kInk),
        );
      case GamePhase.countdown:
        return _buildCountdown();
      case GamePhase.playing:
      case GamePhase.paused:
        return _buildPlaying();
      case GamePhase.finished:
        return Center(
          child: Container(
            width: 440,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            decoration: BoxDecoration(
              color: kInk,
              borderRadius: kAsymmetricRadius,
              border: Border.all(color: kCream, width: 3.5),
              boxShadow: const [
                BoxShadow(
                    color: Color(0xFF0F0A1C),
                    offset: Offset(6, 6),
                    blurRadius: 0),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Time's Up!",
                  style: GoogleFonts.bowlbyOne(
                    fontSize: 44,
                    color: kYellow,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${_controller.score}',
                  style: GoogleFonts.bowlbyOne(
                    fontSize: 72,
                    color: kLime,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Calculating results...',
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: kCream,
                  ),
                ),
              ],
            ),
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
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
            decoration: BoxDecoration(
              color: kCream,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: kInk, width: 2.0),
              boxShadow: kSmallShadow,
            ),
            child: Text(
              widget.deck.name,
              style: GoogleFonts.bowlbyOne(fontSize: 15, color: kInk),
            ),
          ),
          const SizedBox(height: 8),
          // Large countdown numeral in Bowlby One
          Text(
            '${_controller.countdownValue}',
            style: GoogleFonts.bowlbyOne(
              fontSize: 110,
              color: kInk,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: kYellow,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: kInk, width: 2.5),
              boxShadow: kSmallShadow,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.phone_android_rounded,
                    color: kInk, size: 20),
                const SizedBox(width: 8),
                Text(
                  'PLACE ON FOREHEAD',
                  style: GoogleFonts.bowlbyOne(
                    fontSize: 13,
                    color: kInk,
                    letterSpacing: 0.5,
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        children: [
          // Top Bar: Exit button, Timer display, Deck Name, Score badge, Sound & Pause
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Quit button: rounded kInk button labeled '✕ QUIT' with 2px kInk border, cream text, Offset(2, 2) shadow
              GestureDetector(
                onTap: _quitToMenu,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: kInk,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: kInk, width: 2.0),
                    boxShadow: const [
                      BoxShadow(
                          color: kInk, offset: Offset(2, 2), blurRadius: 0),
                    ],
                  ),
                  child: Text(
                    '✕ QUIT',
                    style: GoogleFonts.bowlbyOne(
                      fontSize: 13,
                      color: kCream,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),

              // Timer Display in pill
              _buildPillTimer(_controller.timeRemaining),

              // Deck name badge in dark ink
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: kCream,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: kInk, width: 2.0),
                  boxShadow: kSmallShadow,
                ),
                child: Text(
                  widget.deck.name,
                  style: GoogleFonts.bowlbyOne(fontSize: 14, color: kInk),
                ),
              ),

              // Score badge & controls
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildScoreBadge(_controller.score),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _toggleSound,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: kCream,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: kInk, width: 2.0),
                        boxShadow: kSmallShadow,
                      ),
                      child: Icon(
                        _storage.settings.soundEnabled
                            ? Icons.volume_up_rounded
                            : Icons.volume_off_rounded,
                        size: 20,
                        color: kInk,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      _engine.stop();
                      _controller.pause();
                    },
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: kCream,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: kInk, width: 2.0),
                        boxShadow: kSmallShadow,
                      ),
                      child: const Icon(
                        Icons.pause_rounded,
                        size: 20,
                        color: kInk,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Main Center Area: Huge Centered Word Card taking full stage
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              switchInCurve: Curves.easeOutBack,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) {
                final isEven = _controller.cardIndex % 2 == 0;
                final angle =
                    (isEven ? 0.035 : -0.035) * (1.0 - animation.value);
                return ScaleTransition(
                  scale: animation,
                  child: Transform.rotate(
                    angle: angle,
                    child: child,
                  ),
                );
              },
              child: Container(
                key: ValueKey<String>(
                    '${_controller.cardIndex}_${_controller.currentWord}'),
                margin: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 4),
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 16),
                decoration: BoxDecoration(
                  color: kCream,
                  borderRadius: kAsymmetricRadius,
                  border: Border.all(color: kInk, width: 3.5),
                  boxShadow: kCardShadow,
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
                        style: GoogleFonts.bowlbyOne(
                          fontSize: 56,
                          color: kInk,
                          height: 1.05,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPillTimer(int seconds) {
    final isUrgent = seconds <= 10;
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: isUrgent ? kOrange : kCream,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: kInk, width: 2.0),
        boxShadow: kSmallShadow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isUrgent ? Icons.timer_rounded : Icons.timer_outlined,
            size: 18,
            color: isUrgent ? kCream : kInk,
          ),
          const SizedBox(width: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${seconds}s',
              style: GoogleFonts.bowlbyOne(
                fontSize: 110,
                color: isUrgent ? kCream : kInk,
                shadows: isUrgent
                    ? const [Shadow(color: kInk, offset: Offset(3, 3))]
                    : null,
              ),
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
        color: kYellow,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: kInk, width: 2.0),
        boxShadow: kSmallShadow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('★', style: TextStyle(fontSize: 14, color: kInk)),
          const SizedBox(width: 5),
          Text(
            '$score',
            style: GoogleFonts.bowlbyOne(fontSize: 14, color: kInk),
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
        width: 440,
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          color: kInk,
          borderRadius: kAsymmetricRadius,
          border: Border.all(color: kCream, width: 3.0),
          boxShadow: const [
            BoxShadow(
                color: Color(0xFF0F0A1C),
                offset: Offset(6, 6),
                blurRadius: 0),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: kYellow,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: kInk, width: 2.0),
                boxShadow: kSmallShadow,
              ),
              child: const Icon(
                Icons.pause_rounded,
                size: 26,
                color: kInk,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Game Paused',
              style: GoogleFonts.bowlbyOne(
                fontSize: 26,
                color: kYellow,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Game timer and motion sensors are suspended.',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: kCream,
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _quitToMenu,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: kCream,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: kInk, width: 2.0),
                        boxShadow: kSmallShadow,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Quit to Menu',
                        style: GoogleFonts.bowlbyOne(
                          fontSize: 13,
                          color: kInk,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: GestureDetector(
                    onTap: _resumeFromPause,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: kLime,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: kInk, width: 2.0),
                        boxShadow: kSmallShadow,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Resume',
                        style: GoogleFonts.bowlbyOne(
                          fontSize: 13,
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


