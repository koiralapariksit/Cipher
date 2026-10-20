import 'dart:convert';

/// Represents a card deck with an id, name, icon, color, list of items,
/// and metadata (e.g. isCustom, category).
class Deck {
  final String id;
  final String name;
  final String emoji;
  final int colorValue;
  final List<String> items;
  final bool isCustom;
  final String category;
  final String? originalPrompt;
  final bool isAiGenerated;

  const Deck({
    required this.id,
    required this.name,
    required this.emoji,
    required this.colorValue,
    required this.items,
    this.isCustom = false,
    this.category = 'General',
    this.originalPrompt,
    this.isAiGenerated = false,
  });

  /// Returns a shuffled copy of [items].
  List<String> get shuffledItems => List<String>.from(items)..shuffle();

  /// Whether this deck qualifies for dynamic online refresh:
  /// - Default starter decks: Always refreshable using their curated theme.
  /// - AI-Generated decks: Always refreshable using the original prompt/theme.
  /// - Purely hand-crafted user custom decks (without prompt): Protected from overwrite.
  bool get canRefresh => !isCustom || isAiGenerated || (originalPrompt != null && originalPrompt!.isNotEmpty);

  Deck copyWith({
    String? id,
    String? name,
    String? emoji,
    int? colorValue,
    List<String>? items,
    bool? isCustom,
    String? category,
    String? originalPrompt,
    bool? isAiGenerated,
  }) {
    return Deck(
      id: id ?? this.id,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      colorValue: colorValue ?? this.colorValue,
      items: items ?? this.items,
      isCustom: isCustom ?? this.isCustom,
      category: category ?? this.category,
      originalPrompt: originalPrompt ?? this.originalPrompt,
      isAiGenerated: isAiGenerated ?? this.isAiGenerated,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'emoji': emoji,
      'colorValue': colorValue,
      'items': items,
      'isCustom': isCustom,
      'category': category,
      if (originalPrompt != null) 'originalPrompt': originalPrompt,
      'isAiGenerated': isAiGenerated,
    };
  }

  Map<String, dynamic> toJson() => toMap();

