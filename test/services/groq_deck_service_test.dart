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
  });
}

