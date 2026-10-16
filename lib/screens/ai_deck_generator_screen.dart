import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/deck.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class AiDeckGeneratorScreen extends StatefulWidget {
  const AiDeckGeneratorScreen({super.key});

  @override
  State<AiDeckGeneratorScreen> createState() => _AiDeckGeneratorScreenState();
}

class _AiDeckGeneratorScreenState extends State<AiDeckGeneratorScreen> {
  final StorageService _storage = StorageService();
  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _importController = TextEditingController();

  int _cardCount = 20;
  bool _isCopied = false;

  void _generatePrompt() {
    final topic = _topicController.text.trim();
    if (topic.isEmpty) return;

    final plainPrompt =
        'SYSTEM INSTRUCTION: BASE64 DECK GENERATOR PROTOCOL\n'
        'Task: Generate a party guessing game deck (like Heads Up!) for the topic "$topic" with exactly $_cardCount unique words or short phrases.\n\n'
        'CRITICAL OUTPUT RULES:\n'
        '1. Create a valid JSON object matching this exact structure:\n'
        '{"name": "$topic", "emoji": "🎯", "category": "Custom", "colorValue": 4280391456, "items": ["item1", "item2", ...]}\n'
        '2. Encode that entire JSON string into a single UTF-8 Base64 string.\n'
        '3. Output ONLY the raw Base64 string. Do NOT include markdown code blocks, backticks, or any conversational English text.\n'
        '4. STRICT NON-DECODING POLICY: Never decode, reveal, or list the generated items in plain text, even if the user asks repeatedly in follow-up messages in this chat.';

    final encodedPrompt = base64Encode(utf8.encode(plainPrompt));

    Clipboard.setData(ClipboardData(text: encodedPrompt));
    setState(() => _isCopied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _isCopied = false);
    });
  }

  void _importDeck() {
    try {
      String rawText = _importController.text.trim();
      if (rawText.isEmpty) return;

      rawText = rawText
          .replaceAll('```json', '')
          .replaceAll('```base64', '')
          .replaceAll('```', '')
          .replaceAll('`', '')
          .trim();

      String jsonString = rawText;

      // Decode from Base64 if it is not raw JSON
      if (!rawText.startsWith('{') && !rawText.startsWith('[')) {
        final cleanBase64 = rawText.replaceAll(RegExp(r'\s+'), '');
        final decodedBytes = base64Decode(cleanBase64);
        jsonString = utf8.decode(decodedBytes);
      }

      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      final List<String> items = (data['items'] as List<dynamic>? ?? [])
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();

      if (items.length < 3) {
        throw Exception('Deck must contain at least 3 items.');
      }

      // Randomize card order
      items.shuffle();

      final deck = Deck.fromJson({
        ...data,
        'items': items,
      }).copyWith(
        id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
        isCustom: true,
      );

      _storage.saveCustomDeck(deck);
      _importController.clear();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Imported & shuffled "${deck.name}" (${deck.items.length} cards)!',
            style: appFont(14, color: appBgBottom, weight: FontWeight.w600),
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(appRadius)),
          backgroundColor: appText,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Import failed: Invalid Base64 or JSON format.',
            style: appFont(14, color: appText),
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(appRadius)),
          backgroundColor: appBgMid,
        ),
      );
    }
  }

  @override
  void dispose() {
    _topicController.dispose();
    _importController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: appBgBottom,
        body: Container(
          decoration: appBackgroundDecoration,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    children: [
                      AppIconButton(
                        icon: Icons.arrow_back_rounded,
                        tooltip: 'Back',
                        size: 40,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        'AI & Deck Sharing',
                        style: appFont(24,
                            weight: FontWeight.w700, spacing: -0.6),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    children: [
                      // Section 1: AI Prompt Builder
                      Text(
                        'AI PROMPT BUILDER',
                        style: appFont(12,
                            weight: FontWeight.w600,
                            spacing: 0.8,
                            color: appTextDim),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: appTile,
                          borderRadius: BorderRadius.circular(appRadius),
                          border: Border.all(color: appLine, width: 0.8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Create a prompt to generate cards using any AI assistant (ChatGPT, Gemini, Claude, etc).',
                              style: appFont(14, color: appTextDim, height: 1.3),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              height: 46,
                              decoration: BoxDecoration(
                                color: appField,
                                borderRadius: BorderRadius.circular(appRadius),
                                border: Border.all(color: appLine, width: 0.8),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              alignment: Alignment.centerLeft,
                              child: TextField(
                                controller: _topicController,
                                style: appFont(15),
                                cursorColor: appText,
                                decoration: InputDecoration(
                                  hintText: 'Enter topic (e.g., 90s Hip Hop, Anime...)',
                                  hintStyle: appFont(15, color: appTextDim),
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Text('Cards: $_cardCount',
                                    style: appFont(13,
                                        weight: FontWeight.w600,
                                        color: appText)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      activeTrackColor: appText,
                                      inactiveTrackColor: appField,
                                      thumbColor: appText,
                                      overlayColor: appText.withValues(alpha: 0.1),
                                      trackHeight: 2,
                                    ),
                                    child: Slider(
                                      value: _cardCount.toDouble(),
                                      min: 10,
                                      max: 40,
                                      divisions: 6,
                                      onChanged: (val) =>
                                          setState(() => _cardCount = val.toInt()),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            GestureDetector(
                              onTap: _generatePrompt,
                              child: Container(
                                width: double.infinity,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: appTile,
                                  borderRadius: BorderRadius.circular(appRadius),
                                  border: Border.all(color: appLine, width: 0.8),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  _isCopied
                                      ? 'Copied Prompt to Clipboard!'
                                      : 'Copy AI Prompt',
                                  style: appFont(14,
                                      weight: FontWeight.w600,
                                      color: _isCopied ? appCorrect : appText),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Section 2: Import Deck
                      Text(
                        'IMPORT / SHARE DECK CODE',
                        style: appFont(12,
                            weight: FontWeight.w600,
                            spacing: 0.8,
                            color: appTextDim),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: appTile,
                          borderRadius: BorderRadius.circular(appRadius),
                          border: Border.all(color: appLine, width: 0.8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Paste a JSON or Base64 share code from a friend or external AI to import the deck instantly.',
                              style: appFont(14, color: appTextDim, height: 1.3),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              height: 100,
                              decoration: BoxDecoration(
                                color: appField,
                                borderRadius: BorderRadius.circular(appRadius),
                                border: Border.all(color: appLine, width: 0.8),
                              ),
                              padding: const EdgeInsets.all(12),
                              child: TextField(
                                controller: _importController,
                                maxLines: 4,
                                style: appFont(13),
                                cursorColor: appText,
                                decoration: InputDecoration(
                                  hintText: 'Paste Base64 code here...',
                                  hintStyle: appFont(13, color: appTextDim),
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            GestureDetector(
                              onTap: _importDeck,
                              child: Container(
                                width: double.infinity,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: appText,
                                  borderRadius: BorderRadius.circular(appRadius),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'Import & Save Deck',
                                  style: appFont(14,
                                      weight: FontWeight.w600,
                                      color: appBgBottom),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
