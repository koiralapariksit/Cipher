import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Canonical Color Palette ──────────────────────────────────────────────────
// Sampled from charcoal-to-black reference:
const Color appBgTop = Color(0xFF343434);
const Color appBgMid = Color(0xFF222222);
const Color appBgBottom = Color(0xFF0A0A0A);
const Color appField = Color(0x40000000);
const Color appTile = Color(0x14FFFFFF);
const Color appText = Color(0xFFF2F2F2);
const Color appTextDim = Color(0xFF8E8E8E);
const Color appLine = Color(0x24FFFFFF);

// Semantic indicator tones (subtle and muted for gameplay & results)
const Color appCorrect = Color(0xFF4E9F6E);
const Color appPass = Color(0xFFD47A45);

// ── Uniform Geometry ─────────────────────────────────────────────────────────
const double appRadius = 3.0;
const BorderRadius appBorderRadius = BorderRadius.all(Radius.circular(appRadius));

// ── Background Canvas ────────────────────────────────────────────────────────
const LinearGradient appBackgroundGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [appBgTop, appBgMid, appBgBottom],
  stops: [0.0, 0.47, 1.0],
);

const BoxDecoration appBackgroundDecoration = BoxDecoration(
  gradient: appBackgroundGradient,
);

// ── Typography ───────────────────────────────────────────────────────────────
// Single typeface: GoogleFonts.bricolageGrotesque
TextStyle appFont(
  double size, {
  FontWeight weight = FontWeight.w400,
  Color color = appText,
  double spacing = 0,
  double? height,
}) {
  return GoogleFonts.bricolageGrotesque(
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: spacing,
    height: height,
  );
}

// ── Reusable Component Containers ────────────────────────────────────────────

/// Standard card/tile surface (0x14FFFFFF tint with optional outline)
BoxDecoration appTileBox({
  Color? color,
  Color? borderColor,
  double borderWidth = 0.8,
  double radius = appRadius,
}) {
  return BoxDecoration(
    color: color ?? appTile,
    borderRadius: BorderRadius.circular(radius),
    border: borderColor != null || color == null
        ? Border.all(color: borderColor ?? appLine, width: borderWidth)
        : null,
  );
}

/// Standard field container (0x40000000 dark recess with 3px corners)
BoxDecoration appFieldBox({
  Color? color,
  Color? borderColor,
  double borderWidth = 0.8,
  double radius = appRadius,
}) {
  return BoxDecoration(
    color: color ?? appField,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: borderColor ?? appLine, width: borderWidth),
  );
}

/// Razor-sharp 3px icon button
class AppIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final Color? iconColor;
  final Color? backgroundColor;
  final double size;

  const AppIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.iconColor,
    this.backgroundColor,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    final button = GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor ?? appTile,
          borderRadius: appBorderRadius,
          border: Border.all(color: appLine, width: 0.8),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: iconColor ?? appText, size: size * 0.48),
      ),
    );
    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}

/// Clean section header with 3px architectural hairline
class AppSectionHeader extends StatelessWidget {
  final String title;
  final String? trailing;

  const AppSectionHeader({
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
              style: appFont(11, weight: FontWeight.w600, spacing: 1.2, color: appTextDim),
            ),
            if (trailing != null) ...[
              const Spacer(),
              Text(trailing!, style: appFont(11, color: appTextDim)),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Container(height: 0.8, color: appLine),
      ],
    );
  }
}

