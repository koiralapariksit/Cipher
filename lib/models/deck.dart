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

  const Deck({
    required this.id,
    required this.name,
    required this.emoji,
    required this.colorValue,
    required this.items,
    this.isCustom = false,
    this.category = 'General',
  });

  /// Returns a shuffled copy of [items].
  List<String> get shuffledItems => List<String>.from(items)..shuffle();

  Deck copyWith({
    String? id,
    String? name,
    String? emoji,
    int? colorValue,
    List<String>? items,
    bool? isCustom,
    String? category,
  }) {
    return Deck(
      id: id ?? this.id,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      colorValue: colorValue ?? this.colorValue,
      items: items ?? this.items,
      isCustom: isCustom ?? this.isCustom,
      category: category ?? this.category,
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
    };
  }

  Map<String, dynamic> toJson() => toMap();

  factory Deck.fromMap(Map<String, dynamic> map) {
    return Deck(
      id: map['id'] as String? ?? map['name'] as String? ?? '',
      name: map['name'] as String? ?? '',
      emoji: map['emoji'] as String? ?? '🎯',
      colorValue: (map['colorValue'] as num?)?.toInt() ?? 0xFF38BDF8,
      items: (map['items'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      isCustom: map['isCustom'] as bool? ?? true,
      category: map['category'] as String? ?? 'Custom',
    );
  }

  factory Deck.fromJson(dynamic source) {
    if (source is Map<String, dynamic>) {
      return Deck.fromMap(source);
    }
    return Deck.fromMap(json.decode(source as String) as Map<String, dynamic>);
  }

  /// All built-in starter decks.
  static const List<Deck> starterDecks = [
    _animals,
    _food,
    _movies,
    _sports,
    _everydayObjects,
    _actions,
  ];

  // ── Animals ──────────────────────────────────────────────────────────
  static const _animals = Deck(
    id: 'starter_animals',
    name: 'Animals',
    emoji: '🦁',
    colorValue: 0xFF4E9F6E, // Luxury Emerald
    category: 'Nature',
    items: [
      'Lion', 'Elephant', 'Kangaroo', 'Penguin', 'Giraffe',
      'Chimpanzee', 'Dolphin', 'Bald Eagle', 'Grizzly Bear', 'Cheetah',
      'Flamingo', 'Koala', 'Octopus', 'Wolf', 'Rhinoceros',
      'Hippopotamus', 'Sloth', 'Zebra', 'Panda', 'Platypus',
      'Ostrich', 'Tiger', 'Polar Bear', 'Walrus', 'Chameleon',
      'Hedgehog', 'Peacock', 'Gorilla', 'Otter', 'Crocodile',
    ],
  );

  // ── Food ─────────────────────────────────────────────────────────────
  static const _food = Deck(
    id: 'starter_food',
    name: 'Food & Drinks',
    emoji: '🍕',
    colorValue: 0xFFD47A45, // Cognac Amber
    category: 'Lifestyle',
    items: [
      'Pizza', 'Sushi', 'Cheeseburger', 'Ice Cream', 'Tacos',
      'Pancakes', 'Spaghetti', 'Hot Dog', 'Chocolate Cake', 'French Fries',
      'Burrito', 'Waffles', 'Popcorn', 'Donut', 'Guacamole',
      'Smoothie', 'Croissant', 'Ramen', 'Cotton Candy', 'Fried Chicken',
      'Apple Pie', 'Nachos', 'Milkshake', 'Pretzel', 'Bagel',
      'Cupcake', 'Lasagna', 'Boba Tea', 'Cheesecake', 'Churros',
    ],
  );

  // ── Movies & TV ──────────────────────────────────────────────────────
  static const _movies = Deck(
    id: 'starter_movies',
    name: 'Movies & TV',
    emoji: '🍿',
    colorValue: 0xFFB38F4D, // Warm Bronze
    category: 'Entertainment',
    items: [
      'Titanic', 'Jurassic Park', 'Star Wars', 'The Avengers', 'Harry Potter',
      'The Lion King', 'Spider-Man', 'Finding Nemo', 'Frozen', 'Inception',
      'The Matrix', 'Stranger Things', 'Back to the Future', 'Toy Story', 'Shrek',
      'The Dark Knight', 'Home Alone', 'Avatar', 'Ghostbusters', 'Forrest Gump',
      'Pirates of the Caribbean', 'The Office', 'Friends', 'Game of Thrones', 'Iron Man',
      'Jaws', 'E.T.', 'Indiana Jones', 'Moana', 'Monsters Inc',
    ],
  );

  // ── Sports & Fitness ─────────────────────────────────────────────────
  static const _sports = Deck(
    id: 'starter_sports',
    name: 'Sports',
    emoji: '⚽',
    colorValue: 0xFF7A8691, // Muted Slate Stone
    category: 'Sports',
    items: [
      'Soccer', 'Basketball', 'Baseball', 'Tennis', 'American Football',
      'Swimming', 'Volleyball', 'Golf', 'Skateboarding', 'Surfing',
      'Bowling', 'Boxing', 'Ice Hockey', 'Skiing', 'Snowboarding',
      'Gymnastics', 'Table Tennis', 'Badminton', 'Archery', 'Cycling',
      'Wrestling', 'Cricket', 'Rugby', 'Rock Climbing', 'Karate',
      'Figure Skating', 'Marathon', 'Dodgeball', 'Rowing', 'Fencing',
    ],
  );

  // ── Everyday Objects ─────────────────────────────────────────────────
  static const _everydayObjects = Deck(
    id: 'starter_objects',
    name: 'Objects',
    emoji: '💡',
    colorValue: 0xFFC8A45C, // Metallic Gold
    category: 'Everyday',
    items: [
      'Toothbrush', 'Umbrella', 'Coffee Mug', 'Headphones', 'Sunglasses',
      'Backpack', 'Smartphone', 'Wristwatch', 'Flashlight', 'Keys',
      'Pillow', 'Laptop', 'Water Bottle', 'Scissors', 'Toaster',
      'Microwave', 'Bicycle', 'Spoon', 'Mirror', 'Blanket',
      'Wallet', 'Guitar', 'Hair Dryer', 'Clock', 'Candle',
      'Shoelaces', 'Remote Control', 'Trash Can', 'Book', 'Hammer',
    ],
  );

  // ── Actions & Verbs ──────────────────────────────────────────────────
  static const _actions = Deck(
    id: 'starter_actions',
    name: 'Actions',
    emoji: '🎭',
    colorValue: 0xFFA65B32, // Deep Terracotta
    category: 'Activity',
    items: [
      'Dancing', 'Singing', 'Cooking', 'Juggling', 'Sleeping',
      'Whispering', 'Laughing', 'Swimming', 'Yawning', 'Sneezing',
      'Driving', 'Painting', 'Fishing', 'Typing', 'Reading',
      'Exercising', 'Crying', 'Clapping', 'Skipping', 'Winking',
      'Stretching', 'Meditating', 'Shuffling Cards', 'Whistling', 'Taking a Selfie',
      'Brushing Teeth', 'Walking a Dog', 'Playing Video Games', 'Baking Cookies', 'Climbing a Tree',
    ],
  );
}
