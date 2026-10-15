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
}

