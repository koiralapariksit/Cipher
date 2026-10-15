import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/deck.dart';
import '../services/storage_service.dart';
import '../theme/luxury_theme.dart';

/// Screen for creating or editing custom card decks.
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

  late String _selectedEmoji;
  late int _selectedColor;
  late String _selectedCategory;
  late List<String> _words;

  final StorageService _storage = StorageService();

  static const List<String> _emojiOptions = [
    '🎯', '🔥', '🚀', '🧠', '👑', '🎉',
    '🐱', '🍕', '🎮', '💡', '🎸', '⚽',
    '👻', '💎', '🌈', '⚡', '🏆', '🍿',
    '🎭', '🤖', '🏖️', '🍔', '🦄', '🎧',
  ];

  static const List<int> _colorOptions = [
    0xFFC8A45C, // Metallic Gold
    0xFF38BDF8, // Electric Blue
    0xFFF43F5E, // Coral Rose
    0xFF4E9F6E, // Luxury Emerald
    0xFFD47A45, // Terracotta Amber
    0xFF8B5CF6, // Royal Violet
    0xFFEC4899, // Hot Magenta
    0xFF06B6D4, // Cyan
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
      _selectedEmoji = _emojiOptions.first;
      _selectedColor = _colorOptions.first;
      _selectedCategory = _categoryOptions.first;
      _words = [];
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _wordInputController.dispose();
    super.dispose();
  }

  void _addWordsFromInput() {
    final raw = _wordInputController.text;
    if (raw.trim().isEmpty) {
      _showSnack('Please type or paste some words first.');
      return;
    }

    // Support comma-separated or newline-separated bulk pasting
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
        backgroundColor: kPanelTop,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: kGold.withValues(alpha: 0.5), width: 1),
        ),
        title: Text(
          'Edit Card Word',
          style: luxuryFont(18, weight: FontWeight.w500, color: kGold),
        ),
        content: Container(
          decoration: luxuryPanel(radius: 12),
          child: TextField(
            controller: controller,
            autofocus: true,
            style: luxuryFont(15, color: kText),
            cursorColor: kGold,
            decoration: InputDecoration(
              hintText: 'Enter word',
              hintStyle: luxuryFont(14, color: kTextDim),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('CANCEL',
                style: luxuryFont(13, color: kTextDim, spacing: 1)),
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
              decoration: luxuryPanel(radius: 10, highlight: true),
              child: Text(
                'SAVE',
                style: luxuryFont(13,
                    weight: FontWeight.w500, color: kGold, spacing: 1),
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
        backgroundColor: kPanelTop,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: kPassAmber.withValues(alpha: 0.6), width: 1),
        ),
        title: Text(
          'Delete Deck?',
          style: luxuryFont(18, weight: FontWeight.w500, color: kPassAmber),
        ),
        content: Text(
          'Are you sure you want to delete "${widget.deck!.name}"? This action cannot be undone.',
          style: luxuryFont(14, color: kTextDim, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('CANCEL',
                style: luxuryFont(13, color: kTextDim, spacing: 1)),
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
                color: kPassAmber.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kPassAmber, width: 1),
              ),
              child: Text(
                'DELETE',
                style: luxuryFont(13,
                    weight: FontWeight.w500, color: kPassAmber, spacing: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _shareDeckCode() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showSnack('Please give your deck a name before sharing.');
      return;
    }
    if (_words.isEmpty) {
      _showSnack('Please add some cards to your deck before sharing.');
      return;
    }

    final deck = Deck(
      id: widget.deck?.id ?? 'custom_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      emoji: _selectedEmoji,
      colorValue: _selectedColor,
      items: _words,
      isCustom: true,
      category: _selectedCategory,
    );

    final base64Code = base64Encode(utf8.encode(jsonEncode(deck.toJson())));
    Clipboard.setData(ClipboardData(text: base64Code));

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Deck share code copied! Send it to a friend to import.',
          style: luxuryFont(14, color: Colors.black, weight: FontWeight.w500),
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        backgroundColor: kGold,
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
        content: Text(msg, style: luxuryFont(14, color: kText)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: kGold.withValues(alpha: 0.4), width: 0.8),
        ),
        backgroundColor: kPanelTop,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.deck != null;

    return Scaffold(
      backgroundColor: kBlack,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Row(
                children: [
                  LuxuryRoundButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Back',
                    onTap: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    isEditing ? 'Edit Deck' : 'Create Deck',
                    style:
                        luxuryFont(26, weight: FontWeight.w300, spacing: 0.5),
                  ),
                  const Spacer(),
                  if (isEditing) ...[
                    LuxuryRoundButton(
                      icon: Icons.share_outlined,
                      tooltip: 'Share Deck Code (Base64)',
                      onTap: _shareDeckCode,
                    ),
                    const SizedBox(width: 10),
                    LuxuryRoundButton(
                      icon: Icons.delete_outline_rounded,
                      tooltip: 'Delete Deck',
                      iconColor: kPassAmber,
                      onTap: _deleteDeckConfirm,
                    ),
                    const SizedBox(width: 10),
                  ],
                  GestureDetector(
                    onTap: _saveDeck,
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      decoration: luxuryPanel(
                        radius: 22,
                        highlight: true,
                        fillTop: const Color(0xFF241F14),
                        fillBottom: const Color(0xFF14110A),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_rounded,
                              color: kGold, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            'SAVE',
                            style: luxuryFont(13,
                                weight: FontWeight.w500,
                                spacing: 1.2,
                                color: kGold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Form body
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  children: [
                    // Preview Card
                    _buildPreviewHeader(),
                    const SizedBox(height: 14),

                    // Share Deck Code Action Tile
                    GestureDetector(
                      onTap: _shareDeckCode,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: luxuryPanel(radius: 16),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: kSelectedFill,
                                border: Border.all(
                                  color: kGold.withValues(alpha: 0.4),
                                  width: 0.8,
                                ),
                              ),
                              child: const Icon(Icons.share_outlined,
                                  color: kGold, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Share Deck Code (Base64)',
                                    style: luxuryFont(14,
                                        weight: FontWeight.w500, color: kText),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Copy Base64 code to clipboard for friends to import',
                                    style: luxuryFont(11, color: kTextDim),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.copy_rounded,
                                color: kGold, size: 18),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Deck Name Input
                    LuxurySectionHeader(title: 'Deck Title'),
                    const SizedBox(height: 10),
                    Container(
                      height: 48,
                      decoration: luxuryPanel(radius: 14),
                      child: TextFormField(
                        controller: _nameController,
                        style: luxuryFont(15, color: kText),
                        cursorColor: kGold,
                        decoration: InputDecoration(
                          hintText: 'e.g. 90s Nostalgia, Harry Potter...',
                          hintStyle: luxuryFont(14, color: kTextDim),
                          prefixIcon: const Icon(Icons.stars_rounded,
                              color: kGold, size: 20),
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
                    _buildEmojiPicker(),
                    const SizedBox(height: 20),
                    _buildColorPicker(),
                    const SizedBox(height: 24),

                    // Cards List Section Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              'CARDS',
                              style: luxuryFont(11,
                                  weight: FontWeight.w500, spacing: 1.6),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _words.length >= 5
                                    ? kCorrectGreen.withValues(alpha: 0.15)
                                    : kPassAmber.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _words.length >= 5
                                      ? kCorrectGreen.withValues(alpha: 0.5)
                                      : kPassAmber.withValues(alpha: 0.5),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                _words.length >= 5
                                    ? '${_words.length} cards'
                                    : '${_words.length}/5 minimum',
                                style: luxuryFont(
                                  10,
                                  weight: FontWeight.w500,
                                  color: _words.length >= 5
                                      ? kCorrectGreen
                                      : kPassAmber,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_words.isNotEmpty)
                          GestureDetector(
                            onTap: () => setState(() => _words.clear()),
                            child: Text(
                              'CLEAR ALL',
                              style: luxuryFont(11,
                                  weight: FontWeight.w500,
                                  spacing: 1.2,
                                  color: kPassAmber),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 0.8,
                      color: kGold.withValues(alpha: 0.45),
                    ),
                    const SizedBox(height: 12),

                    if (_words.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 36),
                        decoration: luxuryPanel(radius: 18),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.add_circle_outline_rounded,
                                  color: kGold.withValues(alpha: 0.5),
                                  size: 34),
                              const SizedBox(height: 10),
                              Text(
                                'No cards yet.\nType or paste words below to begin.',
                                textAlign: TextAlign.center,
                                style: luxuryFont(13,
                                    color: kTextDim, height: 1.4),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Container(
                        decoration: luxuryPanel(radius: 18),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _words.length,
                            separatorBuilder: (_, _) => Divider(
                              height: 1,
                              color: kGold.withValues(alpha: 0.12),
                            ),
                            itemBuilder: (ctx, index) {
                              final word = _words[index];
                              return ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 2),
                                leading: Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: kSelectedFill,
                                    border: Border.all(
                                      color: kGold.withValues(alpha: 0.4),
                                      width: 0.8,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '${index + 1}',
                                    style: luxuryFont(
                                      11,
                                      weight: FontWeight.w500,
                                      color: kGold,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  word,
                                  style: luxuryFont(15,
                                      weight: FontWeight.w400, color: kText),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined,
                                          size: 18, color: kTextDim),
                                      onPressed: () => _editWord(index),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close_rounded,
                                          size: 18, color: kPassAmber),
                                      onPressed: () {
                                        setState(() => _words.removeAt(index));
                                      },
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

            // Bottom Input Bar for Single or Bulk Words
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [kPanelTop, kPanelBottom],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                border: Border(
                  top: BorderSide(
                    color: kGold.withValues(alpha: 0.3),
                    width: 0.8,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.9),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 46,
                      decoration: luxuryPanel(radius: 14),
                      child: TextField(
                        controller: _wordInputController,
                        style: luxuryFont(14, color: kText),
                        cursorColor: kGold,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _addWordsFromInput(),
                        decoration: InputDecoration(
                          hintText:
                              'Add word or paste list (comma / newline)...',
                          hintStyle: luxuryFont(13, color: kTextDim),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 13),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _addWordsFromInput,
                    child: Container(
                      height: 46,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      decoration: luxuryPanel(
                        radius: 14,
                        highlight: true,
                        fillTop: const Color(0xFF241F14),
                        fillBottom: const Color(0xFF14110A),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add_rounded,
                              color: kGold, size: 20),
                          const SizedBox(width: 4),
                          Text(
                            'ADD',
                            style: luxuryFont(13,
                                weight: FontWeight.w500,
                                spacing: 1.0,
                                color: kGold),
                          ),
                        ],
                      ),
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

  Widget _buildPreviewHeader() {
    final name = _nameController.text.trim().isEmpty
        ? 'Your Deck Title'
        : _nameController.text;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      decoration: luxuryPanel(radius: 20, highlight: true),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: kSelectedFill,
              border: Border.all(
                color: Color(_selectedColor).withValues(alpha: 0.8),
                width: 1.2,
              ),
            ),
            child: Text(_selectedEmoji, style: const TextStyle(fontSize: 28)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: luxuryFont(20,
                      weight: FontWeight.w400, color: kText, spacing: 0.5),
                ),
                const SizedBox(height: 4),
                Text(
                  '$_selectedCategory • ${_words.length} cards',
                  style: luxuryFont(13,
                      weight: FontWeight.w400, color: Color(_selectedColor)),
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
        LuxurySectionHeader(title: 'Category / Genre'),
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
                  color: isSelected ? kSelectedFill : const Color(0xFF101010),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? kGold.withValues(alpha: 0.85)
                        : Colors.white.withValues(alpha: 0.08),
                    width: isSelected ? 1.0 : 0.8,
                  ),
                ),
                child: Text(
                  cat,
                  style: luxuryFont(
                    13,
                    weight: FontWeight.w500,
                    color: isSelected ? kGold : kTextDim,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildEmojiPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LuxurySectionHeader(title: 'Deck Icon'),
        const SizedBox(height: 10),
        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _emojiOptions.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (ctx, idx) {
              final emoji = _emojiOptions[idx];
              final isSelected = emoji == _selectedEmoji;
              return GestureDetector(
                onTap: () => setState(() => _selectedEmoji = emoji),
                child: Container(
                  width: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color:
                        isSelected ? kSelectedFill : const Color(0xFF101010),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? kGold.withValues(alpha: 0.9)
                          : Colors.white.withValues(alpha: 0.08),
                      width: isSelected ? 1.2 : 0.8,
                    ),
                  ),
                  child: Text(emoji, style: const TextStyle(fontSize: 22)),
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
        LuxurySectionHeader(title: 'Color Accent'),
        const SizedBox(height: 10),
        SizedBox(
          height: 42,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _colorOptions.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (ctx, idx) {
              final colorVal = _colorOptions[idx];
              final isSelected = colorVal == _selectedColor;
              return GestureDetector(
                onTap: () => setState(() => _selectedColor = colorVal),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Color(colorVal),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? kGold : Colors.black45,
                      width: isSelected ? 2.5 : 1.0,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: Color(colorVal).withValues(alpha: 0.5),
                              blurRadius: 8,
                              spreadRadius: 1,
                            )
                          ]
                        : null,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check_rounded,
                          size: 20, color: Colors.white)
                      : null,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
