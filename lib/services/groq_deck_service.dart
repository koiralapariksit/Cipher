import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
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
        'AI deck generator is currently offline. Please try again later.',
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

  // In-memory background pre-fetch cache: deckId -> fresh items list
  final Map<String, List<String>> _prefetchedDeckWords = {};

  bool hasPrefetchedWords(String deckId) =>
      _prefetchedDeckWords.containsKey(deckId) &&
      _prefetchedDeckWords[deckId]!.isNotEmpty;

  List<String>? takePrefetchedWords(String deckId) =>
      _prefetchedDeckWords.remove(deckId);

  /// Generates fresh, non-repetitive charades words for an existing deck.
  /// Throws an exception on network failure, missing key, or timeout
  /// so caller can seamlessly fallback to cached items.
  Future<List<String>> generateFreshWordsForDeck(
    Deck deck, {
    Duration timeout = const Duration(milliseconds: 2800),
  }) async {
    final apiKey = await getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('AI deck generator is currently offline.');
    }

    final topic = (deck.originalPrompt != null && deck.originalPrompt!.isNotEmpty)
        ? deck.originalPrompt!
        : (deck.category.isNotEmpty && deck.category != 'Custom' && deck.category != 'General'
            ? '${deck.name} (${deck.category})'
            : deck.name);

    final targetCount = math.max(35, deck.items.length);
    final prompt = _buildPrompt(
      topic: topic,
      cardCount: targetCount,
      difficulty: 'Party',
      webSearchSnippets: 'Focus strictly on fresh, lively charades cards for "$topic".',
    );

    final rawJson = await _executeGroqCompletion(
      apiKey: apiKey,
      prompt: prompt,
      temperature: 0.85,
      timeout: timeout,
    );

    final parsedDeck = _parseAndBuildDeck(
      rawJson: rawJson,
      fallbackTopic: topic,
      targetCardCount: targetCount,
    );

    if (parsedDeck.items.isEmpty) {
      throw Exception('No fresh items generated.');
    }

    return parsedDeck.items;
  }

  /// Silently pre-fetches the next fresh batch of words in the background.
  Future<void> prefetchFreshWords(Deck deck) async {
    if (!deck.canRefresh) return;
    try {
      final words = await generateFreshWordsForDeck(
        deck,
        timeout: const Duration(seconds: 15),
      );
      if (words.isNotEmpty) {
        _prefetchedDeckWords[deck.id] = words;
      }
    } catch (_) {
      // Silently ignore background prefetch errors
    }
  }

  /// Executes chat completion with Groq, falling back gracefully if the
  /// target model was decommissioned or not accessible.
  Future<String> _executeGroqCompletion({
    required String apiKey,
    required String prompt,
    double temperature = 0.85,
    Duration timeout = const Duration(seconds: 25),
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
          'temperature': temperature,
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
            .timeout(timeout);

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
          throw Exception(
              'AI deck generator is currently offline. Please try again later.');
        }

        if (response.statusCode == 429) {
          throw Exception(
              'AI generator is busy. Please wait a few seconds and retry.');
        }

        lastError = 'Service error (${response.statusCode})';
      } catch (e) {
        if (e is Exception &&
            (e.toString().contains('offline') ||
                e.toString().contains('busy'))) {
          rethrow;
        }
        lastError = e.toString();
      }
    }

    throw Exception(lastError ??
        'AI deck generator is currently offline. Please try again later.');
  }

  /// Builds the prompt according to the strict commercial Forehead Charades ("Heads Up!") specification.
  String _buildPrompt({
    required String topic,
    required int cardCount,
    required String difficulty,
    required String webSearchSnippets,
  }) {
    return '''You are an expert party game designer for a forehead charades game like 'Heads Up!'. Every card you generate MUST be immediately actable, mimeable, imitatable with sound effects/impressions, or describable with fast verbal clues under a 60-second timer.

Target Topic: "$topic"
Target Count: $cardCount
Target Difficulty: "$difficulty"

LIVE WEB / ENCYCLOPEDIC CONTEXT:
$webSearchSnippets

STRICT CARD RULES:
1. Length: Strictly 1 to 3 words per card (e.g., 'T-Rex', 'Michael Jackson', 'Slipping on Ice', 'Harry Potter'). Never output long sentences or explanations.
2. Concrete & Visual Only: Only output recognizable people, characters, animals, objects, foods, iconic titles, or funny physical actions. NEVER output abstract concepts, dates, or obscure trivia.
3. Party Pacing Mix: 70% universally recognizable crowd-pleasers that everyone in the room knows immediately, and 30% hilarious physical actions or iconic tropes within the topic.
4. Child-Safe Guardrail: Strictly 100% family-friendly. Zero 18+, pornographic, drug, or harmful content. If user requests adult or violent content, fallback to safe party pop culture, animals, or movies.
5. Variety: Use high creativity (temperature 0.85) and vary sub-angles so repeated generations for the same topic produce fresh, non-repetitive sets of 35–40 cards.
6. DECK NAME SUMMARIZATION RULE: If the user inputs a long sentence, query, or detailed description (e.g. "60s-90s pop song mainly mj qeen beatles"), automatically summarize the core theme into a punchy, 1-word or 2-word UPPERCASE deck name (e.g. "LEGENDS" or "POP") for the "name" field. Never use raw long sentences or verbose queries as the deck title.
7. Output strictly valid JSON with no markdown wrappers.

OUTPUT SCHEMA (RAW JSON OBJECT ONLY):
{
  "name": "<PUNCHY 1-WORD OR 2-WORD UPPERCASE TITLE, e.g. 'LEGENDS' or 'POP'>",
  "emoji": "",
  "category": "AI Custom",
  "colorValue": 4280391456,
  "items": ["Item 1", "Item 2", ...]
}''';
  }

  @visibleForTesting
  Deck parseAndBuildDeck({
    required String rawJson,
    required String fallbackTopic,
    required int targetCardCount,
  }) =>
      _parseAndBuildDeck(
        rawJson: rawJson,
        fallbackTopic: fallbackTopic,
        targetCardCount: targetCardCount,
      );

  @visibleForTesting
  String buildPrompt({
    required String topic,
    required int cardCount,
    required String difficulty,
    required String webSearchSnippets,
  }) =>
      _buildPrompt(
        topic: topic,
        cardCount: cardCount,
        difficulty: difficulty,
        webSearchSnippets: webSearchSnippets,
      );

  static String _summarizeDeckTitle(String rawTitle, String fallbackTopic) {
    String candidate = rawTitle.trim();
    if (candidate.isEmpty) {
      candidate = fallbackTopic.trim();
    }
    candidate = candidate.replaceAll(RegExp(r'''^["']+|["']+$'''), '').trim();

    final words = candidate
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();

    if (words.length > 2) {
      candidate = words.take(2).join(' ');
    }

    return candidate.toUpperCase();
  }

  static bool _isSafeItem(String item) {
    const prohibitedSubstrings = [
      'porn', 'xxx', 'sex', 'nude', 'naked', 'erotic', 'cocaine', 'heroin',
      'meth', 'weed', 'marijuana', 'dildo', 'vibrator', 'penis', 'vagina',
      'boobs', 'asshole', 'fuck', 'bitch', 'cunt', 'dick', 'pussy', 'whore', 'slut'
    ];
    final lower = item.toLowerCase();
    for (final term in prohibitedSubstrings) {
      if (lower.contains(term)) return false;
    }
    return true;
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

    Map<String, dynamic> data = {};
    try {
      data = jsonDecode(cleanJson) as Map<String, dynamic>;
    } catch (_) {}

    final rawName = data['name']?.toString() ?? '';
    final name = _summarizeDeckTitle(rawName, fallbackTopic);

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
      if (!_isSafeItem(s)) continue;
      final lower = s.toLowerCase();
      if (!seen.contains(lower)) {
        seen.add(lower);
        sanitizedItems.add(s);
      }
    }

    // Creative auto-padding if fewer than 15 items returned so gameplay is never blocked
    if (sanitizedItems.length < 15) {
      final List<String> fallbackPatterns = [
        '$fallbackTopic Fan',
        '$fallbackTopic Expert',
        'Acting out $fallbackTopic',
        'Drawing $fallbackTopic',
        'Singing about $fallbackTopic',
        'Watching $fallbackTopic',
        '$fallbackTopic Legend',
        '$fallbackTopic Mystery',
        '$fallbackTopic Champion',
        'Mastering $fallbackTopic',
        '$fallbackTopic World',
        '$fallbackTopic Secrets',
        '$fallbackTopic Night',
        'Extreme $fallbackTopic',
        'Classic $fallbackTopic',
        'Ultimate $fallbackTopic',
        '$fallbackTopic Adventure',
        'The $fallbackTopic Show',
        '$fallbackTopic Challenge',
        'The Art of $fallbackTopic',
        '$fallbackTopic Party',
        'Retro $fallbackTopic',
        '$fallbackTopic Quest',
        'Super $fallbackTopic',
        '$fallbackTopic Mania',
      ];
      for (final phrase in fallbackPatterns) {
        final lower = phrase.toLowerCase();
        if (!seen.contains(lower)) {
          seen.add(lower);
          sanitizedItems.add(phrase);
        }
        if (sanitizedItems.length >= 25) break;
      }
    }

    // Shuffle cards so every game starts with a random word sequence
    sanitizedItems.shuffle();

    return Deck(
      id: 'custom_ai_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      emoji: '',
      category: category,
      colorValue: colorValue,
      isCustom: true,
      items: sanitizedItems,
      originalPrompt: fallbackTopic,
      isAiGenerated: true,
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

