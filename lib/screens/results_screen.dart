import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/deck.dart';
import '../models/game_round.dart';
import '../services/storage_service.dart';
import '../theme/luxury_theme.dart';
import 'gameplay_screen.dart';
import 'home_screen.dart';

/// Shows celebration, score breakdown, and tabs for correct vs passed words.
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
        (r.deckId == widget.round.deckId || r.deckName == widget.round.deckName));

    final prevHighScore = otherRounds.isEmpty
        ? 0
        : otherRounds.map((r) => r.correctCount).reduce(math.max);

    _isNewHighScore =
        widget.round.correctCount > 0 && widget.round.correctCount > prevHighScore;

    _highScore = math.max(widget.round.correctCount, prevHighScore);
  }

  void _playAgain() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => GameplayScreen(
          deck: _resolvedDeck,
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

    final filteredAttempts = switch (_selectedFilterIndex) {
      1 => round.correctWords,
      2 => round.passedWords,
      _ => round.attempts,
    };

    return Scaffold(
      backgroundColor: kBlack,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header Row ──
              Row(
                children: [
                  LuxuryRoundButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Back to Decks',
                    onTap: _goHome,
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'Round Complete',
                    style: luxuryFont(26, weight: FontWeight.w300, spacing: 0.5),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: luxuryPanel(radius: 8),
                    child: Text(
                      round.deckName,
                      style: luxuryFont(13,
                          weight: FontWeight.w500, color: kGold),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ── Hero Score Card ──
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                decoration: luxuryPanel(radius: 8, highlight: true),
                child: Column(
                  children: [
                    if (_isNewHighScore) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: kSelectedFill,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: kGold.withValues(alpha: 0.8),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.emoji_events_rounded,
                                color: kGold, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              'NEW HIGH SCORE',
                              style: luxuryFont(11,
                                  weight: FontWeight.w500,
                                  spacing: 1.4,
                                  color: kGold),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _StatColumn(
                          value: '${round.correctCount}',
                          label: 'CORRECT',
                          color: kCorrectGreen,
                          icon: Icons.check_circle_outline_rounded,
                        ),
                        Container(
                          width: 0.8,
                          height: 38,
                          color: kGold.withValues(alpha: 0.25),
                        ),
                        _StatColumn(
                          value: '${round.passedCount}',
                          label: 'PASSED',
                          color: kPassAmber,
                          icon: Icons.highlight_off_rounded,
                        ),
                        Container(
                          width: 0.8,
                          height: 38,
                          color: kGold.withValues(alpha: 0.25),
                        ),
                        _StatColumn(
                          value: '${round.accuracyPercentage}%',
                          label: 'ACCURACY',
                          color: kGold,
                          icon: Icons.track_changes_rounded,
                        ),
                        Container(
                          width: 0.8,
                          height: 38,
                          color: kGold.withValues(alpha: 0.25),
                        ),
                        _StatColumn(
                          value: '$_highScore',
                          label: 'BEST',
                          color: kGold,
                          icon: Icons.emoji_events_outlined,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

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
                    accentColor: kCorrectGreen,
                    onTap: () => setState(() => _selectedFilterIndex = 1),
                  ),
                  const SizedBox(width: 8),
                  _ResultFilterChip(
                    label: 'Passed (${round.passedCount})',
                    isSelected: _selectedFilterIndex == 2,
                    accentColor: kPassAmber,
                    onTap: () => setState(() => _selectedFilterIndex = 2),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // ── Section Header ──
              LuxurySectionHeader(
                title: 'Words Played',
                trailing: '${filteredAttempts.length} shown',
              ),

              const SizedBox(height: 10),

              // ── Scrollable Words List ──
              Expanded(
                child: Container(
                  decoration: luxuryPanel(radius: 8),
                  child: filteredAttempts.isEmpty
                      ? Center(
                          child: Text(
                            _selectedFilterIndex == 1
                                ? 'No correct words this round.'
                                : _selectedFilterIndex == 2
                                    ? 'No passed words — clean round!'
                                    : 'No words played',
                            style: luxuryFont(14, color: kTextDim),
                          ),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            itemCount: filteredAttempts.length,
                            separatorBuilder: (_, _) => Divider(
                              height: 1,
                              color: kGold.withValues(alpha: 0.12),
                            ),
                            itemBuilder: (_, index) {
                              final attempt = filteredAttempts[index];
                              final isCorrect =
                                  attempt.result == WordResult.correct;
                              final color =
                                  isCorrect ? kCorrectGreen : kPassAmber;

                              return ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 2),
                                leading: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(6),
                                    color: color.withValues(alpha: 0.12),
                                    border: Border.all(
                                      color: color.withValues(alpha: 0.45),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Icon(
                                    isCorrect
                                        ? Icons.check_rounded
                                        : Icons.close_rounded,
                                    color: color,
                                    size: 16,
                                  ),
                                ),
                                title: Text(
                                  attempt.word,
                                  style: luxuryFont(15,
                                      weight: FontWeight.w400, color: kText),
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isCorrect
                                        ? color.withValues(alpha: 0.12)
                                        : Colors.white.withValues(alpha: 0.04),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: isCorrect
                                            ? color.withValues(alpha: 0.4)
                                          : Colors.white10,
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Text(
                                    isCorrect ? '+1 Point' : 'Pass',
                                    style: luxuryFont(
                                      11,
                                      weight: FontWeight.w500,
                                      color: isCorrect ? color : kTextDim,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 16),

              // ── Bottom Action Buttons ──
              Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: GestureDetector(
                      onTap: _goHome,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: luxuryPanel(radius: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.grid_view_rounded,
                                color: kTextDim, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'ALL DECKS',
                              style: luxuryFont(
                                13,
                                weight: FontWeight.w500,
                                spacing: 1.0,
                                color: kTextDim,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 6,
                    child: GestureDetector(
                      onTap: _playAgain,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: luxuryPanel(
                          radius: 8,
                          highlight: true,
                          fillTop: const Color(0xFF241F14),
                          fillBottom: const Color(0xFF14110A),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.replay_rounded,
                                color: kGold, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'PLAY AGAIN',
                              style: luxuryFont(
                                14,
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
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 5),
            Text(
              value,
              style: luxuryFont(
                22,
                weight: FontWeight.w400,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: luxuryFont(
            10,
            weight: FontWeight.w500,
            spacing: 1.2,
            color: kTextDim,
          ),
        ),
      ],
    );
  }
}

class _ResultFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color? accentColor;
  final VoidCallback onTap;

  const _ResultFilterChip({
    required this.label,
    required this.isSelected,
    this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = accentColor ?? kGold;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? kSelectedFill : const Color(0xFF101010),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected
                  ? activeColor.withValues(alpha: 0.85)
                  : Colors.white.withValues(alpha: 0.08),
              width: isSelected ? 1.0 : 0.8,
            ),
          ),
          child: Text(
            label,
            style: luxuryFont(
              12,
              weight: FontWeight.w500,
              color: isSelected ? activeColor : kTextDim,
            ),
          ),
        ),
      ),
    );
  }
}
