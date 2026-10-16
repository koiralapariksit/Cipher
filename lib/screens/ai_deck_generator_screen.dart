import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/deck.dart';
import '../services/storage_service.dart';

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

  static const Color _black = Colors.black;
  static const Color _gold = Color(0xFFC8A45C);
  static const Color _text = Color(0xFFEDEDED);
  static const Color _textDim = Color(0xFF8C8C8C);
  static const Color _panelTop = Color(0xFF1B1B1B);
  static const Color _panelBottom = Color(0xFF0C0C0C);

  TextStyle _font(double size, {FontWeight weight = FontWeight.w400, Color color = _text, double spacing = 0}) {
    return GoogleFonts.jost(fontSize: size, fontWeight: weight, color: color, letterSpacing: spacing);
  }

  BoxDecoration _panel({double radius = 8, bool highlight = false}) {
    return BoxDecoration(
      gradient: const LinearGradient(colors: [_panelTop, _panelBottom], begin: Alignment.topLeft, end: Alignment.bottomRight),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: highlight ? _gold.withValues(alpha: 0.85) : _gold.withValues(alpha: 0.22), width: highlight ? 1.2 : 0.8),
    );
  }
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
            style: _font(14, color: Colors.black, weight: FontWeight.w500),
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          backgroundColor: _gold,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Import failed: Invalid Base64 or JSON format.',
            style: _font(14),
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          backgroundColor: const Color(0xFF8B2500),
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
    return Scaffold(
      backgroundColor: _black,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(width: 44, height: 44, decoration: _panel(radius: 8), child: const Icon(Icons.arrow_back_rounded, color: _gold, size: 21)),
                  ),
                  const SizedBox(width: 16),
                  Text('AI & Deck Sharing', style: _font(24, weight: FontWeight.w300)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text('AI PROMPT BUILDER', style: _font(11, weight: FontWeight.w500, spacing: 1.6, color: _textDim)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: _panel(radius: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Create a prompt to generate cards using any AI assistant (ChatGPT, Gemini, etc).', style: _font(13, color: _textDim)),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _topicController,
                          style: _font(15),
                          cursorColor: _gold,
                          decoration: InputDecoration(
                            hintText: 'Enter topic (e.g., 90s Hip Hop, Anime...)',
                            hintStyle: _font(15, color: _textDim),
                            border: InputBorder.none,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Text('Cards: $_cardCount', style: _font(13, color: _gold)),
                            Expanded(
                              child: Slider(
                                value: _cardCount.toDouble(),
                                min: 10,
                                max: 40,
                                divisions: 6,
                                activeColor: _gold,
                                inactiveColor: _panelTop,
                                onChanged: (val) => setState(() => _cardCount = val.toInt()),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF17140C),
                              foregroundColor: _gold,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: _gold, width: 0.9)),
                            ),
                            onPressed: _generatePrompt,
                            child: Text(_isCopied ? 'Copied Prompt to Clipboard!' : 'Copy AI Prompt', style: _font(14, weight: FontWeight.w500, color: _gold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('IMPORT / SHARE DECK CODE', style: _font(11, weight: FontWeight.w500, spacing: 1.6, color: _textDim)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: _panel(radius: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Paste a JSON or Base64 share code from a friend to import their deck instantly.', style: _font(13, color: _textDim)),
                        const SizedBox(height: 14),
                        Container(
                          height: 100,
                          decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8), border: Border.all(color: _gold.withValues(alpha: 0.2))),
                          padding: const EdgeInsets.all(8),
                          child: TextField(
                            controller: _importController,
                            maxLines: 4,
                            style: _font(13),
                            cursorColor: _gold,
                            decoration: InputDecoration(hintText: 'Paste Base64 code here...', hintStyle: _font(13, color: _textDim), border: InputBorder.none),
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _gold,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: _importDeck,
                            child: Text('Import & Save Deck', style: _font(14, weight: FontWeight.w500, color: Colors.black)),
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
    );
  }
}
