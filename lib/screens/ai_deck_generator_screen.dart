import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/deck.dart';
import '../services/groq_deck_service.dart';
import '../theme/app_theme.dart';
import 'gameplay_screen.dart';

class AiDeckGeneratorScreen extends StatefulWidget {
  const AiDeckGeneratorScreen({super.key});

  @override
  State<AiDeckGeneratorScreen> createState() => _AiDeckGeneratorScreenState();
}

class _AiDeckGeneratorScreenState extends State<AiDeckGeneratorScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _topicController = TextEditingController();
  final GroqDeckService _groqService = GroqDeckService();

  int _selectedCardCount = 25;
  String _selectedVibe = 'Party';
  bool _isGenerating = false;
  String _loadingMessage = 'Encrypting Deck...';

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  static const List<String> _suggestions = [
    '90s Rock Bands',
    'Sci-Fi Movies',
    'Football Legends',
    'Retro Games',
    'Netflix Binge',
    'World Capitals',
    'Anime & Manga',
    'Street Food',
    'Superheroes',
    'Sitcom Quotes',
  ];

  static const List<int> _cardCounts = [15, 25, 40, 50];

  static const List<({String label, String subtitle, IconData icon})> _vibes = [
    (
      label: 'Casual',
      subtitle: 'Popular & relaxed',
      icon: Icons.spa_outlined,
    ),
    (
      label: 'Party',
      subtitle: 'Fast & crowd-friendly',
      icon: Icons.celebration_outlined,
    ),
    (
      label: 'Hardcore',
      subtitle: 'Deep-cut trivia',
      icon: Icons.local_fire_department_outlined,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _topicController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _topicController.dispose();
    super.dispose();
  }

  void _selectSuggestion(String topic) {
    HapticFeedback.selectionClick();
    _topicController.text = topic;
    _topicController.selection = TextSelection.fromPosition(
      TextPosition(offset: topic.length),
    );
  }

  /// Full in-app Groq + Live Web Search AI Deck Generator pipeline.
  Future<void> _onGenerateDeckPressed() async {
    final topic = _topicController.text.trim();
    if (topic.isEmpty) {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please enter a topic or pick a suggestion.',
            style: appFont(14, color: appText),
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(appRadius),
          ),
          backgroundColor: appBgMid,
        ),
      );
      return;
    }

    HapticFeedback.lightImpact();
    setState(() {
      _isGenerating = true;
      _loadingMessage = 'Grounding via Live Web Search...';
    });

    try {
      final deck = await _groqService.generateDeck(
        topic: topic,
        cardCount: _selectedCardCount,
        difficulty: _selectedVibe,
        onProgress: (step) {
          if (mounted) {
            setState(() => _loadingMessage = step);
          }
        },
      );

      if (!mounted) return;

      setState(() {
        _isGenerating = false;
        _loadingMessage = 'Encrypting Deck...';
      });

      HapticFeedback.heavyImpact();
      _showDeckSuccessModal(deck);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isGenerating = false;
        _loadingMessage = 'Encrypting Deck...';
      });

      final errorMessage = e.toString().replaceAll('Exception:', '').trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            errorMessage,
            style: appFont(13, color: appText),
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(appRadius),
          ),
          backgroundColor: appBgMid,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'API Key',
            textColor: appCorrect,
            onPressed: _showApiKeyDialog,
          ),
        ),
      );
    }
  }

  /// Dialog allowing user to verify or update their Groq API Key on device.
  void _showApiKeyDialog() async {
    final currentKey = await _groqService.getApiKey() ?? '';
    if (!mounted) return;

    final controller = TextEditingController(text: currentKey);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: appBgMid,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(appRadius),
          side: const BorderSide(color: appLine, width: 0.8),
        ),
        title: Text(
          'Groq API Key',
          style: appFont(16, weight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Key is loaded automatically from .env. You can also override or update it here:',
              style: appFont(12, color: appTextDim, height: 1.35),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: appFieldBox(),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: TextField(
                controller: controller,
                enableSuggestions: false,
                autocorrect: false,
                style: appFont(13),
                cursorColor: appText,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: 'gsk_...',
                  hintStyle: appFont(13, color: appTextDim),
                  border: InputBorder.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: appFont(13, color: appTextDim)),
          ),
          TextButton(
            onPressed: () async {
              await _groqService.saveApiKey(controller.text.trim());
              if (ctx.mounted) Navigator.of(ctx).pop();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Groq API Key updated successfully.',
                        style: appFont(13, color: appText)),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: appBgMid,
                  ),
                );
              }
            },
            child: Text('Save Key',
                style: appFont(13,
                    weight: FontWeight.w700, color: appCorrect)),
          ),
        ],
      ),
    );
  }

  /// Celebratory bottom sheet presenting the newly sealed encrypted deck.
  void _showDeckSuccessModal(Deck deck) {
    showModalBottomSheet(
      context: context,
      backgroundColor: appBgMid,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(appRadius * 3)),
        side: BorderSide(color: appLine, width: 0.8),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                deck.emoji,
                style: const TextStyle(fontSize: 44),
              ),
              const SizedBox(height: 10),
              Text(
                '${deck.name} Encrypted!',
                textAlign: TextAlign.center,
                style: appFont(20, weight: FontWeight.w700, spacing: -0.4),
              ),
              const SizedBox(height: 4),
              Text(
                '${deck.items.length} cards sealed into your library with zero spoilers.',
                textAlign: TextAlign.center,
                style: appFont(13, color: appTextDim),
              ),
              const SizedBox(height: 24),

              // Action 1: Play Now
              GestureDetector(
                onTap: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => GameplayScreen(
                        deck: deck,
                        timerSeconds: 60,
                      ),
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  height: 48,
                  decoration: BoxDecoration(
                    color: appText,
                    borderRadius: BorderRadius.circular(appRadius),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'PLAY THIS DECK NOW',
                    style: appFont(13,
                        weight: FontWeight.w700,
                        spacing: 0.8,
                        color: appBgBottom),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Action 2: Back to Library
              GestureDetector(
                onTap: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pop();
                },
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
                    'DONE · BACK TO DECKS',
                    style: appFont(13,
                        weight: FontWeight.w600, color: appText),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
                // Navigation Header
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AI Deck Generator',
                              style: appFont(22,
                                  weight: FontWeight.w700, spacing: -0.6),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'GROQ LLM · LIVE WEB GROUNDING',
                              style: appFont(10,
                                  weight: FontWeight.w600,
                                  spacing: 1.1,
                                  color: appTextDim),
                            ),
                          ],
                        ),
                      ),
                      AppIconButton(
                        icon: Icons.key_outlined,
                        tooltip: 'Groq API Key',
                        size: 38,
                        onTap: _showApiKeyDialog,
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
                      // Section 1: Topic Input
                      const AppSectionHeader(
                        title: 'Deck Topic',
                        trailing: 'Instant Synthesis',
                      ),
                      const SizedBox(height: 10),

                      // Input Box
                      Container(
                        height: 52,
                        decoration: appFieldBox(),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.auto_awesome,
                              color: appTextDim,
                              size: 18,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _topicController,
                                enabled: !_isGenerating,
                                enableSuggestions: false,
                                autocorrect: false,
                                style: appFont(15, weight: FontWeight.w500),
                                cursorColor: appText,
                                decoration: InputDecoration(
                                  hintText: 'e.g. 90s Rock Bands, Sci-Fi Movies...',
                                  hintStyle: appFont(14, color: appTextDim),
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                              ),
                            ),
                            if (_topicController.text.isNotEmpty && !_isGenerating)
                              GestureDetector(
                                onTap: () {
                                  _topicController.clear();
                                  HapticFeedback.selectionClick();
                                },
                                behavior: HitTestBehavior.opaque,
                                child: const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(
                                    Icons.close_rounded,
                                    color: appTextDim,
                                    size: 16,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Quick-select suggestions
                      Text(
                        'QUICK SUGGESTIONS',
                        style: appFont(10,
                            weight: FontWeight.w600,
                            spacing: 1.0,
                            color: appTextDim),
                      ),
                      const SizedBox(height: 8),

                      SizedBox(
                        height: 34,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: _suggestions.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final topic = _suggestions[index];
                            final isSelected =
                                _topicController.text.trim().toLowerCase() ==
                                    topic.toLowerCase();
                            return GestureDetector(
                              onTap: _isGenerating
                                  ? null
                                  : () => _selectSuggestion(topic),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: isSelected ? appText : appTile,
                                  borderRadius:
                                      BorderRadius.circular(appRadius),
                                  border: Border.all(
                                    color: isSelected ? appText : appLine,
                                    width: 0.8,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  topic,
                                  style: appFont(
                                    12,
                                    weight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color:
                                        isSelected ? appBgBottom : appText,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Section 2: Customization Controls
                      const AppSectionHeader(
                        title: 'Parameters',
                        trailing: 'Card Tuning',
                      ),
                      const SizedBox(height: 14),

                      // Card Count Selector
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'CARD COUNT',
                            style: appFont(11,
                                weight: FontWeight.w600,
                                spacing: 1.0,
                                color: appTextDim),
                          ),
                          Text(
                            '$_selectedCardCount Cards',
                            style: appFont(12,
                                weight: FontWeight.w700, color: appText),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      Row(
                        children: _cardCounts.map((count) {
                          final isSelected = _selectedCardCount == count;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 3),
                              child: GestureDetector(
                                onTap: _isGenerating
                                    ? null
                                    : () {
                                        HapticFeedback.selectionClick();
                                        setState(() => _selectedCardCount = count);
                                      },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: isSelected ? appText : appTile,
                                    borderRadius:
                                        BorderRadius.circular(appRadius),
                                    border: Border.all(
                                      color: isSelected ? appText : appLine,
                                      width: 0.8,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '$count',
                                    style: appFont(
                                      14,
                                      weight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color:
                                          isSelected ? appBgBottom : appText,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 18),

                      // Vibe / Difficulty Selector
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'VIBE & DIFFICULTY',
                            style: appFont(11,
                                weight: FontWeight.w600,
                                spacing: 1.0,
                                color: appTextDim),
                          ),
                          Text(
                            _selectedVibe,
                            style: appFont(12,
                                weight: FontWeight.w700, color: appText),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      Row(
                        children: _vibes.map((vibe) {
                          final isSelected = _selectedVibe == vibe.label;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 3),
                              child: GestureDetector(
                                onTap: _isGenerating
                                    ? null
                                    : () {
                                        HapticFeedback.selectionClick();
                                        setState(() => _selectedVibe = vibe.label);
                                      },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 10, horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? appTile.withValues(alpha: 0.22)
                                        : appTile,
                                    borderRadius:
                                        BorderRadius.circular(appRadius),
                                    border: Border.all(
                                      color: isSelected ? appText : appLine,
                                      width: isSelected ? 1.2 : 0.8,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        vibe.icon,
                                        size: 18,
                                        color:
                                            isSelected ? appText : appTextDim,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        vibe.label,
                                        style: appFont(12,
                                            weight: isSelected
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            color: isSelected
                                                ? appText
                                                : appTextDim),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        vibe.subtitle,
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: appFont(9,
                                            color: appTextDim.withValues(
                                                alpha: 0.8)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 24),

                      // Anti-Spoiler Privacy Seal Notice
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: appTileBox(
                          color: appTile.withValues(alpha: 0.08),
                          borderColor: appLine,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 1),
                              child: Icon(
                                Icons.shield_outlined,
                                color: appTextDim,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Zero-Spoiler Guarantee',
                                    style: appFont(12,
                                        weight: FontWeight.w600,
                                        color: appText),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Cards are synthesized and encrypted directly into your local library. The player holding the phone never sees the wordlist beforehand.',
                                    style: appFont(11,
                                        color: appTextDim, height: 1.35),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Primary Action / Animated Loading State
                      if (!_isGenerating)
                        GestureDetector(
                          onTap: _onGenerateDeckPressed,
                          child: Container(
                            width: double.infinity,
                            height: 50,
                            decoration: BoxDecoration(
                              color: appText,
                              borderRadius:
                                  BorderRadius.circular(appRadius),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.bolt_rounded,
                                  color: appBgBottom,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'GENERATE CIPHER DECK',
                                  style: appFont(13,
                                      weight: FontWeight.w700,
                                      spacing: 0.8,
                                      color: appBgBottom),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        FadeTransition(
                          opacity: _pulseAnimation,
                          child: Container(
                            width: double.infinity,
                            height: 56,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: appTile,
                              borderRadius:
                                  BorderRadius.circular(appRadius),
                              border: Border.all(
                                color: appText,
                                width: 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(appText),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _loadingMessage.toUpperCase(),
                                        style: appFont(11,
                                            weight: FontWeight.w700,
                                            spacing: 0.8,
                                            color: appText),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Synthesizing & concealing words...',
                                        style: appFont(10,
                                            color: appTextDim),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.lock_outline_rounded,
                                  color: appTextDim,
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        ),

                      const SizedBox(height: 20),
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
