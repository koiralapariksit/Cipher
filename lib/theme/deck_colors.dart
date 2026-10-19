import 'package:flutter/material.dart';
import '../models/deck.dart';

const Color kBlue = Color(0xFF2F5BFF);
const Color kInk = Color(0xFF1A1230);
const Color kInkDim = Color(0xFF5E5778);
const Color kCream = Color(0xFFFFF6E3);
const Color kYellow = Color(0xFFFFD60A);
const Color kLime = Color(0xFFB8F400);
const Color kOrange = Color(0xFFFF7A1A);
const Color kPink = Color(0xFFFF3D8B);
const Color kLavender = Color(0xFFC9B6FF);
const Color kMint = Color(0xFF1FE08F);

// Neo-Brutalist Geometry Tokens
const BorderRadius kAsymmetricRadius = BorderRadius.only(
  topLeft: Radius.circular(26),
  topRight: Radius.circular(26),
  bottomRight: Radius.circular(26),
  bottomLeft: Radius.circular(8),
);

const BorderRadius kAsymmetricSmallRadius = BorderRadius.only(
  topLeft: Radius.circular(16),
  topRight: Radius.circular(16),
  bottomRight: Radius.circular(16),
  bottomLeft: Radius.circular(6),
);

// Neo-Brutalist Hard Offset Shadows
const List<BoxShadow> kHardShadow = [
  BoxShadow(color: kInk, offset: Offset(4, 4), blurRadius: 0),
];

const List<BoxShadow> kSmallShadow = [
  BoxShadow(color: kInk, offset: Offset(2, 2), blurRadius: 0),
];

const List<BoxShadow> kCardShadow = [
  BoxShadow(color: kInk, offset: Offset(6, 6), blurRadius: 0),
];

// Deterministic 5-color deck palette
const List<Color> kDeckColors = [
  Color(0xFFFF7A1A), // orange
  Color(0xFFFF3D8B), // pink
  Color(0xFFC9B6FF), // lavender
  Color(0xFFFFD60A), // yellow
  Color(0xFF1FE08F), // mint
];

/// Returns a consistent, deterministic color for any deck based on its id.
Color deckColorFor(Deck deck) {
  final sum = deck.id.codeUnits.fold<int>(0, (acc, byte) => acc + byte);
  return kDeckColors[sum % kDeckColors.length];
}
