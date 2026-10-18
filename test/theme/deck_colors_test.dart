import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heads_guess/models/deck.dart';
import 'package:heads_guess/theme/deck_colors.dart';

void main() {
  group('DeckColors Tests', () {
    test('kInk and kCream match neo-brutalist definitions', () {
      expect(kInk, const Color(0xFF1A1230));
      expect(kCream, const Color(0xFFFFF6E3));
      expect(kDeckColors.length, 5);
    });

    test('deckColorFor is deterministic for the same deck id', () {
      const deckA = Deck(
        id: 'movies-123',
        name: 'Movies',
        emoji: '🎬',
        category: 'Pop Culture',
        colorValue: 0xFF123456,
        items: ['Titanic', 'Avatar'],
      );

      final color1 = deckColorFor(deckA);
      final color2 = deckColorFor(deckA);

      expect(color1, equals(color2));
      expect(kDeckColors.contains(color1), isTrue);
    });

    test('deckColorFor hashes codeUnits deterministically', () {
      const deck1 = Deck(
        id: 'a', // codeUnits = [97], 97 % 5 = 2 -> Color(0xFFC9B6FF)
        name: 'A',
        emoji: '⭐',
        category: 'Test',
        colorValue: 0,
        items: [],
      );

      const deck2 = Deck(
        id: 'b', // codeUnits = [98], 98 % 5 = 3 -> Color(0xFFFFD60A)
        name: 'B',
        emoji: '⭐',
        category: 'Test',
        colorValue: 0,
        items: [],
      );

      expect(deckColorFor(deck1), const Color(0xFFC9B6FF));
      expect(deckColorFor(deck2), const Color(0xFFFFD60A));
    });
  });
}

