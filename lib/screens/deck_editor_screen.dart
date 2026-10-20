import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/deck.dart';
import '../services/groq_deck_service.dart';
import '../services/storage_service.dart';
import '../theme/deck_colors.dart';

/// Screen for creating or editing custom card decks — 100% Neo-Brutalist.
class DeckEditorScreen extends StatefulWidget {
  final Deck? deck; // null if creating a new deck

  const DeckEditorScreen({super.key, this.deck});

  @override
  State<DeckEditorScreen> createState() => _DeckEditorScreenState();
}

class _DeckEditorScreenState extends State<DeckEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _wordInputController = TextEditingController();
  final _aiTopicController = TextEditingController();
  bool _isAiGenerating = false;

  late String _selectedEmoji;
  late int _selectedColor;
  late String _selectedCategory;
  late List<String> _words;

  final StorageService _storage = StorageService();

  static const List<({IconData icon, String key})> _deckIconOptions = [
    (icon: Icons.style_outlined, key: '🎯'),
    (icon: Icons.local_fire_department_outlined, key: '🔥'),
    (icon: Icons.lightbulb_outlined, key: '💡'),
    (icon: Icons.psychology_outlined, key: '🧠'),
    (icon: Icons.celebration_outlined, key: '🎉'),
    (icon: Icons.sports_esports_outlined, key: '🎮'),
    (icon: Icons.music_note_outlined, key: '🎸'),
    (icon: Icons.sports_soccer_outlined, key: '⚽'),
    (icon: Icons.movie_outlined, key: '🍿'),
    (icon: Icons.theater_comedy_outlined, key: '🎭'),
    (icon: Icons.smart_toy_outlined, key: '🤖'),
    (icon: Icons.palette_outlined, key: '🎨'),
    (icon: Icons.flight_takeoff_rounded, key: '🚀'),
    (icon: Icons.pets_outlined, key: '🐱'),
    (icon: Icons.restaurant_outlined, key: '🍕'),
    (icon: Icons.diamond_outlined, key: '💎'),
    (icon: Icons.flash_on_outlined, key: '⚡'),
    (icon: Icons.military_tech_outlined, key: '🏆'),
    (icon: Icons.beach_access_outlined, key: '🏖️'),
    (icon: Icons.headphones_outlined, key: '🎧'),
  ];

  static const List<int> _colorOptions = [
    0xFFFF7A1A, // Orange
    0xFFFF3D8B, // Pink
    0xFFC9B6FF, // Lavender
    0xFFFFD60A, // Yellow
    0xFF1FE08F, // Mint
    0xFF2F5BFF, // Blue
    0xFFB8F400, // Lime
    0xFF8E8E93, // Slate
  ];

  static const List<String> _categoryOptions = [
    'Custom',
    'Party',
    'Trivia',
    'Pop Culture',
    'Kids',
    'Activity',
    'Movies',
    'General',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.deck != null) {
      _nameController.text = widget.deck!.name;
      _selectedEmoji = widget.deck!.emoji;
      _selectedColor = widget.deck!.colorValue;
      _selectedCategory = widget.deck!.category;
      _words = List.from(widget.deck!.items);
    } else {
      _nameController.text = '';
      _selectedEmoji = _deckIconOptions.first.key;
      _selectedColor = _colorOptions.first;
      _selectedCategory = _categoryOptions.first;
      _words = [];
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _wordInputController.dispose();
    _aiTopicController.dispose();
    super.dispose();
  }

  Future<void> _generateAiWords() async {
    final topic = _aiTopicController.text.trim();
    if (topic.isEmpty) {
      _showSnack('Type a topic for AI generation first.');
      return;
    }

    FocusScope.of(context).unfocus();
    HapticFeedback.lightImpact();
    setState(() => _isAiGenerating = true);

    try {
      final deck = await GroqDeckService().generateDeck(
        topic: topic,
        cardCount: 25,
        difficulty: 'Party',
      );

      int addedCount = 0;
      for (final item in deck.items) {
        final clean = item.trim();
        if (clean.isEmpty) continue;
        if (!_words.any((w) => w.toLowerCase() == clean.toLowerCase())) {
          _words.insert(0, clean);
          addedCount++;
        }
      }

      if (_nameController.text.trim().isEmpty) {
        _nameController.text = deck.name;
      }

      _aiTopicController.clear();
      HapticFeedback.heavyImpact();
      _showSnack('Added $addedCount words from AI!');
    } catch (e) {
      final isOnline = await GroqDeckService().isGroqOnline();
      if (!isOnline) {
        _showSnack('No internet connection! Check your Wi-Fi and try again.');
      } else if (e.toString().contains('busy')) {
        _showSnack('AI generator is busy. Please try again in a moment.');
      } else {
        _showSnack('Failed to generate cards. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _isAiGenerating = false);
      }
    }
  }

  void _addWordsFromInput() {
    final raw = _wordInputController.text;
    if (raw.trim().isEmpty) {
      _showSnack('Please type or paste some words first.');
      return;
    }

    final splits = raw.split(RegExp(r'[\n,]+'));
    int addedCount = 0;
    int duplicateCount = 0;

    for (final part in splits) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;
      final lower = trimmed.toLowerCase();
      if (_words.any((w) => w.toLowerCase() == lower)) {
        duplicateCount++;
      } else {
        _words.insert(0, trimmed);
        addedCount++;
      }
    }

    setState(() {
      _wordInputController.clear();
    });

    if (addedCount > 1) {
      final duplicateSuffix =
          duplicateCount > 0 ? ' ($duplicateCount duplicates skipped)' : '';
      _showSnack('Added $addedCount cards!$duplicateSuffix');
    } else if (addedCount == 0 && duplicateCount > 0) {
      _showSnack('Notice: Card word is already in this deck.');
    }
  }

  void _editWord(int index) {
    final controller = TextEditingController(text: _words[index]);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kInk,
        shape: RoundedRectangleBorder(
          borderRadius: kAsymmetricRadius,
          side: const BorderSide(color: kCream, width: 3.5),
        ),
        title: Text(
          'Edit Card Word',
          style: GoogleFonts.bowlbyOne(fontSize: 20, color: kYellow),
        ),
        content: Container(
          decoration: BoxDecoration(
            color: kCream,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: kInk, width: 2.0),
            boxShadow: kSmallShadow,
          ),
          child: TextField(
            controller: controller,
            autofocus: true,
            enableSuggestions: false,
            autocorrect: false,
            style: GoogleFonts.dmSans(
                fontSize: 16, fontWeight: FontWeight.w700, color: kInk),
            cursorColor: kInk,
            decoration: InputDecoration(
              hintText: 'Enter word',
              hintStyle: GoogleFonts.dmSans(fontSize: 14, color: kInkDim),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'CANCEL',
              style: GoogleFonts.bowlbyOne(fontSize: 13, color: kCream),
            ),
          ),
          GestureDetector(
            onTap: () {
              final newWord = controller.text.trim();
              if (newWord.isNotEmpty) {
                setState(() => _words[index] = newWord);
              }
              Navigator.pop(ctx);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: kLime,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: kInk, width: 2.0),
                boxShadow: kSmallShadow,
              ),
              child: Text(
                'SAVE',
                style: GoogleFonts.bowlbyOne(fontSize: 13, color: kInk),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _deleteDeckConfirm() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kInk,
        shape: RoundedRectangleBorder(
          borderRadius: kAsymmetricRadius,
          side: const BorderSide(color: kCream, width: 3.5),
        ),
        title: Text(
          'Delete Deck?',
          style: GoogleFonts.bowlbyOne(fontSize: 22, color: kPink),
        ),
        content: Text(
          'Are you sure you want to delete "${widget.deck!.name}"? This action cannot be undone.',
          style: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: kCream,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'CANCEL',
              style: GoogleFonts.bowlbyOne(fontSize: 13, color: kCream),
            ),
          ),
          GestureDetector(
            onTap: () async {
              Navigator.pop(ctx);
              await _storage.deleteDeck(widget.deck!.id);
              if (!mounted) return;
              Navigator.pop(context, true);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: kPink,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: kInk, width: 2.0),
                boxShadow: kSmallShadow,
              ),
              child: Text(
                'DELETE',
                style: GoogleFonts.bowlbyOne(fontSize: 13, color: kInk),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveDeck() async {
    if (!_formKey.currentState!.validate()) return;

    if (_words.length < 5) {
      _showSnack(
          'Please add at least 5 cards to save this deck (currently ${_words.length}).');
      return;
    }

    final deck = Deck(
      id: widget.deck?.id ?? 'custom_${DateTime.now().millisecondsSinceEpoch}',
      name: _nameController.text.trim(),
      emoji: _selectedEmoji,
      colorValue: _selectedColor,
      items: _words,
      isCustom: true,
      category: _selectedCategory,
    );

    await _storage.saveDeck(deck);

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
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
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.deck != null;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: kBlue,
        body: SafeArea(
          child: Column(
            children: [
              // ── Custom Neo-Brutalist Header ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
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
                              text: isEditing ? 'Edit Deck' : 'New Deck',
                              style: GoogleFonts.bowlbyOne(
                                fontSize: 30,
                                color: kCream,
                                height: 0.95,
                              ),
                            ),
                            TextSpan(
                              text: '!',
                              style: GoogleFonts.bowlbyOne(
                                fontSize: 30,
                                color: kYellow,
                                height: 0.95,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (isEditing) ...[
                      GestureDetector(
                        onTap: _deleteDeckConfirm,
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: kPink,
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(color: kInk, width: 2.0),
                            boxShadow: kSmallShadow,
                          ),
                          child: const Icon(Icons.delete_outline_rounded,
                              size: 20, color: kInk),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    GestureDetector(
                      onTap: _saveDeck,
                      child: Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: kLime,
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(color: kInk, width: 2.0),
                          boxShadow: kSmallShadow,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'SAVE',
                          style: GoogleFonts.bowlbyOne(
                            fontSize: 13,
                            color: kInk,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Form Body ──
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    children: [
                      // Preview Card
                      _buildPreviewHeader(),
                      const SizedBox(height: 18),

                      // Deck Name Input
                      _buildSectionHeader('DECK TITLE', kYellow),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: kCream,
                          borderRadius: kAsymmetricRadius,
                          border: Border.all(color: kInk, width: 2.5),
                          boxShadow: kHardShadow,
                        ),
                        child: TextFormField(
                          controller: _nameController,
                          enableSuggestions: false,
                          autocorrect: false,
                          style: GoogleFonts.dmSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: kInk,
                          ),
                          cursorColor: kInk,
                          decoration: InputDecoration(
                            hintText: 'e.g. 90s Nostalgia, World History...',
                            hintStyle: GoogleFonts.dmSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: kInkDim,
                            ),
                            prefixIcon: const Icon(Icons.edit_note_rounded,
                                color: kInk, size: 24),
                            border: InputBorder.none,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 14),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please enter a deck name.';
                            }
                            return null;
                          },
                          onChanged: (_) => setState(() {}),
                        ),
                      ),

                      const SizedBox(height: 20),
                      _buildCategorySelector(),
                      const SizedBox(height: 20),
                      _buildDeckIconPicker(),
                      const SizedBox(height: 20),
                      _buildColorPicker(),
                      const SizedBox(height: 24),
                      _buildAiAutoFillCard(),
                      const SizedBox(height: 24),

                      // Cards List Section Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              _buildSectionHeader('CARDS', kLime),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _words.length >= 5 ? kLime : kOrange,
                                  borderRadius: BorderRadius.circular(99),
                                  border: Border.all(color: kInk, width: 2.0),
                                  boxShadow: kSmallShadow,
                                ),
                                child: Text(
                                  _words.length >= 5
                                      ? '${_words.length} cards'
                                      : '${_words.length}/5 minimum',
                                  style: GoogleFonts.bowlbyOne(
                                    fontSize: 11,
                                    color: kInk,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_words.isNotEmpty)
                            GestureDetector(
                              onTap: () => setState(() => _words.clear()),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: kPink,
                                  borderRadius: BorderRadius.circular(99),
                                  border: Border.all(color: kInk, width: 1.5),
                                ),
                                child: Text(
                                  'Clear all',
                                  style: GoogleFonts.bowlbyOne(
                                    fontSize: 11,
                                    color: kInk,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (_words.isEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 36),
                          decoration: BoxDecoration(
                            color: kCream,
                            borderRadius: kAsymmetricRadius,
                            border: Border.all(color: kInk, width: 3.0),
                            boxShadow: kCardShadow,
                          ),
                          child: Center(
                            child: Column(
                              children: [
                                const Icon(Icons.add_circle_outline_rounded,
                                    color: kInk, size: 36),
                                const SizedBox(height: 10),
                                Text(
                                  'No cards yet.\nType or paste words below to begin.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: kInkDim,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Container(
                          decoration: BoxDecoration(
                            color: kCream,
                            borderRadius: kAsymmetricRadius,
                            border: Border.all(color: kInk, width: 3.0),
                            boxShadow: kCardShadow,
                          ),
                          child: ClipRRect(
                            borderRadius: kAsymmetricRadius,
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              itemCount: _words.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 6),
                              itemBuilder: (ctx, index) {
                                final word = _words[index];
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: kAsymmetricSmallRadius,
                                    border: Border.all(color: kInk, width: 2.0),
                                    boxShadow: kSmallShadow,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 26,
                                        height: 26,
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(99),
                                          color: kYellow,
                                          border: Border.all(
                                              color: kInk, width: 1.5),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          '${index + 1}',
                                          style: GoogleFonts.bowlbyOne(
                                            fontSize: 10,
                                            color: kInk,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          word,
                                          style: GoogleFonts.dmSans(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: kInk,
                                          ),
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () => _editWord(index),
                                        child: Container(
                                          width: 28,
                                          height: 28,
                                          decoration: BoxDecoration(
                                            color: kYellow,
                                            borderRadius:
                                                BorderRadius.circular(99),
                                            border: Border.all(
                                                color: kInk, width: 1.5),
                                          ),
                                          child: const Icon(
                                              Icons.edit_outlined,
                                              size: 15,
                                              color: kInk),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      GestureDetector(
                                        onTap: () {
                                          setState(
                                              () => _words.removeAt(index));
                                        },
                                        child: Container(
                                          width: 28,
                                          height: 28,
                                          decoration: BoxDecoration(
                                            color: kPink,
                                            borderRadius:
                                                BorderRadius.circular(99),
                                            border: Border.all(
                                                color: kInk, width: 1.5),
                                          ),
                                          child: const Icon(
                                              Icons.close_rounded,
                                              size: 15,
                                              color: kInk),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

              // ── Bottom Input Bar for Single or Bulk Words ──
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                decoration: const BoxDecoration(
                  color: kCream,
                  border: Border(
                    top: BorderSide(color: kInk, width: 3.0),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(color: kInk, width: 2.0),
                          boxShadow: kSmallShadow,
                        ),
                        child: TextField(
                          controller: _wordInputController,
                          enableSuggestions: false,
                          autocorrect: false,
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: kInk,
                          ),
                          cursorColor: kInk,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _addWordsFromInput(),
                          decoration: InputDecoration(
                            hintText:
                                'Add word or paste list (comma / newline)...',
                            hintStyle: GoogleFonts.dmSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: kInkDim,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: _addWordsFromInput,
                      child: Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          color: kYellow,
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(color: kInk, width: 2.0),
                          boxShadow: kSmallShadow,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'ADD',
                          style: GoogleFonts.bowlbyOne(
                            fontSize: 13,
                            color: kInk,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
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

  Widget _buildPreviewHeader() {
    final name = _nameController.text.trim().isEmpty
        ? 'Your Deck Title'
        : _nameController.text;

    final selectedIcon = _deckIconOptions
        .firstWhere((e) => e.key == _selectedEmoji,
            orElse: () => (icon: Icons.style_outlined, key: '🎯'))
        .icon;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCream,
        borderRadius: kAsymmetricRadius,
        border: Border.all(color: kInk, width: 3.0),
        boxShadow: kCardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(99),
              color: Color(_selectedColor),
              border: Border.all(color: kInk, width: 2.5),
              boxShadow: kSmallShadow,
            ),
            child: Icon(
              selectedIcon,
              size: 26,
              color: kInk,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.bowlbyOne(
                    fontSize: 18,
                    color: kInk,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$_selectedCategory • ${_words.length} cards',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: kInkDim,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('CATEGORY / GENRE', kLavender),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _categoryOptions.map((cat) {
            final isSelected = cat == _selectedCategory;
            return GestureDetector(
              onTap: () => setState(() => _selectedCategory = cat),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected ? kYellow : kCream,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: kInk, width: 2.0),
                  boxShadow: isSelected ? kSmallShadow : null,
                ),
                child: Text(
                  cat,
                  style: isSelected
                      ? GoogleFonts.bowlbyOne(
                          fontSize: 12,
                          color: kInk,
                        )
                      : GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: kInk,
                        ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDeckIconPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('DECK ICON BADGE', kMint),
        const SizedBox(height: 10),
        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _deckIconOptions.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (ctx, idx) {
              final opt = _deckIconOptions[idx];
              final isSelected = opt.key == _selectedEmoji;
              return GestureDetector(
                onTap: () => setState(() => _selectedEmoji = opt.key),
                child: Container(
                  width: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected ? kLime : kCream,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color: kInk,
                      width: isSelected ? 2.5 : 2.0,
                    ),
                    boxShadow: isSelected ? kSmallShadow : null,
                  ),
                  child: Icon(
                    opt.icon,
                    size: 22,
                    color: kInk,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildColorPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('COLOR ACCENT', kOrange),
        const SizedBox(height: 10),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _colorOptions.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (ctx, idx) {
              final colorVal = _colorOptions[idx];
              final isSelected = colorVal == _selectedColor;
              return GestureDetector(
                onTap: () => setState(() => _selectedColor = colorVal),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Color(colorVal),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color: kInk,
                      width: isSelected ? 3.0 : 2.0,
                    ),
                    boxShadow: isSelected ? kSmallShadow : null,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check_rounded,
                          size: 22, color: kInk)
                      : null,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAiAutoFillCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kLime,
        borderRadius: kAsymmetricRadius,
        border: Border.all(color: kInk, width: 2.0),
        boxShadow: kCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: kInk, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'OPTIONAL: AUTO-FILL WITH AI',
                  style: GoogleFonts.bowlbyOne(
                    fontSize: 16,
                    color: kInk,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: kCream,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: kInk, width: 2.0),
              boxShadow: kSmallShadow,
            ),
            child: TextField(
              controller: _aiTopicController,
              enableSuggestions: false,
              autocorrect: false,
              style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: kInk,
              ),
              cursorColor: kInk,
              decoration: InputDecoration(
                hintText: 'Type any topic to generate words...',
                hintStyle: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: kInkDim,
                ),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: kInk, size: 20),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              onSubmitted: (_) => _isAiGenerating ? null : _generateAiWords(),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: _isAiGenerating ? null : _generateAiWords,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: kInk,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: kInk, width: 2.0),
                  boxShadow: kSmallShadow,
                ),
                child: _isAiGenerating
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: kLime,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'GENERATING...',
                            style: GoogleFonts.bowlbyOne(
                              fontSize: 13,
                              color: kLime,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        'GENERATE WORDS',
                        style: GoogleFonts.bowlbyOne(
                          fontSize: 13,
                          color: kLime,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
