import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/deck.dart';
import '../models/game_round.dart';
import '../services/groq_deck_service.dart';
import '../services/storage_service.dart';
import '../theme/deck_colors.dart';
import 'gameplay_screen.dart';
import 'home_screen.dart';

/// Shows celebration, score breakdown, and tabs for correct vs passed words
/// in pure neo-brutalist styling.
class ResultsScreen extends StatefulWidget {
  final GameRound round;
  final Deck? deck;

  const ResultsScreen({super.key, required this.round, this.deck});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  final StorageService _storage = StorageService();
  int _selectedFilterIndex = 0; // 0 = All, 1 = Correct, 2 = Passed

  late final Deck _resolvedDeck;
  late final bool _isNewHighScore;
  late final int _highScore;

  @override
  void initState() {
    super.initState();
    // Resolve deck
    if (widget.deck != null) {
      _resolvedDeck = widget.deck!;
    } else {
      _resolvedDeck = _storage.allDecks.firstWhere(
        (d) => d.id == widget.round.deckId || d.name == widget.round.deckName,
        orElse: () => Deck.starterDecks.first,
      );
    }

    // High score check
    final otherRounds = _storage.roundHistory.where((r) =>
        r.id != widget.round.id &&
        (r.deckId == widget.round.deckId ||
            r.deckName == widget.round.deckName));

    final prevHighScore = otherRounds.isEmpty
        ? 0
        : otherRounds.map((r) => r.correctCount).reduce(math.max);

    _isNewHighScore = widget.round.correctCount > 0 &&
        widget.round.correctCount > prevHighScore;

    _highScore = math.max(widget.round.correctCount, prevHighScore);
  }

