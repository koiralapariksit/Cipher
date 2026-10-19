import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/deck.dart';
import '../services/storage_service.dart';
import '../theme/deck_colors.dart';
import 'ai_deck_generator_screen.dart';
import 'deck_editor_screen.dart';
import 'gameplay_screen.dart';
import 'settings_screen.dart';


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

  void _onSurpriseMe() {
    final all = _storage.allDecks;
    if (all.isEmpty) return;
    HapticFeedback.mediumImpact();
    final randomDeck = all[math.Random().nextInt(all.length)];
    _onDeckTap(randomDeck);
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

  void _onToggleFavorite(String deckId) async {
    HapticFeedback.selectionClick();
    await _storage.toggleFavorite(deckId);
  }

  void _onTogglePin(String deckId) async {
    final success = await _storage.togglePin(deckId);
    if (!success && mounted) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Max 2 decks can be pinned! Unpin one first.',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: kCream,
            ),
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(99),
            side: const BorderSide(color: kYellow, width: 2.0),
          ),
          backgroundColor: kInk,
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      HapticFeedback.mediumImpact();
    }
  }

  void _showDeckContextMenu(Deck deck) {
    HapticFeedback.heavyImpact();
    final isPinned = _storage.isPinned(deck.id);
    final isFavorite = _storage.isFavorite(deck.id);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        decoration: BoxDecoration(
          color: kInk,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          border: const Border(
            top: BorderSide(color: kYellow, width: 2.5),
            left: BorderSide(color: kYellow, width: 2.5),
            right: BorderSide(color: kYellow, width: 2.5),
          ),
          boxShadow: kCardShadow,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          deck.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.bowlbyOne(
                            fontSize: 22,
                            color: kCream,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${deck.category} • ${deck.items.length} cards',
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: kInkDim,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: kCream,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: kInk, width: 2),
                      ),
                      child: const Icon(Icons.close_rounded,
                          size: 18, color: kInk),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Divider(color: Color(0x33FFFFFF), height: 1),
              const SizedBox(height: 12),

              // 1. PIN (Pins to top, max 2)
              _buildContextMenuItem(
                icon: isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                iconColor: kYellow,
                title: isPinned ? 'Unpin from Top' : 'Pin to Top (Max 2)',
                subtitle: isPinned
                    ? 'Remove from top priority'
                    : 'Priority #1: Top of library',
                onTap: () {
                  Navigator.pop(ctx);
                  _onTogglePin(deck.id);
                },
              ),

              // 2. FAVORITE (Marks as favorite)
              _buildContextMenuItem(
                icon: isFavorite
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
                iconColor: isFavorite ? kYellow : kCream,
                title: isFavorite ? 'Remove from Favorites' : 'Add to Favorites',
                subtitle: isFavorite
                    ? 'Remove star'
                    : 'Priority #2: Favorites list',
                onTap: () {
                  Navigator.pop(ctx);
                  _storage.toggleFavorite(deck.id);
                },
              ),

              // 3. EDIT (Opens DeckEditorScreen if custom deck)
              _buildContextMenuItem(
                icon: Icons.edit_rounded,
                iconColor: deck.isCustom ? kLime : kInkDim,
                title: 'Edit Deck',
                subtitle: deck.isCustom
                    ? 'Customize title, cards & colors'
                    : 'Built-in starter decks cannot be modified',
                enabled: deck.isCustom,
                onTap: () {
                  Navigator.pop(ctx);
                  _openDeckEditor(deck);
                },
              ),

              // 4. REMOVE (Deletes or archives with confirmation)
              _buildContextMenuItem(
                icon: Icons.delete_outline_rounded,
                iconColor: deck.isCustom ? kPink : kInkDim,
                title: 'Remove Deck',
                subtitle: deck.isCustom
                    ? 'Delete this deck permanently'
                    : 'Built-in starter decks cannot be removed',
                enabled: deck.isCustom,
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDeleteDeck(deck);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteDeck(Deck deck) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kInk,
        shape: RoundedRectangleBorder(
          borderRadius: kAsymmetricRadius,
          side: const BorderSide(color: kPink, width: 3.0),
        ),
        title: Text(
          'Delete Deck?',
          style: GoogleFonts.bowlbyOne(fontSize: 22, color: kPink),
        ),
        content: Text(
          'Are you sure you want to permanently delete "${deck.name}"? This cannot be undone.',
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
              await _storage.deleteDeck(deck.id);
              if (mounted) {
                HapticFeedback.heavyImpact();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Deleted "${deck.name}".',
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
                    backgroundColor: kPink,
                  ),
                );
              }
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

  Widget _buildContextMenuItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: enabled
              ? iconColor.withValues(alpha: 0.15)
              : const Color(0x14FFFFFF),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: enabled ? iconColor : kInkDim,
            width: 1.8,
          ),
        ),
        child: Icon(icon, color: enabled ? iconColor : kInkDim, size: 20),
      ),
      title: Text(
        title,
        style: GoogleFonts.bowlbyOne(
          fontSize: 15,
          color: enabled ? kCream : kInkDim,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.dmSans(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: enabled ? const Color(0xFFC0BACF) : kInkDim,
        ),
      ),
      onTap: enabled ? onTap : null,
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
    final matchingDecks = allDecks.where((deck) {
      final matchesSearch = query.isEmpty ||
          deck.name.toLowerCase().contains(query) ||
          deck.items.any((i) => i.toLowerCase().contains(query));
      if (!matchesSearch) return false;

      if (_selectedCategory == 'All') return true;
      if (_selectedCategory == 'Favorites') {
        return _storage.isFavorite(deck.id) || _storage.isPinned(deck.id);
      }
      if (_selectedCategory == 'Custom') return deck.isCustom;
      return deck.category.toLowerCase() == _selectedCategory.toLowerCase();
    }).toList();

    // Priority 1: Pinned (up to 2) -> Priority 2: Favorites -> Priority 3: Standard
    final filteredDecks = _storage.sortDecks(matchingDecks);

    final showCreateRows = _searchQuery.isEmpty;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: kBlue,
        body: Stack(
          children: [
            // Decorative soft circle at top-right
            Positioned(
              right: -70,
              top: -80,
              child: Container(
                width: 230,
                height: 230,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: kYellow.withValues(alpha: 0.3),
                ),
              ),
            ),

            SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),

                    // Top Header Row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Tilted "Cipher!" title
                          Transform.rotate(
                            angle: -2 * math.pi / 180,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  'Cipher',
                                  style: GoogleFonts.bowlbyOne(
                                    fontSize: 52,
                                    height: 0.95,
                                    color: kCream,
                                  ),
                                ),
                                Text(
                                  '!',
                                  style: GoogleFonts.bowlbyOne(
                                    fontSize: 52,
                                    height: 0.95,
                                    color: kYellow,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          // Circular Settings button (44x44, kYellow, 2px kInk border, hard shadow)
                          _BouncyTap(
                            onTap: _openSettings,
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: kYellow,
                                border: Border.all(color: kInk, width: 2),
                                boxShadow: kSmallShadow,
                              ),
                              child: const Icon(
                                Icons.tune_rounded,
                                color: kInk,
                                size: 22,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // "Surprise Me" Card
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Transform.rotate(
                        angle: 0.8 * math.pi / 180,
                        child: _BouncyTap(
                          onTap: _onSurpriseMe,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
                            decoration: BoxDecoration(
                              color: kLime,
                              borderRadius: kAsymmetricRadius,
                              border: Border.all(color: kInk, width: 2),
                              boxShadow: kHardShadow,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Surprise me',
                                        style: GoogleFonts.bowlbyOne(
                                          fontSize: 26,
                                          color: kInk,
                                          height: 1.1,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Random deck, straight into a round',
                                        style: GoogleFonts.dmSans(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: kInk,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: kInk,
                                  ),
                                  child: const Icon(
                                    Icons.arrow_forward_rounded,
                                    color: kLime,
                                    size: 22,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 22),

                    // Continuous Ticker Band
                    const _TickerBand(),

                    const SizedBox(height: 22),

                    // Round Length Selector
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Text(
                            'Round length',
                            style: GoogleFonts.dmSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: kCream,
                            ),
                          ),
                          const Spacer(),
                          ..._timerOptions.map((t) {
                            final isSelected = t == _selectedTimer;
                            return Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: _BouncyTap(
                                onTap: () => setState(() => _selectedTimer = t),
                                child: Transform.rotate(
                                  angle: isSelected
                                      ? -3 * math.pi / 180
                                      : 0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 7,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? kYellow
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(99),
                                      border: Border.all(
                                        color: isSelected ? kInk : kCream,
                                        width: 2,
                                      ),
                                      boxShadow:
                                          isSelected ? kSmallShadow : null,
                                    ),
                                    child: Text(
                                      '${t}s',
                                      style: GoogleFonts.dmSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: isSelected ? kInk : kCream,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Search Input Bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        height: 50,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: kCream,
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(color: kInk, width: 2),
                          boxShadow: kHardShadow,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.search_rounded,
                              color: kInk,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                enableSuggestions: false,
                                autocorrect: false,
                                style: GoogleFonts.dmSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: kInk,
                                ),
                                cursorColor: kInk,
                                onChanged: (val) =>
                                    setState(() => _searchQuery = val),
                                decoration: InputDecoration(
                                  hintText: 'Search decks or words',
                                  hintStyle: GoogleFonts.dmSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: kInk.withValues(alpha: 0.55),
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                              ),
                            ),
                            if (_searchQuery.isNotEmpty)
                              GestureDetector(
                                onTap: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                                child: const Icon(
                                  Icons.close_rounded,
                                  color: kInk,
                                  size: 20,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Category Filter Chips (Horizontal Scroll)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: categories.map((cat) {
                          final isSelected = cat == _selectedCategory;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _BouncyTap(
                              onTap: () =>
                                  setState(() => _selectedCategory = cat),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? kOrange
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(99),
                                  border: Border.all(
                                    color: isSelected ? kInk : kCream,
                                    width: 2,
                                  ),
                                  boxShadow:
                                      isSelected ? kSmallShadow : null,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (cat == 'Favorites') ...[
                                      Icon(
                                        Icons.star_rounded,
                                        size: 16,
                                        color: isSelected ? kInk : kCream,
                                      ),
                                      const SizedBox(width: 4),
                                    ],
                                    Text(
                                      cat,
                                      style: GoogleFonts.dmSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: isSelected ? kInk : kCream,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 22),

                    // Staggered Two-Column Deck Grid
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: filteredDecks.isEmpty
                          ? Center(
                              child: Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(top: 24),
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: kCream,
                                  borderRadius: kAsymmetricRadius,
                                  border: Border.all(color: kInk, width: 2),
                                  boxShadow: kHardShadow,
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      _selectedCategory == 'Favorites'
                                          ? 'No favorites yet!'
                                          : 'No decks found!',
                                      style: GoogleFonts.bowlbyOne(
                                        fontSize: 20,
                                        color: kInk,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _selectedCategory == 'Favorites'
                                          ? 'Tap the star icon on any deck to pin it to your favorites.'
                                          : 'Try a different search term or category.',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.dmSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: kInkDim,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : _buildStaggeredGrid(
                              filteredDecks: filteredDecks,
                              showCreateTiles: showCreateRows,
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaggeredGrid({
    required List<Deck> filteredDecks,
    required bool showCreateTiles,
  }) {
    final List<Widget> leftColumn = [];
    final List<Widget> rightColumn = [];

    // Distribute deck tiles
    for (int i = 0; i < filteredDecks.length; i++) {
      final deck = filteredDecks[i];
      final isEven = (i % 2 == 0);
      final tile = _DeckStickerCard(
        deck: deck,
        index: i,
        isPinned: _storage.isPinned(deck.id),
        isFavorite: _storage.isFavorite(deck.id),
        highScore: _storage.getHighScoreForDeck(deck.id, deck.name),
        onTap: () => _onDeckTap(deck),
        onFavoriteToggle: () => _onToggleFavorite(deck.id),
        onEdit: deck.isCustom ? () => _openDeckEditor(deck) : null,
        onLongPress: () => _showDeckContextMenu(deck),
      );

      if (isEven) {
        leftColumn.add(tile);
      } else {
        rightColumn.add(tile);
      }
    }

    // Append creation tiles at the end if searching is not active
    if (showCreateTiles) {
      final newDeckTile = _CreateStickerCard(
        label: 'New deck',
        icon: Icons.add_rounded,
        tiltAngle: -1.5,
        onTap: _openDeckEditor,
      );
      final aiDeckTile = _CreateStickerCard(
        label: 'Make with AI',
        icon: Icons.auto_awesome_rounded,
        tiltAngle: 1.5,
        onTap: _openAiGenerator,
      );

      if (leftColumn.length <= rightColumn.length) {
        leftColumn.add(newDeckTile);
        rightColumn.add(aiDeckTile);
      } else {
        rightColumn.add(newDeckTile);
        leftColumn.add(aiDeckTile);
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column (starts at top)
        Expanded(
          child: Column(
            children: leftColumn
                .map((widget) => Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: widget,
                    ))
                .toList(),
          ),
        ),
        const SizedBox(width: 14),
        // Right Column (staggered offset: 26px top padding)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 26),
            child: Column(
              children: rightColumn
                  .map((widget) => Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: widget,
                      ))
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Continuous Ticker Band ───────────────────────────────────────────────────

class _TickerBand extends StatefulWidget {
  const _TickerBand();

  @override
  State<_TickerBand> createState() => _TickerBandState();
}

class _TickerBandState extends State<_TickerBand>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const String _tickerText =
      'ACT IT OUT ★ GUESS IT FAST ★ NO TALKING ★ LAUGH A LOT ★ ';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Transform.rotate(
        angle: -2 * math.pi / 180,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: kInk,
            border: Border.symmetric(
              horizontal: BorderSide(color: kInk, width: 2),
            ),
            boxShadow: const [
              BoxShadow(color: Color(0x33000000), offset: Offset(0, 3)),
            ],
          ),
          child: ClipRect(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  child: FractionalTranslation(
                    translation: Offset(-_controller.value * 0.25, 0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(
                        4,
                        (_) => Text(
                          _tickerText,
                          style: GoogleFonts.bowlbyOne(
                            fontSize: 13,
                            color: kYellow,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ── Deck Sticker Card ────────────────────────────────────────────────────────

class _DeckStickerCard extends StatelessWidget {
  final Deck deck;
  final int index;
  final bool isPinned;
  final bool isFavorite;
  final int highScore;
  final VoidCallback onTap;
  final VoidCallback onFavoriteToggle;
  final VoidCallback? onEdit;
  final VoidCallback? onLongPress;

  const _DeckStickerCard({
    required this.deck,
    required this.index,
    required this.isPinned,
    required this.isFavorite,
    required this.highScore,
    required this.onTap,
    required this.onFavoriteToggle,
    this.onEdit,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final color = deckColorFor(deck);
    // Alternate tilts: -1.5 degrees and +1.5 degrees
    final tiltAngle = (index % 2 == 0 ? -1.5 : 1.5) * math.pi / 180;
    // Dynamic height between 165px and 190px
    final cardHeight = (index % 3 == 0) ? 190.0 : 168.0;

    return Transform.rotate(
      angle: tiltAngle,
      child: _BouncyTap(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          height: cardHeight,
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 14),
          decoration: BoxDecoration(
            color: color,
            borderRadius: kAsymmetricRadius,
            border: Border.all(color: kInk, width: 2),
            boxShadow: kHardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: pill count + pin badge + edit + favorite star
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: kInk,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '${deck.items.length} cards',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: kCream,
                      ),
                    ),
                  ),
                  if (isPinned) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: kYellow,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: kInk, width: 1.5),
                        boxShadow: kSmallShadow,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.push_pin_rounded,
                              size: 11, color: kInk),
                          const SizedBox(width: 2),
                          Text(
                            'PIN',
                            style: GoogleFonts.bowlbyOne(
                              fontSize: 9,
                              color: kInk,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (onEdit != null)
                    GestureDetector(
                      onTap: onEdit,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        margin: const EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(
                          color: kInk.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Edit',
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: kInk,
                          ),
                        ),
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
                        size: 22,
                        color: kInk,
                      ),
                    ),
                  ),
                ],
              ),

              const Spacer(),

              // Best score if recorded
              if (highScore > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    'BEST $highScore',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: kInk.withValues(alpha: 0.7),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),

              // Deck Title in Bowlby One (strict kInk contrast)
              Text(
                deck.name,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.bowlbyOne(
                  fontSize: deck.name.length > 20 ? 19 : 22,
                  color: kInk,
                  height: 1.05,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Create Tile Sticker Card ─────────────────────────────────────────────────

class _CreateStickerCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final double tiltAngle;
  final VoidCallback onTap;

  const _CreateStickerCard({
    required this.label,
    required this.icon,
    required this.tiltAngle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: tiltAngle * math.pi / 180,
      child: _BouncyTap(
        onTap: onTap,
        child: Container(
          height: 168,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kCream,
            borderRadius: kAsymmetricRadius,
            border: Border.all(color: kInk, width: 2),
            boxShadow: kHardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: kYellow,
                  border: Border.all(color: kInk, width: 1.8),
                ),
                child: Icon(icon, color: kInk, size: 20),
              ),
              const Spacer(),
              Text(
                label,
                style: GoogleFonts.bowlbyOne(
                  fontSize: 18,
                  color: kInk,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Bouncy Tap Animation Wrapper (0.96 scale + haptics) ─────────────────────

class _BouncyTap extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _BouncyTap({
    required this.child,
    required this.onTap,
    this.onLongPress,
  });

  @override
  State<_BouncyTap> createState() => _BouncyTapState();
}

class _BouncyTapState extends State<_BouncyTap> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        HapticFeedback.lightImpact();
        setState(() => _pressed = true);
      },
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress != null
          ? () {
              setState(() => _pressed = false);
              widget.onLongPress!();
            }
          : null,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}