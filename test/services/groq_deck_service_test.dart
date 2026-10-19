import 'package:flutter_test/flutter_test.dart';
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

      expect(deck.name, 'Superconductors');
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
  });
}

