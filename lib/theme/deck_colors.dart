import 'package:flutter/material.dart';
import '../models/deck.dart';

const Color kInk = Color(0xFF1A1230);
const Color kCream = Color(0xFFFFF6E3);

const List<Color> kDeckColors = [
  Color(0xFFFF7A1A), // orange
  Color(0xFFFF3D8B), // pink
  Color(0xFFC9B6FF), // lavender
  Color(0xFFFFD60A), // yellow
  Color(0xFF1FE08F), // mint
];

Color deckColorFor(Deck deck) {
  final sum = deck.id.codeUnits.fold<int>(0, (a, b) => a + b);
  return kDeckColors[sum % kDeckColors.length];
}

