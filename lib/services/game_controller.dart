import 'dart:async';
import '../models/deck.dart';
import '../models/game_round.dart';

/// Possible states of the game controller.
enum GamePhase { idle, countdown, playing, paused, finished }

/// Manages game state: countdown, timer, pause/resume, word cycling, scoring.
class GameController {
  final Deck deck;
  final int timerSeconds;

  GameController({required this.deck, required this.timerSeconds});

  // ── State ──────────────────────────────────────────────────────────────
  GamePhase _phase = GamePhase.idle;
  GamePhase get phase => _phase;

  GamePhase _phaseBeforePause = GamePhase.countdown;

  late List<String> _words;
  int _wordIndex = 0;

  int _countdownValue = 3;
  int get countdownValue => _countdownValue;

  int _timeRemaining = 0;
  int get timeRemaining => _timeRemaining;

  String get currentWord =>
      (_phase == GamePhase.playing || _phase == GamePhase.paused)
          ? (_wordIndex < _words.length ? _words[_wordIndex] : '')
          : '';

  final List<WordAttempt> _attempts = [];
  int _score = 0;
  int get score => _score;

  Timer? _timer;
  bool _isFinished = false;

  // ── Callbacks ──────────────────────────────────────────────────────────
  /// Called on every state change so the UI can rebuild.
  void Function()? onStateChanged;

  /// Called on countdown tick (3, 2, 1) for haptic feedback.
  void Function(int count)? onCountdownTick;

  /// Called when the game finishes.
  void Function(GameRound round)? onGameFinished;

  // ── Lifecycle ──────────────────────────────────────────────────────────

  /// Start the pre-round countdown, then the game.
  void start() {
    _words = deck.shuffledItems;
    _wordIndex = 0;
    _score = 0;
    _attempts.clear();
    _isFinished = false;
    _countdownValue = 3;
    _phase = GamePhase.countdown;
    onStateChanged?.call();
    onCountdownTick?.call(3);

    _startCountdownTimer();
  }

  void _startCountdownTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _countdownValue--;
      if (_countdownValue <= 0) {
        _timer?.cancel();
        _beginPlaying();
      } else {
        onCountdownTick?.call(_countdownValue);
      }
      onStateChanged?.call();
    });
  }

  void _beginPlaying() {
    _timeRemaining = timerSeconds;
    _phase = GamePhase.playing;
    onStateChanged?.call();

    _startPlayingTimer();
  }

  void _startPlayingTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _timeRemaining--;
      if (_timeRemaining <= 0) {
        _finishGame();
      }
      onStateChanged?.call();
    });
  }

  /// Pause countdown or active timer when app is minimized or backgrounded.
  void pause() {
    if (_phase == GamePhase.finished || _phase == GamePhase.paused) return;
    _phaseBeforePause = _phase;
    _timer?.cancel();
    _phase = GamePhase.paused;
    onStateChanged?.call();
  }

  /// Resume from paused state.
  void resume() {
    if (_phase != GamePhase.paused) return;
    _phase = _phaseBeforePause;
    onStateChanged?.call();

    if (_phase == GamePhase.countdown) {
      _startCountdownTimer();
    } else if (_phase == GamePhase.playing) {
      _startPlayingTimer();
    }
  }

  /// Record the current word as correct and advance.
  void markCorrect() {
    if (_phase != GamePhase.playing || _isFinished) return;
    _attempts.add(WordAttempt(word: currentWord, result: WordResult.correct));
    _score++;
    _advance();
  }

  /// Record the current word as passed and advance.
  void markPass() {
    if (_phase != GamePhase.playing || _isFinished) return;
    _attempts.add(WordAttempt(word: currentWord, result: WordResult.passed));
    _advance();
  }

  void _advance() {
    _wordIndex++;
    if (_wordIndex >= _words.length) {
      // Reshuffle and loop to avoid running out
      _words.shuffle();
      _wordIndex = 0;
    }
    onStateChanged?.call();
  }

  void _finishGame() {
    if (_isFinished) return;
    _isFinished = true;
    _timer?.cancel();
    _phase = GamePhase.finished;
    final round = GameRound(
      deckId: deck.id,
      deckName: deck.name,
      timerDuration: timerSeconds,
      attempts: List.unmodifiable(_attempts),
    );
    onStateChanged?.call();
    onGameFinished?.call(round);
  }

  /// Clean up.
  void dispose() {
    _timer?.cancel();
  }
}
