import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/deck.dart';
import '../models/game_round.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: appBgBottom,
        body: Container(
          decoration: appBackgroundDecoration,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header Row ──
                  Row(
                    children: [
                      AppIconButton(
                        icon: Icons.arrow_back_rounded,
                        tooltip: 'Back to Decks',
                        size: 40,
                        onTap: _goHome,
                      ),
                      const SizedBox(width: 14),
                      Text(
                        'Round Complete',
                        style: appFont(24,
                            weight: FontWeight.w700, spacing: -0.6),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: appTile,
                          borderRadius: BorderRadius.circular(appRadius),
                          border: Border.all(color: appLine, width: 0.8),
                        ),
                        child: Text(
                          round.deckName,
                          style: appFont(13,
                              weight: FontWeight.w600, color: appText),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ── Hero Score Card ──
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        vertical: 18, horizontal: 16),
                    decoration: BoxDecoration(
                      color: appTile,
                      borderRadius: BorderRadius.circular(appRadius),
                      border: Border.all(color: appLine, width: 0.8),
                    ),
                    child: Column(
                      children: [
                        if (_isNewHighScore) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: appField,
                              borderRadius: BorderRadius.circular(appRadius),
                              border: Border.all(
                                color: appLine,
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.emoji_events_rounded,
                                    color: appText, size: 14),
                                const SizedBox(width: 6),
                                Text(
                                  'NEW HIGH SCORE',
                                  style: appFont(11,
                                      weight: FontWeight.w600,
                                      spacing: 0.8,
                                      color: appText),
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
                              color: appCorrect,
                              icon: Icons.check_circle_outline_rounded,
                            ),
                            Container(
                              width: 0.8,
                              height: 38,
                              color: appLine,
                            ),
                            _StatColumn(
                              value: '${round.passedCount}',
                              label: 'PASSED',
                              color: appPass,
                              icon: Icons.highlight_off_rounded,
                            ),
                            Container(
                              width: 0.8,
                              height: 38,
                              color: appLine,
                            ),
                            _StatColumn(
                              value: '${round.accuracyPercentage}%',
                              label: 'ACCURACY',
                              color: appText,
                              icon: Icons.track_changes_rounded,
                            ),
                            Container(
                              width: 0.8,
                              height: 38,
                              color: appLine,
                            ),
                            _StatColumn(
                              value: '$_highScore',
                              label: 'BEST',
                              color: appText,
                              icon: Icons.emoji_events_outlined,
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
                        accentColor: appCorrect,
                        onTap: () => setState(() => _selectedFilterIndex = 1),
                      ),
                      const SizedBox(width: 8),
                      _ResultFilterChip(
                        label: 'Passed (${round.passedCount})',
                        isSelected: _selectedFilterIndex == 2,
                        accentColor: appPass,
                        onTap: () => setState(() => _selectedFilterIndex = 2),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // ── Section Header ──
                  AppSectionHeader(
                    title: 'Words Played',
                    trailing: '${filteredAttempts.length} shown',
                  ),

                  const SizedBox(height: 10),

                  // ── Scrollable Words List ──
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: appTile,
                        borderRadius: BorderRadius.circular(appRadius),
                        border: Border.all(color: appLine, width: 0.8),
                      ),
                      child: filteredAttempts.isEmpty
                          ? Center(
                              child: Text(
                                _selectedFilterIndex == 1
                                    ? 'No correct words this round.'
                                    : _selectedFilterIndex == 2
                                        ? 'No passed words — clean round!'
                                        : 'No words played',
                                style: appFont(14, color: appTextDim),
                              ),
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(appRadius),
                              child: ListView.separated(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                itemCount: filteredAttempts.length,
                                separatorBuilder: (_, _) => const Divider(
                                  height: 1,
                                  color: appLine,
                                ),
                                itemBuilder: (_, index) {
                                  final attempt = filteredAttempts[index];
                                  final isCorrect =
                                      attempt.result == WordResult.correct;
                                  final color =
                                      isCorrect ? appCorrect : appPass;

                                  return ListTile(
                                    dense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 2),
                                    leading: Container(
                                      width: 26,
                                      height: 26,
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(appRadius),
                                        color: color.withValues(alpha: 0.15),
                                        border: Border.all(
                                          color: color.withValues(alpha: 0.5),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Icon(
                                        isCorrect
                                            ? Icons.check_rounded
                                            : Icons.close_rounded,
                                        color: color,
                                        size: 15,
                                      ),
                                    ),
                                    title: Text(
                                      attempt.word,
                                      style: appFont(15,
                                          weight: FontWeight.w500,
                                          color: appText),
                                    ),
                                    trailing: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isCorrect
                                            ? color.withValues(alpha: 0.15)
                                            : appField,
                                        borderRadius:
                                            BorderRadius.circular(appRadius),
                                        border: Border.all(
                                          color: isCorrect
                                              ? color.withValues(alpha: 0.4)
                                              : appLine,
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Text(
                                        isCorrect ? '+1 Point' : 'Pass',
                                        style: appFont(
                                          11,
                                          weight: FontWeight.w600,
                                          color: isCorrect ? color : appTextDim,
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
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            decoration: BoxDecoration(
                              color: appTile,
                              borderRadius: BorderRadius.circular(appRadius),
                              border: Border.all(color: appLine, width: 0.8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.grid_view_rounded,
                                    color: appTextDim, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'ALL DECKS',
                                  style: appFont(
                                    13,
                                    weight: FontWeight.w600,
                                    spacing: 0.5,
                                    color: appTextDim,
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
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            decoration: BoxDecoration(
                              color: appText,
                              borderRadius: BorderRadius.circular(appRadius),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.replay_rounded,
                                    color: appBgBottom, size: 19),
                                const SizedBox(width: 8),
                                Text(
                                  'PLAY AGAIN',
                                  style: appFont(
                                    14,
                                    weight: FontWeight.w600,
                                    spacing: 0.5,
                                    color: appBgBottom,
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
              style: appFont(
                22,
                weight: FontWeight.w700,
                color: color,
                spacing: -0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: appFont(
            10,
            weight: FontWeight.w600,
            spacing: 0.8,
            color: appTextDim,
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
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? appText : appTile,
            borderRadius: BorderRadius.circular(appRadius),
            border: isSelected
                ? null
                : Border.all(color: appLine, width: 0.8),
          ),
          child: Text(
            label,
            style: appFont(
              12,
              weight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected ? appBgBottom : appTextDim,
            ),
          ),
        ),
      ),
    );
  }
}
