import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/deck.dart';
import '../services/storage_service.dart';
import 'ai_deck_generator_screen.dart';
import 'deck_editor_screen.dart';
import 'gameplay_screen.dart';
import 'settings_screen.dart';

// Palette taken from the reference: pure black, charcoal panels, thin gold lines.
// Change _gold to restyle every accent in one place.
const Color _black = Colors.black;
const Color _gold = Color(0xFFC8A45C);
const Color _text = Color(0xFFEDEDED);
const Color _textDim = Color(0xFF8C8C8C);
const Color _panelTop = Color(0xFF1B1B1B);
const Color _panelBottom = Color(0xFF0C0C0C);
const Color _selectedFill = Color(0xFF17140C);

TextStyle _font(double size,
    {FontWeight weight = FontWeight.w400,
    Color color = _text,
    double spacing = 0,
    double? height}) {
  return GoogleFonts.jost(
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: spacing,
    height: height,
  );
}

/// Minimalist luxury panel: charcoal surface, subtle border, sharp 8px radius
BoxDecoration _panel({
  double radius = 8,
  bool highlight = false,
  Color? borderColor,
}) {
  return BoxDecoration(
    gradient: const LinearGradient(
      colors: [_panelTop, _panelBottom],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: borderColor ??
          (highlight
              ? _gold.withValues(alpha: 0.85)
              : _gold.withValues(alpha: 0.22)),
      width: highlight ? 1.2 : 0.8,
    ),
  );
}

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

    final showCreateTiles = _searchQuery.isEmpty;
    final tileCount = filteredDecks.length + (showCreateTiles ? 2 : 0);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _black,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title + settings
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Row(
                  children: [
                    Text('Heads Guess',
                        style: _font(30, weight: FontWeight.w300, spacing: 0.5)),
                    const Spacer(),
                    _RoundIconButton(
                      icon: Icons.settings_outlined,
                      tooltip: 'Settings',
                      onTap: _openSettings,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Search
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  height: 46,
                  decoration: _panel(radius: 8),
                  child: TextField(
                    controller: _searchController,
                    style: _font(15),
                    cursorColor: _gold,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Search decks or words',
                      hintStyle: _font(15, color: _textDim),
                      prefixIcon: const Icon(Icons.search_rounded,
                          color: _textDim, size: 20),
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

              const SizedBox(height: 14),

              // Round length
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text('Round length', style: _font(14, color: _textDim)),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: _panel(radius: 8),
                      child: Row(
                        children: _timerOptions.map((t) {
                          final selected = t == _selectedTimer;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedTimer = t),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: selected
                                    ? _selectedFill
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: selected
                                      ? _gold.withValues(alpha: 0.8)
                                      : Colors.transparent,
                                  width: 0.9,
                                ),
                              ),
                              child: Text(
                                '${t}s',
                                style: _font(14,
                                    weight: FontWeight.w500,
                                    color: selected ? _gold : _textDim),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Categories
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: categories.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (ctx, idx) {
                    final cat = categories[idx];
                    final selected = cat == _selectedCategory;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedCategory = cat),
                      child: Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: selected
                              ? _selectedFill
                              : const Color(0xFF101010),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: selected
                                ? _gold.withValues(alpha: 0.85)
                                : Colors.white.withValues(alpha: 0.08),
                            width: selected ? 1.0 : 0.8,
                          ),
                        ),
                        child: Text(
                          cat,
                          style: _font(14,
                              weight: FontWeight.w500,
                              color: selected ? _gold : _textDim),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 18),

              // Section header with gold hairline, like the reference widgets
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('DECKS',
                            style: _font(11,
                                weight: FontWeight.w500, spacing: 1.6)),
                        const Spacer(),
                        Text('${filteredDecks.length} shown',
                            style: _font(11, color: _textDim)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 0.8,
                      color: _gold.withValues(alpha: 0.45),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Decks
              Expanded(
                child: filteredDecks.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.search_off_rounded,
                                  size: 40,
                                  color: _gold.withValues(alpha: 0.6)),
                              const SizedBox(height: 12),
                              Text(
                                _selectedCategory == 'Favorites'
                                    ? 'No favorites yet. Tap the star on a deck to keep it here.'
                                    : 'No decks match that. Try a different word or category.',
                                textAlign: TextAlign.center,
                                style: _font(15, color: _textDim),
                              ),
                            ],
                          ),
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                        itemCount: tileCount,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 1.1,
                        ),
                        itemBuilder: (context, index) {
                          if (index >= filteredDecks.length) {
                            final isAi = index == filteredDecks.length + 1;
                            return _CreateTile(
                              label:
                                  isAi ? 'Ask AI to make one' : 'Write your own',
                              icon: isAi
                                  ? Icons.psychology_outlined
                                  : Icons.add_rounded,
                              onTap: isAi ? _openAiGenerator : _openDeckEditor,
                            );
                          }

                          final deck = filteredDecks[index];
                          return _DeckCard(
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
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: _panel(radius: 8),
          child: Icon(icon, color: _gold, size: 21),
        ),
      ),
    );
  }
}

