import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/deck.dart';
import '../models/game_round.dart';

/// App settings model for user preferences.
class AppSettings {
  final bool soundEnabled;
  final bool vibrationEnabled;
  final int defaultTimerDuration; // 30, 60, 90
  final double tiltSensitivity; // 1.0 (normal)
  final bool showManualButtons; // Always show on-screen buttons
  final bool invertTilt; // Default false: Down = Correct, Up = Pass

  const AppSettings({
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.defaultTimerDuration = 60,
    this.tiltSensitivity = 1.0,
    this.showManualButtons = true,
    this.invertTilt = false,
  });

  AppSettings copyWith({
    bool? soundEnabled,
    bool? vibrationEnabled,
    int? defaultTimerDuration,
    double? tiltSensitivity,
    bool? showManualButtons,
    bool? invertTilt,
  }) {
    return AppSettings(
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      defaultTimerDuration: defaultTimerDuration ?? this.defaultTimerDuration,
      tiltSensitivity: tiltSensitivity ?? this.tiltSensitivity,
      showManualButtons: showManualButtons ?? this.showManualButtons,
      invertTilt: invertTilt ?? this.invertTilt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'soundEnabled': soundEnabled,
      'vibrationEnabled': vibrationEnabled,
      'defaultTimerDuration': defaultTimerDuration,
      'tiltSensitivity': tiltSensitivity,
      'showManualButtons': showManualButtons,
      'invertTilt': invertTilt,
    };
  }

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    return AppSettings(
      soundEnabled: map['soundEnabled'] as bool? ?? true,
      vibrationEnabled: map['vibrationEnabled'] as bool? ?? true,
      defaultTimerDuration:
          (map['defaultTimerDuration'] as num?)?.toInt() ?? 60,
      tiltSensitivity:
          (map['tiltSensitivity'] as num?)?.toDouble() ?? 1.0,
      showManualButtons:
          map['showManualButtons'] as bool? ?? map['forceManualButtons'] as bool? ?? true,
      invertTilt: map['invertTilt'] as bool? ?? false,
    );
  }

  String toJson() => json.encode(toMap());

  factory AppSettings.fromJson(String source) =>
      AppSettings.fromMap(json.decode(source) as Map<String, dynamic>);
}

/// Service managing persistent local data with SharedPreferences:
/// - Custom user-created decks
/// - App settings
/// - Favorite deck IDs
/// - Round history and per-deck high scores
class StorageService with ChangeNotifier {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  static const String _keyCustomDecks = 'custom_decks_v2';
  static const String _keySettings = 'app_settings_v2';
  static const String _keyPinned = 'pinned_deck_ids_v2';
  static const String _keyFavorites = 'favorite_deck_ids_v2';
  static const String _keyHistory = 'round_history_v2';

  SharedPreferences? _prefs;

  List<Deck> _customDecks = [];
  Set<String> _pinnedDeckIds = {};
  Set<String> _favoriteDeckIds = {};
  List<GameRound> _roundHistory = [];
  AppSettings _settings = const AppSettings();

  bool _initialized = false;
  bool get isInitialized => _initialized;

  List<Deck> get customDecks => List.unmodifiable(_customDecks);
  Set<String> get pinnedDeckIds => Set.unmodifiable(_pinnedDeckIds);
  Set<String> get favoriteDeckIds => Set.unmodifiable(_favoriteDeckIds);
  List<GameRound> get roundHistory => List.unmodifiable(_roundHistory);
  AppSettings get settings => _settings;

  /// Returns built-in starter decks + user-created custom decks.
  List<Deck> get allDecks => [...Deck.starterDecks, ..._customDecks];

  /// Initialize and load all stored data.
  Future<void> init({bool force = false}) async {
    if (_initialized && !force) return;
    _prefs = await SharedPreferences.getInstance();

    // 1. Settings
    final settingsJson = _prefs?.getString(_keySettings);
    if (settingsJson != null) {
      try {
        _settings = AppSettings.fromJson(settingsJson);
      } catch (e) {
        debugPrint('Error loading settings: $e');
      }
    }

    // 2. Custom Decks
    final customDecksJson = _prefs?.getStringList(_keyCustomDecks);
    if (customDecksJson != null) {
      _customDecks = customDecksJson.map((d) {
        try {
          return Deck.fromJson(d);
        } catch (e) {
          debugPrint('Error loading deck: $e');
          return null;
        }
      }).whereType<Deck>().toList();
    }

    // 3a. Pinned Decks (Strict Max 2)
    final pinnedList = _prefs?.getStringList(_keyPinned);
    if (pinnedList != null) {
      _pinnedDeckIds = pinnedList.take(2).toSet();
    } else {
      final legacyFavs = _prefs?.getStringList(_keyFavorites);
      if (legacyFavs != null && legacyFavs.isNotEmpty) {
        _pinnedDeckIds = legacyFavs.take(2).toSet();
      }
    }

    // 3b. Favorites (Unlimited)
    final favoritesList = _prefs?.getStringList(_keyFavorites);
    if (favoritesList != null) {
      _favoriteDeckIds = favoritesList.toSet();
    }

    // 4. History
    final historyJson = _prefs?.getStringList(_keyHistory);
    if (historyJson != null) {
      _roundHistory = historyJson.map((h) {
        try {
          return GameRound.fromJson(h);
        } catch (e) {
          debugPrint('Error loading round history: $e');
          return null;
        }
      }).whereType<GameRound>().toList();
    }

    _initialized = true;
    notifyListeners();
  }