  void _playAgain() {
    Deck deckToPlay = _storage.getDeck(_resolvedDeck.id);
    if (GroqDeckService().hasPrefetchedWords(_resolvedDeck.id)) {
      final prefetched = GroqDeckService().takePrefetchedWords(_resolvedDeck.id);
      if (prefetched != null && prefetched.isNotEmpty) {
        _storage.updateDeckItems(_resolvedDeck.id, prefetched);
        deckToPlay = deckToPlay.copyWith(items: prefetched);
      }
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => GameplayScreen(
          deck: deckToPlay,
          timerSeconds: widget.round.timerDuration,
        ),
      ),
    );
  }

  void _goHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final round = widget.round;
    final deckColor = deckColorFor(_resolvedDeck);

    final filteredAttempts = switch (_selectedFilterIndex) {
      1 => round.correctWords,
      2 => round.passedWords,
      _ => round.attempts,
    };

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: kBlue,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header Row ──
                Row(
                  children: [
                    GestureDetector(
                      onTap: _goHome,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: kInk,
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(color: kInk, width: 2.0),
                          boxShadow: kSmallShadow,
                        ),
                        child: Text(
                          '✕ BACK',
                          style: GoogleFonts.bowlbyOne(
                            fontSize: 13,
                            color: kCream,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Transform.rotate(
                      angle: -2 * math.pi / 180,
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: 'Results',
                              style: GoogleFonts.bowlbyOne(
                                fontSize: 32,
                                color: kCream,
                                height: 0.95,
                              ),
                            ),
                            TextSpan(
                              text: '!',
                              style: GoogleFonts.bowlbyOne(
                                fontSize: 32,
                                color: kYellow,
                                height: 0.95,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: deckColor,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: kInk, width: 2.0),
                        boxShadow: kSmallShadow,
                      ),
                      child: Text(
                        round.deckName,
                        style: GoogleFonts.bowlbyOne(
                          fontSize: 13,
                          color: kInk,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ── Hero Score Card (kInk Fill, kCream Highlights) ──
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 20, horizontal: 18),
                  decoration: BoxDecoration(
                    color: kInk,
                    borderRadius: kAsymmetricRadius,
                    border: Border.all(color: kCream, width: 3.5),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0xFF0F0A1C),
                        offset: Offset(6, 6),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        "Time's Up!",
                        style: GoogleFonts.bowlbyOne(
                          fontSize: 44,
                          color: kYellow,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${round.correctCount}',
                        style: GoogleFonts.bowlbyOne(
                          fontSize: 72,
                          color: kLime,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 8),

                      if (_isNewHighScore) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 5),
                          decoration: BoxDecoration(
                            color: kYellow,
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(color: kInk, width: 2.0),
                            boxShadow: kSmallShadow,
                          ),
                          child: Text(
                            '★ NEW HIGH SCORE ★',
                            style: GoogleFonts.bowlbyOne(
                              fontSize: 12,
                              color: kInk,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Stats row (Correct, Passed, Accuracy, Best)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _StatColumn(
                            value: '${round.correctCount}',
                            label: 'CORRECT',
                            color: kLime,
                            icon: Icons.check_circle_rounded,
                          ),
                          Container(
                            width: 2.0,
                            height: 34,
                            color: kCream.withValues(alpha: 0.25),
                          ),
                          _StatColumn(
                            value: '${round.passedCount}',
                            label: 'PASSED',
                            color: kOrange,
                            icon: Icons.highlight_off_rounded,
                          ),
                          Container(
                            width: 2.0,
                            height: 34,
                            color: kCream.withValues(alpha: 0.25),
                          ),
                          _StatColumn(
                            value: '${round.accuracyPercentage}%',
                            label: 'ACCURACY',
                            color: kCream,
                            icon: Icons.track_changes_rounded,
                          ),
                          Container(
                            width: 2.0,
                            height: 34,
                            color: kCream.withValues(alpha: 0.25),
                          ),
                          _StatColumn(
                            value: '$_highScore',
                            label: 'BEST',
                            color: kYellow,
                            icon: Icons.emoji_events_rounded,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Filter Chips ──
                Row(
                  children: [
                    _ResultFilterChip(
                      label: 'All (${round.totalAttempts})',
                      isSelected: _selectedFilterIndex == 0,
                      onTap: () => setState(() => _selectedFilterIndex = 0),
                    ),
                    const SizedBox(width: 8),
                    _ResultFilterChip(
                      label: 'Correct (${round.correctCount})',
                      isSelected: _selectedFilterIndex == 1,
                      onTap: () => setState(() => _selectedFilterIndex = 1),
                    ),
                    const SizedBox(width: 8),
                    _ResultFilterChip(
                      label: 'Passed (${round.passedCount})',
                      isSelected: _selectedFilterIndex == 2,
                      onTap: () => setState(() => _selectedFilterIndex = 2),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // ── Scrollable Words List ──
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: kCream,
                      borderRadius: kAsymmetricRadius,
                      border: Border.all(color: kInk, width: 3.0),
                      boxShadow: kCardShadow,
                    ),
                    child: filteredAttempts.isEmpty
                        ? Center(
                            child: Text(
                              _selectedFilterIndex == 1
                                  ? 'No correct words this round.'
                                  : _selectedFilterIndex == 2
                                      ? 'No passed words — clean round!'
                                      : 'No words played',
                              style: GoogleFonts.dmSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: kInkDim,
                              ),
                            ),
                          )
                        : ClipRRect(
                            borderRadius: kAsymmetricRadius,
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              itemCount: filteredAttempts.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 8),
                              itemBuilder: (_, index) {
                                final attempt = filteredAttempts[index];
                                final isCorrect =
                                    attempt.result == WordResult.correct;

                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: kAsymmetricSmallRadius,
                                    border: Border.all(color: kInk, width: 2.0),
                                    boxShadow: kSmallShadow,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          color: isCorrect ? kLime : kOrange,
                                          borderRadius:
                                              BorderRadius.circular(99),
                                          border: Border.all(
                                              color: kInk, width: 1.5),
                                        ),
                                        child: Icon(
                                          isCorrect
                                              ? Icons.check_rounded
                                              : Icons.close_rounded,
                                          color: kInk,
                                          size: 16,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          attempt.word,
                                          style: GoogleFonts.dmSans(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: kInk,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isCorrect ? kLime : kOrange,
                                          borderRadius:
                                              BorderRadius.circular(99),
                                          border: Border.all(
                                              color: kInk, width: 1.5),
                                        ),
                                        child: Text(
                                          isCorrect ? '+1 Pt' : 'Pass',
                                          style: GoogleFonts.bowlbyOne(
                                            fontSize: 11,
                                            color: kInk,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 16),

                // ── Action Triggers (Primary CTA: kLime Play Again, Fallback: Underlined Back to Decks) ──
                GestureDetector(
                  onTap: _playAgain,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: kLime,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: kInk, width: 2.5),
                      boxShadow: const [
                        BoxShadow(
                            color: kInk, offset: Offset(4, 4), blurRadius: 0),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.replay_rounded, color: kInk, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'PLAY AGAIN',
                          style: GoogleFonts.bowlbyOne(
                            fontSize: 16,
                            color: kInk,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                Center(
                  child: GestureDetector(
                    onTap: _goHome,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        'Back to decks',
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: kCream,
                          decoration: TextDecoration.underline,
                          decorationColor: kCream,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  final IconData icon;

  const _StatColumn({
    required this.value,
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              value,
              style: GoogleFonts.bowlbyOne(
                fontSize: 20,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: kCream.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}

class _ResultFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ResultFilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? kYellow : kCream,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: kInk, width: 2.0),
            boxShadow: isSelected ? kSmallShadow : null,
          ),
          child: Text(
            label,
            style: GoogleFonts.bowlbyOne(
              fontSize: 11,
              color: kInk,
            ),
          ),
        ),
      ),
    );
  }
}