  factory Deck.fromMap(Map<String, dynamic> map) {
    return Deck(
      id: map['id'] as String? ?? map['name'] as String? ?? '',
      name: map['name'] as String? ?? '',
      emoji: map['emoji'] as String? ?? '',
      colorValue: (map['colorValue'] as num?)?.toInt() ?? 0xFF38BDF8,
      items: (map['items'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      isCustom: map['isCustom'] as bool? ?? true,
      category: map['category'] as String? ?? 'Custom',
      originalPrompt: map['originalPrompt'] as String?,
      isAiGenerated: map['isAiGenerated'] as bool? ?? false,
    );
  }

  factory Deck.fromJson(dynamic source) {
    if (source is Map<String, dynamic>) {
      return Deck.fromMap(source);
    }
    return Deck.fromMap(json.decode(source as String) as Map<String, dynamic>);
  }

  /// All built-in emoji-free starter decks.
  static const List<Deck> starterDecks = [
    _animals,
    _moviesTv,
    _foodDrinks,
    _sports,
    _countries,
    _celebrities,
  ];

  // ── 1. Animals ────────────────────────────────────────────────────────
  static const _animals = Deck(
    id: 'animals',
    name: 'Animals',
    emoji: '',
    colorValue: 0xFF4E9F6E,
    category: 'Nature',
    items: [
      'Lion', 'Elephant', 'Kangaroo', 'Penguin', 'Giraffe',
      'Chimpanzee', 'Dolphin', 'Bald Eagle', 'Grizzly Bear', 'Cheetah',
      'Flamingo', 'Koala', 'Octopus', 'Wolf', 'Rhinoceros',
      'Hippopotamus', 'Sloth', 'Zebra', 'Panda', 'Platypus',
      'Ostrich', 'Tiger', 'Polar Bear', 'Walrus', 'Chameleon',
      'Hedgehog', 'Peacock', 'Gorilla', 'Otter', 'Crocodile',
      'Camel', 'Meerkat', 'Jaguar', 'Pelican', 'Beaver',
      'Armadillo', 'Badger', 'Skunk', 'Raccoon', 'Lemur',
      'Hyena', 'Antelope', 'Moose', 'Seahorse', 'Starfish',
    ],
  );

  // ── 2. Movies & TV ───────────────────────────────────────────────────
  static const _moviesTv = Deck(
    id: 'movies_tv',
    name: 'Movies & TV',
    emoji: '',
    colorValue: 0xFFB38F4D,
    category: 'Entertainment',
    items: [
      'Titanic', 'Jurassic Park', 'Star Wars', 'The Avengers', 'Harry Potter',
      'The Lion King', 'Spider-Man', 'Finding Nemo', 'Frozen', 'Inception',
      'The Matrix', 'Stranger Things', 'Back to the Future', 'Toy Story', 'Shrek',
      'The Dark Knight', 'Home Alone', 'Avatar', 'Ghostbusters', 'Forrest Gump',
      'Pirates of the Caribbean', 'The Office', 'Friends', 'Game of Thrones', 'Iron Man',
      'Jaws', 'E.T.', 'Indiana Jones', 'Moana', 'Monsters Inc',
      'Squid Game', 'Breaking Bad', 'The Simpsons', 'Black Panther', 'Gladiator',
      'Shrek 2', 'Coco', 'Interstellar', 'Top Gun', 'The Terminator',
      'Mean Girls', 'Pulp Fiction', 'The Wizard of Oz', 'Wednesday', 'The Mandalorian',
    ],
  );

  // ── 3. Food & Drinks ─────────────────────────────────────────────────
  static const _foodDrinks = Deck(
    id: 'food_drinks',
    name: 'Food & Drinks',
    emoji: '',
    colorValue: 0xFFD47A45,
    category: 'Lifestyle',
    items: [
      'Pizza', 'Sushi', 'Cheeseburger', 'Ice Cream', 'Tacos',
      'Pancakes', 'Spaghetti', 'Hot Dog', 'Chocolate Cake', 'French Fries',
      'Burrito', 'Waffles', 'Popcorn', 'Donut', 'Guacamole',
      'Smoothie', 'Croissant', 'Ramen', 'Cotton Candy', 'Fried Chicken',
      'Apple Pie', 'Nachos', 'Milkshake', 'Pretzel', 'Bagel',
      'Cupcake', 'Lasagna', 'Boba Tea', 'Cheesecake', 'Churros',
      'Dumplings', 'Falafel', 'Fondue', 'Barbecue Ribs', 'Crepes',
      'Pecan Pie', 'Gummy Bears', 'Milk Chocolate', 'Espresso', 'Hot Chocolate',
      'Tiramisu', 'Caesar Salad', 'Fish and Chips', 'Macaroni and Cheese', 'Shawarma',
    ],
  );

  // ── 4. Sports ────────────────────────────────────────────────────────
  static const _sports = Deck(
    id: 'sports',
    name: 'Sports',
    emoji: '',
    colorValue: 0xFF7A8691,
    category: 'Actions',
    items: [
      'Soccer', 'Basketball', 'Baseball', 'Tennis', 'American Football',
      'Swimming', 'Volleyball', 'Golf', 'Skateboarding', 'Surfing',
      'Bowling', 'Boxing', 'Ice Hockey', 'Skiing', 'Snowboarding',
      'Gymnastics', 'Table Tennis', 'Badminton', 'Archery', 'Cycling',
      'Wrestling', 'Cricket', 'Rugby', 'Rock Climbing', 'Karate',
      'Figure Skating', 'Marathon', 'Dodgeball', 'Rowing', 'Fencing',
      'Horse Racing', 'Water Polo', 'Javelin Throw', 'Pole Vault', 'Curling',
      'Bobsleigh', 'Billiards', 'Darts', 'BMX Racing', 'Triathlon',
      'Weightlifting', 'Kayaking', 'Handball', 'Lacrosse', 'Sumo Wrestling',
    ],
  );

  // ── 5. Countries ─────────────────────────────────────────────────────
  static const _countries = Deck(
    id: 'countries',
    name: 'Countries',
    emoji: '',
    colorValue: 0xFF2F5BFF,
    category: 'World',
    items: [
      'France', 'Japan', 'Brazil', 'Australia', 'Canada',
      'Egypt', 'Italy', 'India', 'Mexico', 'Germany',
      'United Kingdom', 'Spain', 'South Africa', 'Argentina', 'Thailand',
      'Greece', 'Norway', 'South Korea', 'New Zealand', 'Switzerland',
      'China', 'United States', 'Turkey', 'Iceland', 'Netherlands',
      'Peru', 'Morocco', 'Sweden', 'Portugal', 'Ireland',
      'Singapore', 'Vietnam', 'Kenya', 'Chile', 'Colombia',
      'Austria', 'Finland', 'Poland', 'Croatia', 'Philippines',
      'Nepal', 'Jamaica', 'Cuba', 'Costa Rica', 'Belgium',
    ],
  );

  // ── 6. Celebrities ───────────────────────────────────────────────────
  static const _celebrities = Deck(
    id: 'celebrities',
    name: 'Celebrities',
    emoji: '',
    colorValue: 0xFFFF3D8B,
    category: 'Entertainment',
    items: [
      'Taylor Swift', 'Leonardo DiCaprio', 'Beyonce', 'Tom Cruise', 'Rihanna',
      'Dwayne Johnson', 'Lady Gaga', 'Brad Pitt', 'Selena Gomez', 'Will Smith',
      'Ariana Grande', 'Keanu Reeves', 'Adele', 'Johnny Depp', 'Billie Eilish',
      'Morgan Freeman', 'Zendaya', 'Robert Downey Jr', 'Scarlett Johansson', 'Cristiano Ronaldo',
      'Lionel Messi', 'Oprah Winfrey', 'Ed Sheeran', 'Tom Hanks', 'Jennifer Aniston',
      'Michael Jackson', 'Elvis Presley', 'Madonna', 'Justin Bieber', 'Shakira',
      'Kanye West', 'Drake', 'Bruno Mars', 'Eminem', 'Katy Perry',
      'Barack Obama', 'Miley Cyrus', 'Chris Hemsworth', 'Ryan Reynolds', 'Emma Watson',
      'Harrison Ford', 'Jackie Chan', 'Gordon Ramsay', 'Steve Jobs', 'Albert Einstein',
    ],
  );
}
