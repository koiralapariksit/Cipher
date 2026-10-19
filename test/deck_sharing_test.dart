import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:heads_guess/models/deck.dart';
import 'package:heads_guess/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('Deck Base64 Export and Import Round-Trip', () async {
    final storage = StorageService();
    await storage.init();

    // 1. Create a custom deck
    const originalDeck = Deck(
      id: 'custom_test_123',
      name: 'Anime & Manga',
      emoji: '⚡',
      colorValue: 0xFFC8A45C,
      category: 'Pop Culture',
      isCustom: true,
      items: ['Naruto', 'One Piece', 'Attack on Titan', 'Dragon Ball', 'Death Note'],
    );

    // 2. Export to Base64 (same logic as DeckEditorScreen)
    final base64Code = base64Encode(utf8.encode(jsonEncode(originalDeck.toJson())));
    expect(base64Code, isNotEmpty);

    // 3. Import from Base64 (same logic as AiDeckGeneratorScreen)
    String jsonString = base64Code.trim();
    if (!jsonString.startsWith('{') && !jsonString.startsWith('[')) {
      final decodedBytes = base64Decode(jsonString);
      jsonString = utf8.decode(decodedBytes);
    }

    final data = jsonDecode(jsonString) as Map<String, dynamic>;
    final importedDeck = Deck.fromJson(data).copyWith(
      id: 'custom_imported_456',
      isCustom: true,
    );

    expect(importedDeck.name, 'Anime & Manga');
    expect(importedDeck.emoji, '⚡');
    expect(importedDeck.items.length, 5);
    expect(importedDeck.items, contains('Attack on Titan'));

    // 4. Save via storage.saveCustomDeck
    await storage.saveCustomDeck(importedDeck);
    expect(storage.customDecks.any((d) => d.id == 'custom_imported_456'), isTrue);
  });

  group('6 Emoji-Free Starter Decks Validation', () {
    test('contains exactly 6 starter decks with emoji stripped', () {
      final decks = Deck.starterDecks;
      expect(decks.length, 6);

      final expectedIds = [
        'animals',
        'movies_tv',
        'food_drinks',
        'sports',
        'countries',
        'celebrities',
      ];

      final expectedCategories = {
        'animals': 'Nature',
        'movies_tv': 'Entertainment',
        'food_drinks': 'Lifestyle',
        'sports': 'Actions',
        'countries': 'World',
        'celebrities': 'Entertainment',
      };

      for (int i = 0; i < decks.length; i++) {
        final d = decks[i];
        expect(d.id, expectedIds[i]);
        expect(d.emoji, '', reason: 'Deck ${d.name} must have empty emoji string');
        expect(d.category, expectedCategories[d.id]);
        expect(d.items.length, inInclusiveRange(40, 50),
            reason: 'Deck ${d.name} must have 40 to 50 curated items');
      }
    });
  });

  group('Strict Max-2 Pinned Decks Enforcement', () {
    test('enforces max 2 pinned decks on toggleFavorite and init', () async {
      final storage = StorageService();
      await storage.init();

      // Clear any favorites
      for (final id in storage.favoriteDeckIds.toList()) {
        await storage.toggleFavorite(id);
      }
      expect(storage.favoriteDeckIds, isEmpty);

      // 1. Pin 1st deck
      final res1 = await storage.toggleFavorite('animals');
      expect(res1, isTrue);
      expect(storage.favoriteDeckIds.length, 1);
      expect(storage.isFavorite('animals'), isTrue);

      // 2. Pin 2nd deck
      final res2 = await storage.toggleFavorite('movies_tv');
      expect(res2, isTrue);
      expect(storage.favoriteDeckIds.length, 2);
      expect(storage.isFavorite('movies_tv'), isTrue);

      // 3. Attempt to pin 3rd deck -> must be rejected
      final res3 = await storage.toggleFavorite('sports');
      expect(res3, isFalse);
      expect(storage.favoriteDeckIds.length, 2);
      expect(storage.isFavorite('sports'), isFalse);

      // 4. Unpin animals -> succeeds
      final res4 = await storage.toggleFavorite('animals');
      expect(res4, isTrue);
      expect(storage.favoriteDeckIds.length, 1);
      expect(storage.isFavorite('animals'), isFalse);

      // 5. Pin sports now that a slot opened -> succeeds
      final res5 = await storage.toggleFavorite('sports');
      expect(res5, isTrue);
      expect(storage.favoriteDeckIds.length, 2);
      expect(storage.isFavorite('sports'), isTrue);
    });

    test('truncates to max 2 favorites if legacy storage has > 2', () async {
      SharedPreferences.setMockInitialValues({
        'favorite_deck_ids_v2': ['animals', 'movies_tv', 'sports', 'food_drinks'],
      });

      final storage = StorageService();
      await storage.init(force: true);

      expect(storage.favoriteDeckIds.length, 2);
      expect(storage.favoriteDeckIds, containsAll(['animals', 'movies_tv']));
    });
  });
}

