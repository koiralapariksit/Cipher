import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/deck.dart';
import '../services/groq_deck_service.dart';
import '../theme/deck_colors.dart';
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
    _pulseAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
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
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: kInk,
            ),
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(99),
            side: const BorderSide(color: kInk, width: 2.0),
          ),
          backgroundColor: kYellow,
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

      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No internet connection! Check your Wi-Fi and try again.',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: kInk,
            ),
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(99),
            side: const BorderSide(color: kInk, width: 2.0),
          ),
          backgroundColor: kOrange,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  /// Celebratory bottom sheet presenting the newly sealed encrypted deck.
  void _showDeckSuccessModal(Deck deck) {
    showModalBottomSheet(
      context: context,
      backgroundColor: kInk,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        side: BorderSide(color: kCream, width: 3.5),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                deck.emoji,
                style: const TextStyle(fontSize: 48),
              ),
              const SizedBox(height: 10),
              Text(
                '${deck.name} Encrypted!',
                textAlign: TextAlign.center,
                style: GoogleFonts.bowlbyOne(
                  fontSize: 22,
                  color: kYellow,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${deck.items.length} cards sealed into your library with zero spoilers.',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: kCream,
                ),
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
                    color: kLime,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: kInk, width: 2.5),
                    boxShadow: const [
                      BoxShadow(
                          color: kInk, offset: Offset(4, 4), blurRadius: 0),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'PLAY THIS DECK NOW',
                    style: GoogleFonts.bowlbyOne(
                      fontSize: 14,
                      color: kInk,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

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
                    color: kCream,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: kInk, width: 2.0),
                    boxShadow: kSmallShadow,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'DONE · BACK TO DECKS',
                    style: GoogleFonts.bowlbyOne(
                      fontSize: 13,
                      color: kInk,
                    ),
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
        backgroundColor: kBlue,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Custom Neo-Brutalist Header ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: kInk,
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(color: kInk, width: 2.0),
                          boxShadow: kSmallShadow,
                        ),
                        child: Text(
                          '✕ BACK',
                          style: GoogleFonts.bowlbyOne(
                            fontSize: 13,
                            color: kCream,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Transform.rotate(
                      angle: -2 * math.pi / 180,
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: 'AI Generator',
                              style: GoogleFonts.bowlbyOne(
                                fontSize: 28,
                                color: kCream,
                                height: 0.95,
                              ),
                            ),
                            TextSpan(
                              text: '!',
                              style: GoogleFonts.bowlbyOne(
                                fontSize: 28,
                                color: kYellow,
                                height: 0.95,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              ),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  children: [
                    // Section 1: Topic Input
                    _buildSectionHeader('DECK TOPIC', kYellow),
                    const SizedBox(height: 8),

                    // Input Box
                    Container(
                      height: 54,
                      decoration: BoxDecoration(
                        color: kCream,
                        borderRadius: kAsymmetricRadius,
                        border: Border.all(color: kInk, width: 2.5),
                        boxShadow: kHardShadow,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.auto_awesome,
                            color: kInk,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _topicController,
                              enabled: !_isGenerating,
                              enableSuggestions: false,
                              autocorrect: false,
                              style: GoogleFonts.dmSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: kInk,
                              ),
                              cursorColor: kInk,
                              decoration: InputDecoration(
                                hintText:
                                    'e.g. 90s Rock Bands, Sci-Fi Movies...',
                                hintStyle: GoogleFonts.dmSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: kInkDim,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                          if (_topicController.text.isNotEmpty &&
                              !_isGenerating)
                            GestureDetector(
                              onTap: () {
                                _topicController.clear();
                                HapticFeedback.selectionClick();
                              },
                              behavior: HitTestBehavior.opaque,
                              child: Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: kPink,
                                  borderRadius: BorderRadius.circular(99),
                                  border: Border.all(color: kInk, width: 1.5),
                                ),
                                child: const Icon(
                                  Icons.close_rounded,
                                  color: kInk,
                                  size: 16,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Quick-select suggestions
                    Text(
                      'QUICK SUGGESTIONS',
                      style: GoogleFonts.bowlbyOne(
                        fontSize: 11,
                        color: kCream,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),

                    SizedBox(
                      height: 38,
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
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(
                                color: isSelected ? kYellow : kCream,
                                borderRadius: BorderRadius.circular(99),
                                border: Border.all(color: kInk, width: 2.0),
                                boxShadow: isSelected ? kSmallShadow : null,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                topic,
                                style: GoogleFonts.dmSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: kInk,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Section 2: Customization Controls
                    _buildSectionHeader('PARAMETERS', kLime),
                    const SizedBox(height: 12),

                    // Card Count Selector
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'CARD COUNT',
                          style: GoogleFonts.bowlbyOne(
                            fontSize: 11,
                            color: kCream,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: kYellow,
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(color: kInk, width: 1.5),
                          ),
                          child: Text(
                            '$_selectedCardCount Cards',
                            style: GoogleFonts.bowlbyOne(
                              fontSize: 11,
                              color: kInk,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    Row(
                      children: _cardCounts.map((count) {
                        final isSelected = _selectedCardCount == count;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: GestureDetector(
                              onTap: _isGenerating
                                  ? null
                                  : () {
                                      HapticFeedback.selectionClick();
                                      setState(
                                          () => _selectedCardCount = count);
                                    },
                              child: Container(
                                height: 42,
                                decoration: BoxDecoration(
                                  color: isSelected ? kYellow : kCream,
                                  borderRadius: BorderRadius.circular(99),
                                  border: Border.all(color: kInk, width: 2.0),
                                  boxShadow: isSelected ? kSmallShadow : null,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '$count',
                                  style: GoogleFonts.bowlbyOne(
                                    fontSize: 14,
                                    color: kInk,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 20),

                    // Vibe / Difficulty Selector
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'VIBE & DIFFICULTY',
                          style: GoogleFonts.bowlbyOne(
                            fontSize: 11,
                            color: kCream,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: kLime,
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(color: kInk, width: 1.5),
                          ),
                          child: Text(
                            _selectedVibe,
                            style: GoogleFonts.bowlbyOne(
                              fontSize: 11,
                              color: kInk,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    Row(
                      children: _vibes.map((vibe) {
                        final isSelected = _selectedVibe == vibe.label;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: GestureDetector(
                              onTap: _isGenerating
                                  ? null
                                  : () {
                                      HapticFeedback.selectionClick();
                                      setState(
                                          () => _selectedVibe = vibe.label);
                                    },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12, horizontal: 8),
                                decoration: BoxDecoration(
                                  color: isSelected ? kLime : kCream,
                                  borderRadius: kAsymmetricRadius,
                                  border: Border.all(
                                    color: kInk,
                                    width: isSelected ? 3.0 : 2.0,
                                  ),
                                  boxShadow: isSelected ? kSmallShadow : null,
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      vibe.icon,
                                      size: 22,
                                      color: kInk,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      vibe.label,
                                      style: GoogleFonts.bowlbyOne(
                                        fontSize: 12,
                                        color: kInk,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      vibe.subtitle,
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.dmSans(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: kInkDim,
                                      ),
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
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: kCream,
                        borderRadius: kAsymmetricRadius,
                        border: Border.all(color: kInk, width: 2.5),
                        boxShadow: kSmallShadow,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: kYellow,
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(color: kInk, width: 1.5),
                            ),
                            child: const Icon(
                              Icons.shield_outlined,
                              color: kInk,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Zero-Spoiler Guarantee',
                                  style: GoogleFonts.bowlbyOne(
                                    fontSize: 13,
                                    color: kInk,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Cards are synthesized and encrypted directly into your local library. The player holding the phone never sees the wordlist beforehand.',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: kInkDim,
                                    height: 1.35,
                                  ),
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
                          height: 52,
                          decoration: BoxDecoration(
                            color: kLime,
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(color: kInk, width: 2.5),
                            boxShadow: const [
                              BoxShadow(
                                color: kInk,
                                offset: Offset(4, 4),
                                blurRadius: 0,
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.bolt_rounded,
                                color: kInk,
                                size: 22,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'GENERATE CIPHER DECK',
                                style: GoogleFonts.bowlbyOne(
                                  fontSize: 15,
                                  color: kInk,
                                  letterSpacing: 0.5,
                                ),
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
                          height: 60,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: kInk,
                            borderRadius: kAsymmetricRadius,
                            border: Border.all(
                              color: kCream,
                              width: 3.0,
                            ),
                            boxShadow: kCardShadow,
                          ),
                          child: Row(
                            children: [
                              const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(kYellow),
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
                                      style: GoogleFonts.bowlbyOne(
                                        fontSize: 12,
                                        color: kYellow,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Synthesizing & concealing words...',
                                      style: GoogleFonts.dmSans(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: kCream,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.lock_outline_rounded,
                                color: kYellow,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color badgeColor) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: badgeColor,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: kInk, width: 2.0),
          boxShadow: kSmallShadow,
        ),
        child: Text(
          title,
          style: GoogleFonts.bowlbyOne(
            fontSize: 12,
            color: kInk,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