  // ── Settings ───────────────────────────────────────────────────────────

  Future<void> updateSettings(AppSettings newSettings) async {
    _settings = newSettings;
    await _prefs?.setString(_keySettings, _settings.toJson());
    notifyListeners();
  }

  // ── Custom Decks ───────────────────────────────────────────────────────

  Future<void> saveDeck(Deck deck) async {
    final index = _customDecks.indexWhere((d) => d.id == deck.id);
    if (index >= 0) {
      _customDecks[index] = deck;
    } else {
      _customDecks.add(deck);
    }
    await _persistCustomDecks();
    notifyListeners();
  }

  /// Alias for saving user-created or imported custom decks.
  Future<void> saveCustomDeck(Deck deck) => saveDeck(deck);

  Future<void> deleteDeck(String deckId) async {
    _customDecks.removeWhere((d) => d.id == deckId);
    _pinnedDeckIds.remove(deckId);
    _favoriteDeckIds.remove(deckId);
    await _persistCustomDecks();
    await _persistPinned();
    await _persistFavorites();
    notifyListeners();
  }

  Future<void> _persistCustomDecks() async {
    final list = _customDecks.map((d) => json.encode(d.toJson())).toList();
    await _prefs?.setStringList(_keyCustomDecks, list);
  }

  // ── Pinned Decks (Strict Max 2 Pinned) ──────────────────────────────────

  bool isPinned(String deckId) => _pinnedDeckIds.contains(deckId);

  /// Toggles pinned status for [deckId].
  /// Returns `true` if pinned/unpinned successfully.
  /// Returns `false` if pinning is blocked because 2 decks are already pinned.
  Future<bool> togglePin(String deckId) async {
    if (_pinnedDeckIds.contains(deckId)) {
      _pinnedDeckIds.remove(deckId);
      await _persistPinned();
      notifyListeners();
      return true;
    } else {
      if (_pinnedDeckIds.length >= 2) {
        return false;
      }
      _pinnedDeckIds.add(deckId);
      await _persistPinned();
      notifyListeners();
      return true;
    }
  }

  Future<void> _persistPinned() async {
    await _prefs?.setStringList(_keyPinned, _pinnedDeckIds.toList());
  }

  // ── Favorites (Unlimited) ──────────────────────────────────────────────

  bool isFavorite(String deckId) => _favoriteDeckIds.contains(deckId);

  /// Toggles favorite status for [deckId].
  Future<bool> toggleFavorite(String deckId) async {
    if (_favoriteDeckIds.contains(deckId)) {
      _favoriteDeckIds.remove(deckId);
    } else {
      _favoriteDeckIds.add(deckId);
    }
    await _persistFavorites();
    notifyListeners();
    return true;
  }

  Future<void> _persistFavorites() async {
    await _prefs?.setStringList(_keyFavorites, _favoriteDeckIds.toList());
  }

  // ── Priority Sorting ───────────────────────────────────────────────────

  /// Sorts decks in the exact hierarchy:
  /// - Priority 1: Pinned Decks (up to 2)
  /// - Priority 2: Favorite Decks (non-pinned favorites)
  /// - Priority 3: Standard/All other decks
  /// Within each priority tier, decks are sorted alphabetically by name.
  List<Deck> sortDecks(List<Deck> decks) {
    final list = List<Deck>.from(decks);
    list.sort((a, b) {
      final aPinned = isPinned(a.id);
      final bPinned = isPinned(b.id);
      if (aPinned && !bPinned) return -1;
      if (!aPinned && bPinned) return 1;

      final aFav = isFavorite(a.id);
      final bFav = isFavorite(b.id);
      if (aFav && !bFav) return -1;
      if (!aFav && bFav) return 1;

      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return list;
  }

  // ── History & High Scores ──────────────────────────────────────────────

  /// Get highest score recorded for a deck.
  int getHighScoreForDeck(String deckId, [String? deckName]) {
    int maxScore = 0;
    for (final round in _roundHistory) {
      if (round.deckId == deckId || (deckName != null && round.deckName == deckName)) {
        if (round.correctCount > maxScore) {
          maxScore = round.correctCount;
        }
      }
    }
    return maxScore;
  }

  Future<void> addRoundHistory(GameRound round) async {
    _roundHistory.insert(0, round);
    if (_roundHistory.length > 50) {
      _roundHistory = _roundHistory.sublist(0, 50);
    }
    final list = _roundHistory.map((r) => r.toJson()).toList();
    await _prefs?.setStringList(_keyHistory, list);
    notifyListeners();
  }

  Future<void> clearHistory() async {
    _roundHistory.clear();
    await _prefs?.remove(_keyHistory);
    notifyListeners();
  }

  /// Reset all custom data: custom decks, favorites, and history.
  Future<void> resetAllCustomData() async {
    _customDecks.clear();
    _favoriteDeckIds.clear();
    _roundHistory.clear();
    _settings = const AppSettings();

    await _prefs?.remove(_keyCustomDecks);
    await _prefs?.remove(_keyFavorites);
    await _prefs?.remove(_keyHistory);
    await _prefs?.remove(_keySettings);

    notifyListeners();
  }
}
