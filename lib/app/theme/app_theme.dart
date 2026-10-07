import 'package:flutter/material.dart';

import 'tokens.dart';

ThemeData buildAppTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: Tokens.primary,
        brightness: Brightness.light,
      ).copyWith(
        primary: Tokens.primary,
        onPrimary: Colors.white,
        surface: Tokens.surface,
        onSurface: Tokens.ink,
        error: Tokens.danger,
      );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Tokens.background,
    dividerColor: Tokens.divider,
    textTheme: const TextTheme(
      headlineSmall: Tokens.title,
      titleMedium: Tokens.heading,
      bodyMedium: Tokens.body,
      bodySmall: Tokens.caption,
      labelSmall: Tokens.label,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(Tokens.minTouch),
        backgroundColor: Tokens.primary,
        foregroundColor: Colors.white,
        textStyle: Tokens.bodyStrong,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Tokens.radiusButton),
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Tokens.ink,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Tokens.radiusButton),
      ),
    ),
  );
}
