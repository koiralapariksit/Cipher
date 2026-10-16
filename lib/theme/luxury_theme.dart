// Compatibility export for app_theme
export 'app_theme.dart';

import 'package:flutter/material.dart';
import 'app_theme.dart';

// Backwards compatibility aliases mapped to new canonical tokens
const Color kBlack = appBgBottom;
const Color kGold = appText;
const Color kText = appText;
const Color kTextDim = appTextDim;
const Color kPanelTop = appBgTop;
const Color kPanelBottom = appBgBottom;
const Color kSelectedFill = appTile;
const Color kCorrectGreen = appCorrect;
const Color kPassAmber = appPass;

TextStyle luxuryFont(
  double size, {
  FontWeight weight = FontWeight.w400,
  Color color = appText,
  double spacing = 0,
  double? height,
}) =>
    appFont(size,
        weight: weight, color: color, spacing: spacing, height: height);

BoxDecoration luxuryPanel({
  double radius = appRadius,
  bool highlight = false,
  Color? borderColor,
  Color? fillTop,
  Color? fillBottom,
}) {
  return BoxDecoration(
    color: appTile,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
        color: borderColor ?? (highlight ? appText : appLine),
        width: 0.8),
  );
}

typedef LuxuryRoundButton = AppIconButton;
typedef LuxurySectionHeader = AppSectionHeader;
