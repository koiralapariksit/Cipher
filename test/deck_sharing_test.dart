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
    test('enforces max 2 pinned decks on togglePin and init', () async {
      final storage = StorageService();
      await storage.init(force: true);

      // Clear any pinned decks
      for (final id in storage.pinnedDeckIds.toList()) {
        await storage.togglePin(id);
      }
      expect(storage.pinnedDeckIds, isEmpty);

      // 1. Pin 1st deck
      final res1 = await storage.togglePin('animals');
      expect(res1, isTrue);
      expect(storage.pinnedDeckIds.length, 1);
      expect(storage.isPinned('animals'), isTrue);

      // 2. Pin 2nd deck
      final res2 = await storage.togglePin('movies_tv');
      expect(res2, isTrue);
      expect(storage.pinnedDeckIds.length, 2);
      expect(storage.isPinned('movies_tv'), isTrue);

      // 3. Attempt to pin 3rd deck -> must be rejected
      final res3 = await storage.togglePin('sports');
      expect(res3, isFalse);
      expect(storage.pinnedDeckIds.length, 2);
      expect(storage.isPinned('sports'), isFalse);

      // 4. Unpin animals -> succeeds
      final res4 = await storage.togglePin('animals');
      expect(res4, isTrue);
      expect(storage.pinnedDeckIds.length, 1);
      expect(storage.isPinned('animals'), isFalse);

      // 5. Pin sports now that a slot opened -> succeeds
      final res5 = await storage.togglePin('sports');
      expect(res5, isTrue);
      expect(storage.pinnedDeckIds.length, 2);
      expect(storage.isPinned('sports'), isTrue);
    });

    test('truncates to max 2 pinned if storage has > 2', () async {
      SharedPreferences.setMockInitialValues({
        'pinned_deck_ids_v2': ['animals', 'movies_tv', 'sports', 'food_drinks'],
      });

      final storage = StorageService();
      await storage.init(force: true);

      expect(storage.pinnedDeckIds.length, 2);
      expect(storage.pinnedDeckIds, containsAll(['animals', 'movies_tv']));
    });
  });

  group('Unlimited Favorites & 3-Tier Priority Sorting', () {
    test('allows unlimited favorite decks', () async {
      final storage = StorageService();
      await storage.init(force: true);

      // Clear favorites
      for (final id in storage.favoriteDeckIds.toList()) {
        await storage.toggleFavorite(id);
      }
      expect(storage.favoriteDeckIds, isEmpty);

      // Add 4 favorites
      expect(await storage.toggleFavorite('animals'), isTrue);
      expect(await storage.toggleFavorite('movies_tv'), isTrue);
      expect(await storage.toggleFavorite('sports'), isTrue);
      expect(await storage.toggleFavorite('food_drinks'), isTrue);

      expect(storage.favoriteDeckIds.length, 4);
      expect(storage.isFavorite('food_drinks'), isTrue);
    });

    test('sortDecks orders: Pinned (Tier 1) -> Favorites (Tier 2) -> Standard (Tier 3)', () async {
      final storage = StorageService();
      await storage.init(force: true);

      // Clear both sets
      for (final id in storage.pinnedDeckIds.toList()) {
        await storage.togglePin(id);
      }
      for (final id in storage.favoriteDeckIds.toList()) {
        await storage.toggleFavorite(id);
      }

      // Pin 'sports' (Tier 1)
      await storage.togglePin('sports');

      // Favorite 'food_drinks' and 'animals' (Tier 2)
      await storage.toggleFavorite('food_drinks');
      await storage.toggleFavorite('animals');

      // Standard remaining: 'celebrities', 'countries', 'movies_tv' (Tier 3)
      final sorted = storage.sortDecks(Deck.starterDecks);

      // Verify Tier 1: Pinned
      expect(sorted[0].id, 'sports');

      // Verify Tier 2: Favorites sorted alphabetically ('animals' before 'food_drinks')
      expect(sorted[1].id, 'animals');
      expect(sorted[2].id, 'food_drinks');

      // Verify Tier 3: Standard sorted alphabetically ('celebrities', 'countries', 'movies_tv')
      expect(sorted[3].id, 'celebrities');
      expect(sorted[4].id, 'countries');
      expect(sorted[5].id, 'movies_tv');
    });
  });

  group('StorageService Invert Tilt Default & Long Title Deck Handling', () {
    test('fresh StorageService initializes invertTilt to true', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init(force: true);

      expect(storage.settings.invertTilt, isTrue);
    });

    test('custom deck with very long title stores and retrieves properly', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init(force: true);

      const longTitleDeck = Deck(
        id: 'custom_long_title',
        name: '60s-90s POPULAR SONGS - MJ, QUEEN, BEATLES, MADONNA, ELTON JOHN',
        emoji: '',
        colorValue: 0xFF2F5BFF,
        category: 'Pop Culture',
        isCustom: true,
        items: ['Thriller', 'Bohemian Rhapsody', 'Hey Jude', 'Like a Prayer'],
      );

      await storage.saveCustomDeck(longTitleDeck);
      final retrieved = storage.customDecks.firstWhere((d) => d.id == 'custom_long_title');
      expect(retrieved.name, contains('60s-90s POPULAR SONGS'));
    });
  });
}

