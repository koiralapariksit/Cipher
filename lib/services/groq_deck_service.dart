import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/deck.dart';
import 'storage_service.dart';

/// Core intelligence service powering 1-click in-app deck generation
/// with live web search grounding and Groq inference.
class GroqDeckService {
  static final GroqDeckService _instance = GroqDeckService._internal();
  factory GroqDeckService() => _instance;
  GroqDeckService._internal();

  static const String _defaultModel = 'llama-3.3-70b-versatile';
  static const List<String> _fallbackModels = [
    'openai/gpt-oss-120b',
    'qwen/qwen3.8-27b',
    'openai/gpt-oss-20b',
  ];

  static const String _groqCompletionsUrl =
      'https://api.groq.com/openai/v1/chat/completions';

  static const Map<String, String> _standardHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Content-Type': 'application/json',
  };

  /// Retrieves the active Groq API Key:
  /// 1. First checks persistent in-app preferences (`groq_api_key`).
  /// 2. Second reads from `.env` bundled asset.
  Future<String?> getApiKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedKey = prefs.getString('groq_api_key')?.trim();
      if (savedKey != null &&
          savedKey.isNotEmpty &&
          !savedKey.contains('PASTE_YOUR_GROQ_KEY_HERE')) {
        return savedKey;
      }
    } catch (_) {}

    try {
      final envString = await rootBundle.loadString('.env');
      final lines = const LineSplitter().convert(envString);
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.startsWith('GROQ_API_KEY=')) {
          final key = trimmed.substring('GROQ_API_KEY='.length).trim();
          if (key.isNotEmpty && !key.contains('PASTE_YOUR_GROQ_KEY_HERE')) {
            return key;
          }
        }
      }
    } catch (_) {}

    return null;
  }

  /// Allows persisting or updating the API key in local storage.
  Future<void> saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('groq_api_key', key.trim());
  }

  /// Live Web Search grounding: Queries Wikipedia and DuckDuckGo for
  /// real-world entities, verified rosters, and relevant context.
  Future<String> fetchLiveWebContext(String topic) async {
    final List<String> snippets = [];

    // 1. Wikipedia OpenSearch & Query API (High factual grounding)
    final List<String> topTitles = [];
    try {
      final encoded = Uri.encodeComponent(topic);
      final wikiUri = Uri.parse(
        'https://en.wikipedia.org/w/api.php?action=query&list=search&srsearch=$encoded&format=json&utf8=1&srlimit=6',
      );

      final response = await http
          .get(wikiUri, headers: {'User-Agent': 'CipherApp/1.0'})
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final searchResults =
            data['query']?['search'] as List<dynamic>? ?? [];

        for (final item in searchResults) {
          final title = item['title']?.toString() ?? '';
          final rawSnippet = item['snippet']?.toString() ?? '';
          final cleanSnippet = _sanitizeSnippet(rawSnippet);
          if (title.isNotEmpty) {
            topTitles.add(title);
            snippets.add('$title: $cleanSnippet');
          }
        }
      }
    } catch (_) {}

    // 1b. Wikipedia Deep Encyclopedic Extract for top matches
    if (topTitles.isNotEmpty) {
      try {
        final joinedTitles = topTitles.take(2).map(Uri.encodeComponent).join('|');
        final extUri = Uri.parse(
          'https://en.wikipedia.org/w/api.php?action=query&prop=extracts&exintro=1&explaintext=1&titles=$joinedTitles&format=json',
        );

        final extResponse = await http
            .get(extUri, headers: {'User-Agent': 'CipherApp/1.0'})
            .timeout(const Duration(seconds: 3));

        if (extResponse.statusCode == 200) {
          final extData = jsonDecode(extResponse.body) as Map<String, dynamic>;
          final pages = extData['query']?['pages'] as Map<String, dynamic>? ?? {};
          for (final page in pages.values) {
            if (page is Map<String, dynamic>) {
              final title = page['title']?.toString() ?? '';
              final extract = page['extract']?.toString() ?? '';
              if (extract.isNotEmpty) {
                final cleanExtract = extract.length > 350
                    ? '${extract.substring(0, 350)}...'
                    : extract;
                snippets.add('ENCYCLOPEDIC RECORD [$title]: $cleanExtract');
              }
            }
          }
        }
      } catch (_) {}
    }

    // 2. DuckDuckGo Instant Answer API (Supplementary grounding)
    if (snippets.length < 3) {
      try {
        final encoded = Uri.encodeComponent(topic);
        final ddgUri = Uri.parse(
          'https://api.duckduckgo.com/?q=$encoded&format=json&no_html=1&skip_disambig=1',
        );

        final response = await http
            .get(ddgUri, headers: {'User-Agent': 'CipherApp/1.0'})
            .timeout(const Duration(seconds: 3));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final abstractText = data['AbstractText']?.toString() ?? '';
          final heading = data['Heading']?.toString() ?? '';
          if (abstractText.isNotEmpty) {
            snippets.add('$heading: $abstractText');
          }

          final related = data['RelatedTopics'] as List<dynamic>? ?? [];
          for (final r in related) {
            if (r is Map<String, dynamic> && r['Text'] != null) {
              snippets.add(r['Text'].toString());
            }
          }
        }
      } catch (_) {}
    }

    if (snippets.isEmpty) {
      return 'No external web snippets found for "$topic". Ground strictly in verified real-world knowledge.';
    }

    return snippets.take(6).join('\n');
  }

  /// Generates a complete, verified Deck via Groq LLM with progressive callbacks.
  Future<Deck> generateDeck({
    required String topic,
    required int cardCount,
    required String difficulty,
    void Function(String step)? onProgress,
  }) async {
    final cleanTopic = topic.trim();
    if (cleanTopic.isEmpty) {
      throw Exception('Please specify a deck topic.');
    }

    // Phase 1: Retrieve API Key
    final apiKey = await getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception(
        'Missing Groq API Key. Add your key to .env or update it in app settings.',
      );
    }

    // Phase 2: Live Web Search Grounding
    onProgress?.call('Grounding via Live Web Search...');
    final webSearchSnippets = await fetchLiveWebContext(cleanTopic);

    // Phase 3: Construct Exact Grounding Prompt
    final prompt = _buildPrompt(
      topic: cleanTopic,
      cardCount: cardCount,
      difficulty: difficulty,
      webSearchSnippets: webSearchSnippets,
    );

    // Phase 4: Query Groq API with Model Resilience Fallback
    onProgress?.call('Synthesizing cards with Groq AI...');
    final responseContent = await _executeGroqCompletion(
      apiKey: apiKey,
      prompt: prompt,
      onProgress: onProgress,
    );

    // Phase 5: Parse and Seal Deck
    onProgress?.call('Encrypting & sealing deck into library...');
    final deck = _parseAndBuildDeck(
      rawJson: responseContent,
      fallbackTopic: cleanTopic,
      targetCardCount: cardCount,
    );

    // Persist to local storage
    await StorageService().saveCustomDeck(deck);

    return deck;
  }

  /// Executes chat completion with Groq, falling back gracefully if the
  /// target model was decommissioned or not accessible.
  Future<String> _executeGroqCompletion({
    required String apiKey,
    required String prompt,
    void Function(String step)? onProgress,
  }) async {
    final candidateModels = [_defaultModel, ..._fallbackModels];

    String? lastError;
    for (final model in candidateModels) {
      try {
        final payload = {
          'model': model,
          'messages': [
            {'role': 'user', 'content': prompt},
          ],
          'temperature': 0.2,
          'response_format': {'type': 'json_object'},
        };

        final response = await http
            .post(
              Uri.parse(_groqCompletionsUrl),
              headers: {
                ..._standardHeaders,
                'Authorization': 'Bearer $apiKey',
              },
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 25));

        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes))
              as Map<String, dynamic>;
          final choices = data['choices'] as List<dynamic>?;
          if (choices != null && choices.isNotEmpty) {
            final content = choices[0]['message']?['content']?.toString();
            if (content != null && content.isNotEmpty) {
              return content;
            }
          }
        }

        // If 404/400 model not available or decommissioned, try next candidate
        if (response.statusCode == 404 ||
            response.statusCode == 400 ||
            response.statusCode == 422) {
          final errorBody = response.body;
          if (errorBody.contains('model') ||
              errorBody.contains('decommissioned')) {
            lastError = 'Model $model unavailable on Groq: $errorBody';
            continue;
          }
        }

        if (response.statusCode == 401) {
          throw Exception('Invalid Groq API Key. Please verify your key.');
        }

        if (response.statusCode == 429) {
          throw Exception(
              'Groq rate limit reached. Please wait a few seconds and retry.');
        }

        lastError = 'Groq API error (${response.statusCode}): ${response.body}';
      } catch (e) {
        if (e is Exception &&
            (e.toString().contains('Invalid Groq') ||
                e.toString().contains('rate limit'))) {
          rethrow;
        }
        lastError = e.toString();
      }
    }

    throw Exception(lastError ?? 'Failed to generate deck with Groq.');
  }

  /// Builds the prompt according to the strict two-step verification specification.
  String _buildPrompt({
    required String topic,
    required int cardCount,
    required String difficulty,
    required String webSearchSnippets,
  }) {
    return '''You are the factual accuracy and intelligence engine for "Cipher", a party guessing game.
Target Topic: "$topic"
Target Count: $cardCount
Target Difficulty: "$difficulty"

LIVE WEB / ENCYCLOPEDIC CONTEXT:
$webSearchSnippets

STRICT VERIFICATION & FACT-CHECKING RULES:
1. STRICT QUALIFICATION CHECK: Every single item MUST strictly satisfy all conditions in the prompt.
   - Example failure: If topic is "Ballon d'Or Winners", nominees, runner-ups, and Kopa/Yashin trophy winners (e.g., Jude Bellingham, Andrés Iniesta, Neymar, Thierry Henry) are STRICTLY DISQUALIFIED. Only official winners (e.g., Lionel Messi, Cristiano Ronaldo, Kaká, Ronaldinho, Luka Modrić, Karim Benzema, Rodri, Rivaldo, Zidane, George Weah, Marco van Basten) are permitted.
2. ZERO TOLERANCE FOR FALSE POSITIVES: Do not include an item simply because it is famous or associated with the subject. If an entity did not definitively achieve/meet the requested criteria, exclude it.
3. NEGATIVE CHECK BEFORE EMITTING:
   - Does this item strictly meet the exact query criteria? If doubtful, discard and replace.
4. QUANTITY & DIVERSITY:
   - Emit exactly $cardCount unique items.
   - If the exact historical pool is smaller than $cardCount, include all valid entities across eras (historical and modern) rather than inventing or padding with unqualified entries.

OUTPUT SCHEMA (RAW JSON OBJECT ONLY):
{
  "name": "$topic",
  "emoji": "<single relevant emoji>",
  "category": "AI Custom",
  "colorValue": 4280391456,
  "items": ["Item 1", "Item 2", ...]
}''';
  }

  /// Parses, sanitizes, and verifies output against schema constraints.
  Deck _parseAndBuildDeck({
    required String rawJson,
    required String fallbackTopic,
    required int targetCardCount,
  }) {
    String cleanJson = rawJson.trim();
    if (cleanJson.startsWith('```json')) {
      cleanJson = cleanJson.substring(7);
    }
    if (cleanJson.startsWith('```')) {
      cleanJson = cleanJson.substring(3);
    }
    if (cleanJson.endsWith('```')) {
      cleanJson = cleanJson.substring(0, cleanJson.length - 3);
    }
    cleanJson = cleanJson.trim();

    final data = jsonDecode(cleanJson) as Map<String, dynamic>;

    final rawName = data['name']?.toString().trim();
    final name = (rawName != null && rawName.isNotEmpty) ? rawName : fallbackTopic;

    final rawEmoji = data['emoji']?.toString().trim();
    final emoji = (rawEmoji != null && rawEmoji.isNotEmpty)
        ? String.fromCharCode(rawEmoji.runes.first)
        : '🎯';

    final category = data['category']?.toString().trim() ?? 'AI Custom';
    final colorValue = data['colorValue'] is int
        ? data['colorValue'] as int
        : 4280391456;

    final rawItems = data['items'] as List<dynamic>? ?? [];
    final Set<String> seen = {};
    final List<String> sanitizedItems = [];

    for (final item in rawItems) {
      final s = item?.toString().trim() ?? '';
      if (s.isEmpty) continue;
      final lower = s.toLowerCase();
      if (!seen.contains(lower)) {
        seen.add(lower);
        sanitizedItems.add(s);
      }
    }

    if (sanitizedItems.length < 3) {
      throw Exception(
        'Deck generator produced too few valid cards (${sanitizedItems.length}). Please try a different topic.',
      );
    }

    // Shuffle cards so every game starts with a random word sequence
    sanitizedItems.shuffle();

    return Deck(
      id: 'custom_ai_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      emoji: emoji,
      category: category,
      colorValue: colorValue,
      isCustom: true,
      items: sanitizedItems,
    );
  }

  /// Strips HTML tags and entities from raw Wikipedia snippets.
  String _sanitizeSnippet(String html) {
    var text = html.replaceAll(RegExp(r'<[^>]*>'), '');
    text = text.replaceAll('&quot;', '"');
    text = text.replaceAll('&#039;', "'");
    text = text.replaceAll('&amp;', '&');
    text = text.replaceAll('&lt;', '<');
    text = text.replaceAll('&gt;', '>');
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}

