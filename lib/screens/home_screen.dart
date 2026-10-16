import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/deck.dart';
import '../services/storage_service.dart';
import 'ai_deck_generator_screen.dart';
import 'deck_editor_screen.dart';
import 'gameplay_screen.dart';
import 'settings_screen.dart';

// Background sampled from the reference wallpaper: one vertical fall from
// soft charcoal at the top to near black at the bottom.
const Color _bgTop = Color(0xFF343434);
const Color _bgMid = Color(0xFF222222);
const Color _bgBottom = Color(0xFF0A0A0A);
const Color _field = Color(0x40000000);
const Color _tile = Color(0x14FFFFFF);
const Color _text = Color(0xFFF2F2F2);
const Color _textDim = Color(0xFF8E8E8E);
const Color _line = Color(0x24FFFFFF);

// One typeface. Swap the family here if you want a different voice.
TextStyle _font(double size,
    {FontWeight weight = FontWeight.w400,
    Color color = _text,
    double spacing = 0,
    double? height}) {
  return GoogleFonts.bricolageGrotesque(
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: spacing,
    height: height,
  );
}

// Tight corners everywhere.
const double _radius = 3;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final StorageService _storage = StorageService();
  final TextEditingController _searchController = TextEditingController();

  late int _selectedTimer;
  String _selectedCategory = 'All';
  String _searchQuery = '';

  static const List<int> _timerOptions = [30, 60, 90];

  @override
  void initState() {
    super.initState();
    _selectedTimer = _storage.settings.defaultTimerDuration;
    _storage.addListener(_onStorageUpdate);
  }

  @override
  void dispose() {
    _storage.removeListener(_onStorageUpdate);
    _searchController.dispose();
    super.dispose();
  }

  void _onStorageUpdate() {
    if (mounted) setState(() {});
  }

  void _onDeckTap(Deck deck) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            GameplayScreen(deck: deck, timerSeconds: _selectedTimer),
      ),
    );
  }

  void _openDeckEditor([Deck? deck]) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => DeckEditorScreen(deck: deck)),
    );
    if (result == true) {
      setState(() {});
    }
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  void _openAiGenerator() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AiDeckGeneratorScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allDecks = _storage.allDecks;

    final categories = [
      'All',
      'Favorites',
      'Custom',
      ...{
        for (var d in allDecks)
          if (d.category.isNotEmpty &&
              d.category != 'General' &&
              d.category != 'Custom')
            d.category
      }
    ];

    final query = _searchQuery.toLowerCase();
    final filteredDecks = allDecks.where((deck) {
      final matchesSearch = query.isEmpty ||
          deck.name.toLowerCase().contains(query) ||
          deck.items.any((i) => i.toLowerCase().contains(query));
      if (!matchesSearch) return false;

      if (_selectedCategory == 'All') return true;
      if (_selectedCategory == 'Favorites') return _storage.isFavorite(deck.id);
      if (_selectedCategory == 'Custom') return deck.isCustom;
      return deck.category.toLowerCase() == _selectedCategory.toLowerCase();
    }).toList();

    // Favorites first, then A to Z.
    filteredDecks.sort((a, b) {
      final aFav = _storage.isFavorite(a.id);
      final bFav = _storage.isFavorite(b.id);
      if (aFav && !bFav) return -1;
      if (!aFav && bFav) return 1;
      return a.name.compareTo(b.name);
    });

    final showCreateRows = _searchQuery.isEmpty;
    final tileCount = filteredDecks.length + (showCreateRows ? 2 : 0);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _bgBottom,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_bgTop, _bgMid, _bgBottom],
              stops: [0.0, 0.47, 1.0],
            ),
          ),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title + settings
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('Heads Guess',
                          style: _font(32,
                              weight: FontWeight.w700, spacing: -0.8)),
                      const Spacer(),
                      GestureDetector(
                        onTap: _openSettings,
                        behavior: HitTestBehavior.opaque,
                        child: Text('Settings',
                            style: _font(15, color: _textDim)),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                // Search
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: _field,
                      borderRadius: BorderRadius.circular(_radius),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: _font(15),
                      cursorColor: _text,
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: InputDecoration(
                        hintText: 'Search decks or words',
                        hintStyle: _font(15, color: _textDim),
                        prefixIcon: const Icon(Icons.search_rounded,
                            color: _textDim, size: 19),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded,
                                    color: _textDim, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 22),

                // Round length
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Text('Round length', style: _font(14, color: _textDim)),
                      const Spacer(),
                      ..._timerOptions.map((t) {
                        final selected = t == _selectedTimer;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedTimer = t),
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 13, vertical: 7),
                            decoration: BoxDecoration(
                              color: selected ? _text : Colors.transparent,
                              borderRadius: BorderRadius.circular(_radius),
                            ),
                            child: Text(
                              '${t}s',
                              style: _font(14,
                                  weight: FontWeight.w600,
                                  color: selected ? _bgBottom : _textDim),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Decks as a plain list
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: filteredDecks.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 48),
                                  child: Text(
                                    _selectedCategory == 'Favorites'
                                        ? 'No favorites yet. Tap the star on a deck to keep it here.'
                                        : 'No decks match that. Try a different word or category.',
                                    textAlign: TextAlign.center,
                                    style: _font(15, color: _textDim, height: 1.4),
                                  ),
                                ),
                              )
                            : GridView.builder(
                                padding: const EdgeInsets.fromLTRB(24, 4, 6, 32),
                                itemCount: tileCount,
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 12,
                                  childAspectRatio: 1.12,
                                ),
                                itemBuilder: (context, index) {
                                  if (index >= filteredDecks.length) {
                                    final isAi = index == filteredDecks.length + 1;
                                    return _CreateTile(
                                      label: isAi ? 'Make one with AI' : 'New deck',
                                      showPlus: !isAi,
                                      onTap: isAi ? _openAiGenerator : _openDeckEditor,
                                    );
                                  }

                                  final deck = filteredDecks[index];
                                  return _DeckTile(
                                    deck: deck,
                                    isFavorite: _storage.isFavorite(deck.id),
                                    highScore: _storage.getHighScoreForDeck(
                                        deck.id, deck.name),
                                    onTap: () => _onDeckTap(deck),
                                    onFavoriteToggle: () =>
                                        _storage.toggleFavorite(deck.id),
                                    onEdit: deck.isCustom
                                        ? () => _openDeckEditor(deck)
                                        : null,
                                  );
                                },
                              ),
                      ),
                      _CategoryRail(
                        categories: categories,
                        selected: _selectedCategory,
                        onSelect: (c) => setState(() => _selectedCategory = c),
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

class _DeckTile extends StatelessWidget {
  final Deck deck;
  final bool isFavorite;
  final int highScore;
  final VoidCallback onTap;
  final VoidCallback onFavoriteToggle;
  final VoidCallback? onEdit;

  const _DeckTile({
    required this.deck,
    required this.isFavorite,
    required this.highScore,
    required this.onTap,
    required this.onFavoriteToggle,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 10, 12),
        decoration: BoxDecoration(
          color: _tile,
          borderRadius: BorderRadius.circular(_radius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    deck.name,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: _font(17,
                        weight: FontWeight.w600, spacing: -0.2, height: 1.15),
                  ),
                ),
                if (onEdit != null)
                  GestureDetector(
                    onTap: onEdit,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(6, 2, 4, 2),
                      child: Text('Edit', style: _font(12, color: _textDim)),
                    ),
                  ),
                GestureDetector(
                  onTap: onFavoriteToggle,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 2),
                    child: Icon(
                      isFavorite
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 20,
                      color: isFavorite ? _text : _textDim,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Row(
                children: [
                  Text('${deck.items.length} cards',
                      style: _font(12, color: _textDim)),
                  const Spacer(),
                  if (highScore > 0)
                    Text('Best $highScore',
                        style: _font(12, weight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateTile extends StatelessWidget {
  final String label;
  final bool showPlus;
  final VoidCallback onTap;

  const _CreateTile({
    required this.label,
    required this.showPlus,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_radius),
          border: Border.all(color: _line, width: 0.8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showPlus)
              const Icon(Icons.add_rounded, size: 22, color: _textDim),
            const Spacer(),
            Text(label,
                style: _font(15, weight: FontWeight.w500, color: _textDim)),
          ],
        ),
      ),
    );
  }
}

class _CategoryRail extends StatelessWidget {
  final List<String> categories;
  final String selected;
  final ValueChanged<String> onSelect;

  const _CategoryRail({
    required this.categories,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: categories.map((cat) {
          final isSelected = cat == selected;
          final color = isSelected ? _text : _textDim;
          final Widget label = cat == 'Favorites'
              ? Icon(
                  isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 22,
                  color: color,
                )
              : RotatedBox(
                  quarterTurns: 3,
                  child: Text(
                    cat,
                    maxLines: 1,
                    style: _font(15,
                        weight: isSelected ? FontWeight.w700 : FontWeight.w400,
                        color: color),
                  ),
                );
          return GestureDetector(
            onTap: () => onSelect(cat),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(child: label),
            ),
          );
        }).toList(),
      ),
    );
  }
}