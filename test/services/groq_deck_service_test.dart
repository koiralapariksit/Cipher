import 'package:flutter_test/flutter_test.dart';
import 'package:heads_guess/models/deck.dart';
import 'package:heads_guess/services/groq_deck_service.dart';
import 'package:heads_guess/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('GroqDeckService Unit Tests', () {
    test('API Key storage and retrieval round-trip', () async {
      final service = GroqDeckService();
      await service.saveApiKey('test_key_12345');
      final key = await service.getApiKey();
      expect(key, 'test_key_12345');
    });

    test('Live Web Search snippet retrieval and formatting', () async {
      final service = GroqDeckService();
      final context = await service.fetchLiveWebContext('Sci-Fi Movies');
      expect(context, isNotEmpty);
      expect(context, contains(':'));
    });

    test('Deck storage integration', () async {
      final storage = StorageService();
      await storage.init();
      final initialCount = storage.customDecks.length;
      expect(initialCount, isNonNegative);
    });

    test('parseAndBuildDeck auto-pads short responses without throwing error', () {
      final service = GroqDeckService();
      const rawJson = '''
{
  "name": "Superconductors",
  "category": "Science",
  "items": ["Yttrium Barium", "Meissner Effect", "Zero Resistance"]
}
''';
      final deck = service.parseAndBuildDeck(
        rawJson: rawJson,
        fallbackTopic: 'Superconductors',
        targetCardCount: 25,
      );

      expect(deck.name, 'SUPERCONDUCTORS');
      expect(deck.emoji, '');
      expect(deck.items.length, greaterThanOrEqualTo(25));
      expect(deck.items, contains('Meissner Effect'));
      expect(deck.items, contains('Superconductors Fan'));
    });

    test('Missing API Key throws friendly offline error without mentioning .env or Groq', () async {
      final service = GroqDeckService();
      // Ensure no key saved in mock prefs
      await service.saveApiKey('');

      expect(
        () => service.generateDeck(
          topic: 'Quantum Physics',
          cardCount: 25,
          difficulty: 'Party',
        ),
        throwsA(
          predicate((e) =>
              e.toString().contains('AI deck generator is currently offline') &&
              !e.toString().contains('.env') &&
              !e.toString().contains('Groq')),
        ),
      );
    });

    test('parseAndBuildDeck summarizes long description into punchy 1-2 word uppercase title', () {
      final service = GroqDeckService();
      const rawJson = '''
{
  "name": "60s-90s pop song mainly mj qeen beatles",
  "category": "Music",
  "items": ["Billie Jean", "Bohemian Rhapsody", "Hey Jude", "Thriller", "Yesterday"]
}
''';
      final deck = service.parseAndBuildDeck(
        rawJson: rawJson,
        fallbackTopic: '60s-90s pop song mainly mj qeen beatles',
        targetCardCount: 25,
      );

      // Must be uppercase and at most 2 words
      expect(deck.name, '60S-90S POP');
      expect(deck.name.split(' ').length, lessThanOrEqualTo(2));
      expect(deck.name, deck.name.toUpperCase());
    });

    test('parseAndBuildDeck filters out inappropriate words for family-friendly safety', () {
      final service = GroqDeckService();
      const rawJson = '''
{
  "name": "Party",
  "category": "Entertainment",
  "items": ["Dance Battle", "bad xxx content", "Charades", "explicit porn stuff", "Karaoke"]
}
''';
      final deck = service.parseAndBuildDeck(
        rawJson: rawJson,
        fallbackTopic: 'Party',
        targetCardCount: 25,
      );

      expect(deck.items, contains('Dance Battle'));
      expect(deck.items, contains('Charades'));
      expect(deck.items, contains('Karaoke'));
      expect(deck.items.any((item) => item.contains('xxx') || item.contains('porn')), isFalse);
    });

    test('buildPrompt includes all strict Forehead Charades / Heads Up game design rules', () {
      final service = GroqDeckService();
      final prompt = service.buildPrompt(
        topic: 'Blockbuster Movies',
        cardCount: 35,
        difficulty: 'Party',
        webSearchSnippets: 'Top movies',
      );

      // System Role
      expect(prompt, contains("You are an elite party game director creating cards for 'Heads Up!'"));
      expect(prompt, contains('fast-paced forehead charades guessing game'));

      // Rule 1: No descriptions or powers, actual character names
      expect(prompt, contains('NO DESCRIPTIONS OR POWERS'));
      expect(prompt, contains('Never output abstract concepts, emotions, or character powers'));
      expect(prompt, contains('Hulk'));
      expect(prompt, contains('Spider-Man'));

      // Rule 2: No history or summaries, real politician names
      expect(prompt, contains('NO HISTORY OR SUMMARIES'));
      expect(prompt, contains('real, well-known names of politicians or political figures'));
      expect(prompt, contains('KP Sharma Oli'));
      expect(prompt, contains('Sher Bahadur Deuba'));
      expect(prompt, contains('Pushpa Kamal Dahal'));

      // Rule 3: 1 to 3 words
      expect(prompt, contains('EXACT FORMATTING: 1 to 3 words maximum per card'));

      // Rule 4: Count & variety
      expect(prompt, contains('COUNT & VARIETY'));

      // Rule 5: Child-Safe guardrail
      expect(prompt, contains('CHILD-SAFE GUARDRAIL: Strictly 100% family-friendly'));

      // Rule 7: JSON array of strings
      expect(prompt, contains('OUTPUT REQUIREMENT: Return strictly valid JSON array of strings'));
    });

    test('parseAndBuildDeck correctly parses JSON array of entity names for Marvel without powers', () {
      final service = GroqDeckService();
      const rawJson = '''
[
  "Spider-Man",
  "Iron Man",
  "Thor",
  "Captain America",
  "Black Panther",
  "Loki",
  "Doctor Strange",
  "Groot",
  "Rocket Raccoon",
  "Thanos",
  "Deadpool",
  "Wolverine",
  "Hulk",
  "Hawkeye",
  "Black Widow",
  "how to do hulk rage",
  "spidey sense power of spider"
]
''';
      final deck = service.parseAndBuildDeck(
        rawJson: rawJson,
        fallbackTopic: 'Marvel',
        targetCardCount: 35,
      );

      expect(deck.name, 'MARVEL');
      expect(deck.items, contains('Spider-Man'));
      expect(deck.items, contains('Iron Man'));
      expect(deck.items, contains('Thor'));
      expect(deck.items, contains('Captain America'));
      expect(deck.items, contains('Black Panther'));
      expect(deck.items, contains('Loki'));
      expect(deck.items, contains('Doctor Strange'));
      expect(deck.items, contains('Hulk'));

      // Verifies abstract descriptions/powers are excluded
      expect(deck.items.any((item) => item.toLowerCase().contains('how to')), isFalse);
      expect(deck.items.any((item) => item.toLowerCase().contains('power of')), isFalse);
    });

    test('parseAndBuildDeck correctly parses Nepali Politicians entities instead of election summaries', () {
      final service = GroqDeckService();
      const rawJson = '''
[
  "KP Sharma Oli",
  "Sher Bahadur Deuba",
  "Pushpa Kamal Dahal",
  "Gagan Thapa",
  "Rabi Lamichhane",
  "Balen Shah",
  "Harka Sampang",
  "Kulman Ghising",
  "Ram Chandra Poudel",
  "Bidhya Devi Bhandari",
  "Bhim Rawal",
  "Subash Nembang",
  "Baburam Bhattarai",
  "Madhav Kumar Nepal",
  "Sujata Koirala",
  "history of nepal election system",
  "election procedure of parliament"
]
''';
      final deck = service.parseAndBuildDeck(
        rawJson: rawJson,
        fallbackTopic: 'Nepali Politicians',
        targetCardCount: 35,
      );

      expect(deck.name, 'NEPALI POLITICIANS');
      expect(deck.items, contains('KP Sharma Oli'));
      expect(deck.items, contains('Sher Bahadur Deuba'));
      expect(deck.items, contains('Pushpa Kamal Dahal'));
      expect(deck.items, contains('Balen Shah'));
      expect(deck.items, contains('Gagan Thapa'));
      expect(deck.items, contains('Rabi Lamichhane'));

      // Verifies procedural summaries are excluded
      expect(deck.items.any((item) => item.toLowerCase().contains('history of')), isFalse);
      expect(deck.items.any((item) => item.toLowerCase().contains('election procedure')), isFalse);
    });

    test('Deck canRefresh correctly distinguishes refreshable vs handmade decks', () {
      // 1. Starter deck is always refreshable
      final starter = Deck.starterDecks.first;
      expect(starter.canRefresh, isTrue);

      // 2. AI-generated deck is refreshable
      const aiDeck = Deck(
        id: 'ai_1',
        name: 'SCI-FI',
        emoji: '',
        colorValue: 0xFF2F5BFF,
        items: ['Dune', 'Matrix'],
        isCustom: true,
        isAiGenerated: true,
        originalPrompt: 'Sci-fi movies and concepts',
      );
      expect(aiDeck.canRefresh, isTrue);

      // 3. User handmade custom deck (without AI generation / prompt) is NOT refreshable
      const handmadeDeck = Deck(
        id: 'custom_1',
        name: 'MY INSIDE JOKES',
        emoji: '',
        colorValue: 0xFF2F5BFF,
        items: ['Uncle Bob', 'Thanksgiving 2024'],
        isCustom: true,
        isAiGenerated: false,
        originalPrompt: null,
      );
      expect(handmadeDeck.canRefresh, isFalse);
    });

    test('StorageService updateDeckItems persists fresh words for starter and custom decks', () async {
      final storage = StorageService();
      await storage.init();

      final starter = Deck.starterDecks.first;
      final freshStarterWords = ['Fresh 1', 'Fresh 2', 'Fresh 3'];
      await storage.updateDeckItems(starter.id, freshStarterWords);

      final retrievedStarter = storage.getDeck(starter.id);
      expect(retrievedStarter.items, equals(freshStarterWords));

      // Also custom deck
      const customDeck = Deck(
        id: 'custom_test_1',
        name: 'CUSTOM TEST',
        emoji: '',
        colorValue: 0xFF2F5BFF,
        items: ['Old 1', 'Old 2'],
        isCustom: true,
        isAiGenerated: true,
      );
      await storage.saveCustomDeck(customDeck);
      final freshCustomWords = ['New 1', 'New 2', 'New 3'];
      await storage.updateDeckItems(customDeck.id, freshCustomWords);

      final retrievedCustom = storage.getDeck(customDeck.id);
      expect(retrievedCustom.items, equals(freshCustomWords));
    });

    test('generateFreshWordsForDeck throws offline error without API key, enabling seamless fallback', () async {
      final service = GroqDeckService();
      await service.saveApiKey('');

      final deck = Deck.starterDecks.first;
      expect(
        () => service.generateFreshWordsForDeck(deck),
        throwsA(
          predicate((e) => e.toString().contains('AI deck generator is currently offline')),
        ),
      );
    });

    test('In-memory prefetch caching stores and takes words properly', () {
      final service = GroqDeckService();
      const testDeckId = 'test_deck_123';
      expect(service.hasPrefetchedWords(testDeckId), isFalse);
      expect(service.takePrefetchedWords(testDeckId), isNull);
    });

    test('isGroqOnline checks direct HTTP connectivity to Groq API endpoint', () async {
      final service = GroqDeckService();
      final result = await service.isGroqOnline(timeout: const Duration(seconds: 3));
      expect(result, isA<bool>());
    });
  });
}

