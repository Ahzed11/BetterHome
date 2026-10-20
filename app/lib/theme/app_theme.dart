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
    fontFamily: AppTypography.textFont,
    scaffoldBackgroundColor: AppTokens.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: AppTokens.surface,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      titleTextStyle: AppTypography.display.copyWith(fontSize: 20),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppTokens.brand,
      foregroundColor: AppTokens.onBrand,
      shape: StadiumBorder(),
      extendedTextStyle: TextStyle(
        fontFamily: AppTypography.textFont,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppTokens.card,
      indicatorColor: AppTokens.brandTint,
      indicatorShape: const StadiumBorder(),
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => AppTypography.label.copyWith(
          fontSize: 12,
          color: states.contains(WidgetState.selected)
              ? AppTokens.brand
              : AppTokens.inkMuted,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w600,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? AppTokens.brand
              : AppTokens.inkMuted,
        ),
      ),
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
