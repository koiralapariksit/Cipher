import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/deck.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

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
    0xFFEDEDED, // Off-white / Silver
    0xFFC8A45C, // Metallic Gold
    0xFFB38F4D, // Warm Bronze
    0xFFD47A45, // Cognac Amber
    0xFF4E9F6E, // Luxury Emerald
    0xFF7A8691, // Muted Slate Stone
    0xFFA65B32, // Deep Terracotta
    0xFF6B8267, // Muted Olive
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
    super.dispose();
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
        backgroundColor: appBgMid,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(appRadius),
          side: const BorderSide(color: appLine, width: 0.8),
        ),
        title: Text(
          'Edit Card Word',
          style: appFont(18, weight: FontWeight.w600, color: appText),
        ),
        content: Container(
          decoration: BoxDecoration(
            color: appField,
            borderRadius: BorderRadius.circular(appRadius),
            border: Border.all(color: appLine, width: 0.8),
          ),
          child: TextField(
            controller: controller,
            autofocus: true,
            enableSuggestions: false,
            autocorrect: false,
            style: appFont(15, color: appText),
            cursorColor: appText,
            decoration: InputDecoration(
              hintText: 'Enter word',
              hintStyle: appFont(14, color: appTextDim),
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
                style: appFont(13, color: appTextDim, spacing: 0.5)),
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
                color: appText,
                borderRadius: BorderRadius.circular(appRadius),
              ),
              child: Text(
                'SAVE',
                style: appFont(13,
                    weight: FontWeight.w600, color: appBgBottom, spacing: 0.5),
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
        backgroundColor: appBgMid,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(appRadius),
          side: const BorderSide(color: appLine, width: 0.8),
        ),
        title: Text(
          'Delete Deck?',
          style: appFont(18, weight: FontWeight.w600, color: appPass),
        ),
        content: Text(
          'Are you sure you want to delete "${widget.deck!.name}"? This action cannot be undone.',
          style: appFont(14, color: appTextDim, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('CANCEL',
                style: appFont(13, color: appTextDim, spacing: 0.5)),
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
                color: appPass.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(appRadius),
                border: Border.all(color: appPass, width: 0.8),
              ),
              child: Text(
                'DELETE',
                style: appFont(13,
                    weight: FontWeight.w600, color: appPass, spacing: 0.5),
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
        content: Text(msg, style: appFont(14, color: appText)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(appRadius),
          side: const BorderSide(color: appLine, width: 0.8),
        ),
        backgroundColor: appBgMid,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.deck != null;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: appBgBottom,
        body: Container(
          decoration: appBackgroundDecoration,
          child: SafeArea(
            child: Column(
              children: [
                // Top Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    children: [
                      AppIconButton(
                        icon: Icons.arrow_back_rounded,
                        tooltip: 'Back',
                        size: 40,
                        onTap: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        isEditing ? 'Edit Deck' : 'Create Deck',
                        style: appFont(24,
                            weight: FontWeight.w700, spacing: -0.6),
                      ),
                      const Spacer(),
                      if (isEditing) ...[
                        AppIconButton(
                          icon: Icons.delete_outline_rounded,
                          tooltip: 'Delete Deck',
                          iconColor: appPass,
                          size: 40,
                          onTap: _deleteDeckConfirm,
                        ),
                        const SizedBox(width: 8),
                      ],
                      GestureDetector(
                        onTap: _saveDeck,
                        child: Container(
                          height: 40,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: appText,
                            borderRadius: BorderRadius.circular(appRadius),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Save',
                            style: appFont(14,
                                weight: FontWeight.w600,
                                color: appBgBottom),
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      children: [
                        // Preview Card
                        _buildPreviewHeader(),
                        const SizedBox(height: 18),

                        // Deck Name Input
                        const AppSectionHeader(title: 'Deck Title'),
                        const SizedBox(height: 10),
                        Container(
                          height: 46,
                          decoration: BoxDecoration(
                            color: appField,
                            borderRadius: BorderRadius.circular(appRadius),
                            border: Border.all(color: appLine, width: 0.8),
                          ),
                          child: TextFormField(
                            controller: _nameController,
                            enableSuggestions: false,
                            autocorrect: false,
                            style: appFont(15, color: appText),
                            cursorColor: appText,
                            decoration: InputDecoration(
                              hintText: 'e.g. 90s Nostalgia, World History...',
                              hintStyle: appFont(15, color: appTextDim),
                              prefixIcon: const Icon(Icons.edit_note_rounded,
                                  color: appTextDim, size: 20),
                              border: InputBorder.none,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 13),
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

                        // Cards List Section Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'CARDS',
                                  style: appFont(11,
                                      weight: FontWeight.w600,
                                      spacing: 1.2,
                                      color: appTextDim),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: appField,
                                    borderRadius:
                                        BorderRadius.circular(appRadius),
                                    border: Border.all(
                                      color: _words.length >= 5
                                          ? appCorrect.withValues(alpha: 0.5)
                                          : appPass.withValues(alpha: 0.5),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Text(
                                    _words.length >= 5
                                        ? '${_words.length} cards'
                                        : '${_words.length}/5 minimum',
                                    style: appFont(
                                      11,
                                      weight: FontWeight.w600,
                                      color: _words.length >= 5
                                          ? appCorrect
                                          : appPass,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (_words.isNotEmpty)
                              GestureDetector(
                                onTap: () => setState(() => _words.clear()),
                                child: Text(
                                  'Clear all',
                                  style: appFont(12,
                                      weight: FontWeight.w600,
                                      color: appTextDim),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Container(height: 0.8, color: appLine),
                        const SizedBox(height: 12),

                        if (_words.isEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 36),
                            decoration: BoxDecoration(
                              color: appTile,
                              borderRadius: BorderRadius.circular(appRadius),
                              border: Border.all(color: appLine, width: 0.8),
                            ),
                            child: Center(
                              child: Column(
                                children: [
                                  const Icon(Icons.add_circle_outline_rounded,
                                      color: appTextDim, size: 32),
                                  const SizedBox(height: 10),
                                  Text(
                                    'No cards yet.\nType or paste words below to begin.',
                                    textAlign: TextAlign.center,
                                    style: appFont(13,
                                        color: appTextDim, height: 1.4),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          Container(
                            decoration: BoxDecoration(
                              color: appTile,
                              borderRadius: BorderRadius.circular(appRadius),
                              border: Border.all(color: appLine, width: 0.8),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(appRadius),
                              child: ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _words.length,
                                separatorBuilder: (_, _) => const Divider(
                                  height: 1,
                                  color: appLine,
                                ),
                                itemBuilder: (ctx, index) {
                                  final word = _words[index];
                                  return ListTile(
                                    dense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 2),
                                    leading: Container(
                                      width: 26,
                                      height: 26,
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(appRadius),
                                        color: appField,
                                        border: Border.all(
                                            color: appLine, width: 0.8),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        '${index + 1}',
                                        style: appFont(
                                          11,
                                          weight: FontWeight.w600,
                                          color: appTextDim,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      word,
                                      style: appFont(15,
                                          weight: FontWeight.w500,
                                          color: appText),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined,
                                              size: 18, color: appTextDim),
                                          onPressed: () => _editWord(index),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.close_rounded,
                                              size: 18, color: appTextDim),
                                          onPressed: () {
                                            setState(
                                                () => _words.removeAt(index));
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
                  decoration: const BoxDecoration(
                    color: appBgMid,
                    border: Border(
                      top: BorderSide(color: appLine, width: 0.8),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 46,
                          decoration: BoxDecoration(
                            color: appField,
                            borderRadius: BorderRadius.circular(appRadius),
                            border: Border.all(color: appLine, width: 0.8),
                          ),
                          child: TextField(
                            controller: _wordInputController,
                            enableSuggestions: false,
                            autocorrect: false,
                            style: appFont(14, color: appText),
                            cursorColor: appText,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _addWordsFromInput(),
                            decoration: InputDecoration(
                              hintText:
                                  'Add word or paste list (comma / newline)...',
                              hintStyle: appFont(13, color: appTextDim),
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
                          decoration: BoxDecoration(
                            color: appText,
                            borderRadius: BorderRadius.circular(appRadius),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Add',
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
        color: appTile,
        borderRadius: BorderRadius.circular(appRadius),
        border: Border.all(color: appLine, width: 0.8),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(appRadius),
              color: appField,
              border: Border.all(
                color: Color(_selectedColor).withValues(alpha: 0.8),
                width: 1.0,
              ),
            ),
            child: Icon(
              selectedIcon,
              size: 24,
              color: Color(_selectedColor),
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
                  style: appFont(18,
                      weight: FontWeight.w600, color: appText, spacing: -0.2),
                ),
                const SizedBox(height: 3),
                Text(
                  '$_selectedCategory • ${_words.length} cards',
                  style: appFont(12,
                      weight: FontWeight.w500, color: appTextDim),
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
        const AppSectionHeader(title: 'Category / Genre'),
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
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected ? appText : appTile,
                  borderRadius: BorderRadius.circular(appRadius),
                  border: isSelected
                      ? null
                      : Border.all(color: appLine, width: 0.8),
                ),
                child: Text(
                  cat,
                  style: appFont(
                    13,
                    weight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? appBgBottom : appTextDim,
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
        const AppSectionHeader(title: 'Deck Icon Badge'),
        const SizedBox(height: 10),
        SizedBox(
          height: 42,
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
                  width: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected ? appText : appTile,
                    borderRadius: BorderRadius.circular(appRadius),
                    border: isSelected
                        ? null
                        : Border.all(color: appLine, width: 0.8),
                  ),
                  child: Icon(
                    opt.icon,
                    size: 19,
                    color: isSelected ? appBgBottom : appTextDim,
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
        const AppSectionHeader(title: 'Color Accent'),
        const SizedBox(height: 10),
        SizedBox(
          height: 38,
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
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Color(colorVal),
                    borderRadius: BorderRadius.circular(appRadius),
                    border: Border.all(
                      color: isSelected ? appText : Colors.white24,
                      width: isSelected ? 2.0 : 0.8,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check_rounded,
                          size: 18, color: Colors.black)
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