class _DeckCard extends StatelessWidget {
  final Deck deck;
  final bool isFavorite;
  final int highScore;
  final VoidCallback onTap;
  final VoidCallback onFavoriteToggle;
  final VoidCallback? onEdit;

  const _DeckCard({
    required this.deck,
    required this.isFavorite,
    required this.highScore,
    required this.onTap,
    required this.onFavoriteToggle,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(deck.colorValue);
    final categoryLabel = deck.isCustom
        ? 'CUSTOM'
        : (deck.category.isNotEmpty ? deck.category.toUpperCase() : 'GENERAL');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: _panel(radius: 8, highlight: isFavorite),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: category/custom badge, high score, and action icons
            Row(
              children: [
                // Category Tag
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: _gold.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: _gold.withValues(alpha: 0.35),
                      width: 0.7,
                    ),
                  ),
                  child: Text(
                    categoryLabel,
                    style: _font(9,
                        weight: FontWeight.w600, spacing: 1.1, color: _gold),
                  ),
                ),
                if (highScore > 0) ...[
                  const SizedBox(width: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 2.5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: _gold.withValues(alpha: 0.35),
                        width: 0.7,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.emoji_events_outlined,
                            size: 10, color: _gold),
                        const SizedBox(width: 3),
                        Text('$highScore',
                            style: _font(9,
                                weight: FontWeight.w600, color: _gold)),
                      ],
                    ),
                  ),
                ],
                const Spacer(),
                if (onEdit != null)
                  GestureDetector(
                    onTap: onEdit,
                    behavior: HitTestBehavior.opaque,
                    child: const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      child:
                          Icon(Icons.edit_outlined, size: 15, color: _textDim),
                    ),
                  ),
                GestureDetector(
                  onTap: onFavoriteToggle,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 3, top: 2, bottom: 2),
                    child: Icon(
                      isFavorite
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 20,
                      color:
                          isFavorite ? _gold : _textDim.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ),

            const Spacer(),

            // Deck Name with minimalist accent bar
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 2.5,
                  height: 20,
                  margin: const EdgeInsets.only(top: 2, right: 8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
                Expanded(
                  child: Text(
                    deck.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _font(
                      16,
                      weight: FontWeight.w500,
                      color: _text,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Bottom info row: clean card count + subtle direction arrow
            Row(
              children: [
                Text(
                  '${deck.items.length} CARDS',
                  style: _font(10,
                      weight: FontWeight.w500, spacing: 1.2, color: _textDim),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 13,
                  color: _gold.withValues(alpha: 0.55),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _CreateTile({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: _DashedBorderPainter(),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 28, color: _gold),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: _font(14, weight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _gold.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Offset.zero & size,
        const Radius.circular(8),
      ));

    const dash = 7.0;
    const gap = 6.0;
    for (final metric in path.computeMetrics()) {
      double d = 0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + dash), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}