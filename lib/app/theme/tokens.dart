import 'package:flutter/material.dart';

/// Design tokens sampled from the mockups. Never hard-code colors in widgets.
abstract final class Tokens {
  // Colors
  static const ink = Color(0xFF13363E);
  static const inkMuted = Color(0xFF5C6B6E);
  static const surface = Color(0xFFFFFFFF);
  static const background = Color(0xFFF5F7F6);
  static const divider = Color(0xFFE3E7E6);
  static const primary = Color(0xFF1F7A6C);
  static const primarySoft = Color(0xFFDFEEE9);
  static const warning = Color(0xFFA86A12);
  static const warningText = Color(0xFF7A4A0C);
  static const warningSoft = Color(0xFFFCEFDC);
  static const info = Color(0xFF2D7BBF);
  static const infoText = Color(0xFF1F4E79);
  static const infoSoft = Color(0xFFE3EFF8);
  static const danger = Color(0xFFC8553D);
  static const dangerText = Color(0xFF8E2F1E);
  static const dangerSoft = Color(0xFFF7E3DD);
  static const navInactive = Color(0xFFB7C0BE);

  // Spacing
  static const s4 = 4.0;
  static const s8 = 8.0;
  static const s12 = 12.0;
  static const s16 = 16.0;
  static const s24 = 24.0;
  static const s32 = 32.0;
  static const pagePadding = 24.0;

  // Radii
  static const radiusCard = 16.0;
  static const radiusButton = 16.0;
  static const radiusPill = 999.0;

  /// Minimum touch target; nurses use this outdoors, often one-handed.
  static const minTouch = 48.0;

  // Type scale
  static const title = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: ink,
    height: 1.2,
  );
  static const heading = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: ink,
    height: 1.3,
  );
  static const body = TextStyle(fontSize: 15, color: ink, height: 1.4);
  static const bodyStrong = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: ink,
    height: 1.4,
  );
  static const caption = TextStyle(fontSize: 13, color: inkMuted, height: 1.4);
  static const label = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );
}
