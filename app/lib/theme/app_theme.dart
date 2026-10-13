import 'package:betterhome/theme/tokens.dart';
import 'package:flutter/material.dart';

ThemeData buildAppTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppTokens.brand,
    primary: AppTokens.brand,
    surface: AppTokens.surface,
    brightness: Brightness.light,
  );
  return ThemeData(
    colorScheme: colorScheme,
    useMaterial3: true,
    scaffoldBackgroundColor: AppTokens.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: AppTokens.surface,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(
          AppTokens.minTouchTarget,
          AppTokens.minTouchTarget,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      ),
    ),
  );
}
