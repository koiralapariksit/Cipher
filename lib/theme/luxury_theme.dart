import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Master Luxury Black & Gold Design Palette
const Color kBlack = Colors.black;
const Color kGold = Color(0xFFC8A45C);
const Color kText = Color(0xFFEDEDED);
const Color kTextDim = Color(0xFF8C8C8C);
const Color kPanelTop = Color(0xFF1B1B1B);
const Color kPanelBottom = Color(0xFF0C0C0C);
const Color kSelectedFill = Color(0xFF17140C);
const Color kCorrectGreen = Color(0xFF4E9F6E);
const Color kPassAmber = Color(0xFFD47A45);

/// Typography helper using GoogleFonts.jost
TextStyle luxuryFont(
  double size, {
  FontWeight weight = FontWeight.w400,
  Color color = kText,
  double spacing = 0,
  double? height,
}) {
  return GoogleFonts.jost(
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: spacing,
    height: height,
  );
}

/// Soft embossed panel: charcoal gradient, faint highlight top-left,
/// deep shadow bottom-right, and a thin gold hairline.
BoxDecoration luxuryPanel({
  double radius = 18,
  bool highlight = false,
  Color? borderColor,
  Color? fillTop,
  Color? fillBottom,
}) {
  return BoxDecoration(
    gradient: LinearGradient(
      colors: [
        fillTop ?? kPanelTop,
        fillBottom ?? kPanelBottom,
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: borderColor ??
          (highlight
              ? kGold.withValues(alpha: 0.85)
              : kGold.withValues(alpha: 0.22)),
      width: highlight ? 1.2 : 0.8,
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.white.withValues(alpha: 0.04),
        offset: const Offset(-2, -2),
        blurRadius: 6,
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.9),
        offset: const Offset(3, 3),
        blurRadius: 8,
      ),
    ],
  );
}

/// 44x44 circular button matching home_screen.dart
class LuxuryRoundButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? iconColor;
  final double size;

  const LuxuryRoundButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.iconColor,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: luxuryPanel(radius: size / 2),
          child: Icon(icon, color: iconColor ?? kGold, size: size * 0.48),
        ),
      ),
    );
  }
}

/// Section header with 11px Jost + gold hairline
class LuxurySectionHeader extends StatelessWidget {
  final String title;
  final String? trailing;

  const LuxurySectionHeader({
    super.key,
    required this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title.toUpperCase(),
              style: luxuryFont(11, weight: FontWeight.w500, spacing: 1.6),
            ),
            if (trailing != null) ...[
              const Spacer(),
              Text(
                trailing!,
                style: luxuryFont(11, color: kTextDim),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 0.8,
          color: kGold.withValues(alpha: 0.45),
        ),
      ],
    );
  }
}

