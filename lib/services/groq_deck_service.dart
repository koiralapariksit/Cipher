// ignore_for_file: avoid_print

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

  /// Maps player counts (2 to 6) to recommended target card quantities:
  /// 2 Players -> 40 cards
  /// 3 Players -> 60 cards
  /// 4 Players -> 80 cards
  /// 5 Players -> 100 cards
  /// 6 Players -> 120 cards
  static int cardCountForPlayers(int players) {
    if (players <= 2) return 40;
    if (players == 3) return 60;
    if (players == 4) return 80;
    if (players == 5) return 100;
    return 120; // 6+ players
  }

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

  /// Direct, lightweight HTTP check to the Groq API endpoint (`https://api.groq.com`).
  /// If the request returns any HTTP response (including 200, 401, 403, 404),
  /// the network route to Groq is verified open and the device is ONLINE.
  /// Only returns false if a SocketException, TimeoutException, or ClientException occurs.
  Future<bool> isGroqOnline({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    try {
      final uri = Uri.parse('https://api.groq.com');
      final response = await http
          .head(uri, headers: {'User-Agent': 'CipherApp/1.0'})
          .timeout(timeout);
      return response.statusCode != 0;
    } catch (_) {
      try {
        final fallbackUri = Uri.parse('https://api.groq.com');
        final response = await http
            .get(fallbackUri, headers: {'User-Agent': 'CipherApp/1.0'})
            .timeout(timeout);
        return response.statusCode != 0;
      } catch (_) {
        return false;
      }
    }
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
    int? playerCount,
    void Function(String step)? onProgress,
  }) async {
    final cleanTopic = topic.trim();
    if (cleanTopic.isEmpty) {
      throw Exception('Please specify a deck topic.');
    }

    final effectiveCardCount = playerCount != null
        ? cardCountForPlayers(playerCount)
        : cardCount;

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
      cardCount: effectiveCardCount,
      difficulty: difficulty,
      webSearchSnippets: webSearchSnippets,
      playerCount: playerCount,
    );

    // Phase 4: Query Groq API with Model Resilience Fallback
    onProgress?.call('Synthesizing cards with Groq AI...');
    final responseContent = await _executeGroqCompletion(
      apiKey: apiKey,
      prompt: prompt,
      topic: cleanTopic,
      onProgress: onProgress,
    );

    // Phase 5: Parse and Seal Deck
    onProgress?.call('Encrypting & sealing deck into library...');
    final deck = _parseAndBuildDeck(
      rawJson: responseContent,
      fallbackTopic: cleanTopic,
      targetCardCount: effectiveCardCount,
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
      topic: topic,
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
    String topic = '',
    double temperature = 0.7,
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
          'temperature': 0.7,
          'response_format': {'type': 'json_object'},
        };

        print('--> GROQ REQUEST ATTEMPT: model=$model, topic=$topic');

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

        print('--> GROQ STATUS: ${response.statusCode}');
        print('--> GROQ BODY: ${response.body}');

        if (response.statusCode != 200) {
          debugPrint(
              '--> GROQ HTTP ERROR: status=${response.statusCode}, body=${response.body}');
        }

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
      } catch (e, st) {
        print('--> GROQ ERROR: $e');
        print('--> STACK TRACE: $st');
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
    int? playerCount,
  }) {
    final playerContext = playerCount != null
        ? ' (scaled dynamically for $playerCount players with strict anti-repetition)'
        : '';
    return '''You are an elite party game director creating cards for 'Heads Up!', a fast-paced forehead charades guessing game. Every single item you generate must be something a player can instantly mime, describe, or name in under 3 seconds.

Target Topic: "$topic"
Target Count: $cardCount$playerContext
Target Difficulty: "$difficulty"

LIVE WEB / ENCYCLOPEDIC CONTEXT:
$webSearchSnippets

STRICT ENTITY-ONLY RULES:
1. NO DESCRIPTIONS OR POWERS: Never output abstract concepts, emotions, or character powers (e.g., DO NOT output 'hulk rage', 'spidey sense', 'time travel'). Output the actual character name instead (e.g., 'Hulk', 'Spider-Man', 'Doctor Strange').
2. NO HISTORY OR SUMMARIES: If the user asks for a political topic (e.g., 'Nepali parliament members' or 'Nepali politicians'), output real, well-known names of politicians or political figures (e.g., 'KP Sharma Oli', 'Sher Bahadur Deuba', 'Pushpa Kamal Dahal'), never explanations of elections or parliament procedures.
3. EXACT FORMATTING: 1 to 3 words maximum per card. Pure nouns, names, titles, movies, or concrete actions.
4. COUNT & ANTI-REPETITION: Generate strictly $cardCount unique, highly recognizable items per request. Ensure zero duplicates, distinct sub-themes, and high variety.
5. CHILD-SAFE GUARDRAIL: Strictly 100% family-friendly. Zero 18+, pornographic, drug, or harmful content. If user requests adult or violent content, fallback to safe party pop culture, animals, or movies.
6. DECK NAME SUMMARIZATION RULE: Automatically summarize the core theme into a punchy, 1-word or 2-word UPPERCASE deck name (e.g. 'LEGENDS' or 'POP').
7. OUTPUT REQUIREMENT: Return strictly a valid JSON object matching this schema:
{
  "name": "UPPERCASE DECK NAME",
  "category": "Category",
  "items": ["Card 1", "Card 2", ...]
}
Never include markdown code block wrappers (e.g. no ```json). Output pure raw JSON only.
8. CRITICAL ANTI-TEMPLATE RULE: Never use the user's input topic as a mandatory prefix or suffix for every card. If the user asks for 'MCU Avengers', do NOT output 'Watching mcu avengers' or 'Classic mcu avengers'. Output distinct, independent entity names, characters, items, or titles (e.g., 'Iron Man', 'Thor', 'Thanos', 'Shield', 'Mjolnir', 'Black Widow'). Each card must be entirely unique and diverse.
''';
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
    int? playerCount,
  }) =>
      _buildPrompt(
        topic: topic,
        cardCount: cardCount,
        difficulty: difficulty,
        webSearchSnippets: webSearchSnippets,
        playerCount: playerCount,
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

  static bool _isCleanEntityItem(String item, {String? topic}) {
    if (item.length < 2) return false;
    // Forehead charades cards must be 1-3 words (allow max 4 words for full names)
    final words = item.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.length > 4) return false;

    final lower = item.toLowerCase();
    const bannedAbstractPhrases = [
      'history of',
      'how to',
      'how elections',
      'parliament procedure',
      'election procedure',
      'voting system',
      'voting process',
      'rules of',
      'explanation of',
    ];
    for (final phrase in bannedAbstractPhrases) {
      if (lower.contains(phrase)) return false;
    }

    // Critical Anti-Template Guard: discard lazy phrases appending topic
    if (topic != null && topic.trim().isNotEmpty) {
      final t = topic.trim().toLowerCase();
      if (t.length >= 3 && lower != t) {
        final lazyPrefixes = ['watching ', 'classic ', 'acting out ', 'drawing ', 'singing about ', 'extreme ', 'ultimate ', 'retro ', 'super '];
        final lazySuffixes = [' fan', ' expert', ' party', ' mania', ' challenge', ' secrets', ' night', ' legend', ' mystery'];
        for (final p in lazyPrefixes) {
          if (lower.startsWith(p) && lower.contains(t)) return false;
        }
        for (final s in lazySuffixes) {
          if (lower.endsWith(s) && lower.contains(t)) return false;
        }
      }
    }

    return true;
  }

  /// Parses, sanitizes, and verifies output against schema constraints.
  Deck _parseAndBuildDeck({
    required String rawJson,
    required String fallbackTopic,
    required int targetCardCount,
  }) {
    print(
        '--> PARSE DECK: fallbackTopic=$fallbackTopic, targetCardCount=$targetCardCount, rawJsonLength=${rawJson.length}');
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

    dynamic decoded;
    try {
      decoded = jsonDecode(cleanJson);
    } catch (_) {
      // Fallback: extract object or array if wrapped in conversational text
      final objectMatch = RegExp(r'\{[\s\S]*\}').firstMatch(cleanJson);
      if (objectMatch != null) {
        try {
          decoded = jsonDecode(objectMatch.group(0)!);
        } catch (_) {}
      }
      if (decoded == null) {
        final arrayMatch = RegExp(r'\[[\s\S]*\]').firstMatch(cleanJson);
        if (arrayMatch != null) {
          try {
            decoded = jsonDecode(arrayMatch.group(0)!);
          } catch (_) {}
        }
      }
    }

    String rawName = '';
    String category = 'AI Custom';
    int colorValue = 4280391456;
    List<dynamic> rawItems = [];

    if (decoded is Map<String, dynamic>) {
      rawName = decoded['name']?.toString() ?? fallbackTopic;
      category = decoded['category']?.toString().trim() ?? 'AI Custom';
      colorValue = decoded['colorValue'] is int
          ? decoded['colorValue'] as int
          : 4280391456;
      rawItems = decoded['items'] as List<dynamic>? ?? [];
    } else if (decoded is List) {
      rawItems = decoded;
      rawName = fallbackTopic;
    }

    final name = _summarizeDeckTitle(rawName, fallbackTopic);

    final Set<String> seen = {};
    final List<String> sanitizedItems = [];

    for (final item in rawItems) {
      final s = item?.toString().trim() ?? '';
      if (s.isEmpty) continue;
      if (!_isSafeItem(s)) continue;
      if (!_isCleanEntityItem(s, topic: fallbackTopic)) continue;
      final lower = s.toLowerCase();
      if (!seen.contains(lower)) {
        seen.add(lower);
        sanitizedItems.add(s);
      }
    }

    print(
        '--> PARSE DECK RESULT: rawCount=${rawItems.length}, sanitizedCount=${sanitizedItems.length}');

    // If the API returns fewer than 10 valid sanitized items, fail cleanly without generating fake templates
    if (sanitizedItems.length < 10) {
      debugPrint(
          '--> PARSE ERROR: Insufficient valid cards (${sanitizedItems.length} < 10)');
      throw Exception('AI Generation failed — check connection & try again');
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

