import 'package:flutter/material.dart';

/// Semantic design tokens from the project specification §8.
abstract final class AppTokens {
  static const Color brand = Color(0xFF0B7A70);
  static const Color overdue = Color(0xFFE07A5F);
  static const Color surface = Color(0xFFF7FAF9);
  static const Color onBrand = Color(0xFFFFFFFF);
  static const Color ink = Color(0xFF12201D);
  static const Color inkMuted = Color(0xFF5A6A66);
  static const Color brandTint = Color(0xFFDFF0EC);
  static const Color card = Color(0xFFFFFFFF);
  static const Color outline = Color(0xFFDCE2DC);
  static const Color divider = Color(0xFFEEF1EE);

  /// Outline of an empty check box: dark enough for the 3:1 contrast of a control boundary.
  static const Color controlOutline = Color(0xFF7F8F8A);
  static const double radiusMd = 16;
  static const double radiusLg = 20;
  static const double radiusPill = 999;
  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 16;
  static const double spaceLg = 24;
  static const double minTouchTarget = 44;

  /// Material tap target; the accessibility baseline checks Android's 48 px.
  static const double minTapTarget = 48;
  static const double pillHeight = 40;
  static const double fieldHeight = 52;
  static const double checkBoxSize = 24;
}

/// Text styles of the design. The design uses Bricolage Grotesque for titles and Figtree for text;
/// until those fonts are bundled, the platform font is used and only these styles change.
abstract final class AppTypography {
  static const TextStyle display = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    height: 1.1,
    letterSpacing: -0.3,
    color: AppTokens.ink,
  );
  static const TextStyle eyebrow = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppTokens.inkMuted,
  );
  static const TextStyle body = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppTokens.ink,
  );
  static const TextStyle bodyMuted = TextStyle(
    fontSize: 16,
    color: AppTokens.inkMuted,
  );
  static const TextStyle label = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppTokens.ink,
  );
  static const TextStyle sectionLabel = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
    color: AppTokens.inkMuted,
  );
}
