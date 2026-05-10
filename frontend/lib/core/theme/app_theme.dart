import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppThemeMode { sunlight, midnight }

// Whimsical Scholar Design System Colors
class AppColors {
  // Sunlight Theme (Light Mode)
  static const Color surface = Color(0xFFFFFBDC);
  static const Color surfaceDim = Color(0xFFDFDBBD);
  static const Color surfaceBright = Color(0xFFFFFBDC);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF9F5D6);
  static const Color surfaceContainer = Color(0xFFF3EFD0);
  static const Color surfaceContainerHigh = Color(0xFFEDE9CB);
  static const Color surfaceContainerHighest = Color(0xFFE7E4C5);
  static const Color onSurface = Color(0xFF1D1C0A);
  static const Color onSurfaceVariant = Color(0xFF3E4944);
  static const Color inverseSurface = Color(0xFF32311D);
  static const Color inverseOnSurface = Color(0xFFF6F2D3);
  static const Color outline = Color(0xFF6E7A74);
  static const Color outlineVariant = Color(0xFFBDC9C2);
  static const Color surfaceTint = Color(0xFF7FE1BE);
  
  // Primary Colors
  static const Color primary = Color(0xFF7FE1BE);
  static const Color onPrimary = Color(0xFF00644C);
  static const Color primaryContainer = Color(0xFF7FE1BE);
  static const Color onPrimaryContainer = Color(0xFF00644C);
  static const Color inversePrimary = Color(0xFF77D9B6);
  
  // Secondary Colors
  static const Color secondary = Color(0xFFBBAAF6);
  static const Color onSecondary = Color(0xFF2A1A5E);
  static const Color secondaryContainer = Color(0xFFC2B1FD);
  static const Color onSecondaryContainer = Color(0xFF4F4084);
  
  // Tertiary Colors
  static const Color tertiary = Color(0xFFF4D569);
  static const Color onTertiary = Color(0xFF4A3C00);
  static const Color tertiaryContainer = Color(0xFFEBCD62);
  static const Color onTertiaryContainer = Color(0xFF6A5600);
  
  // Error Colors
  static const Color error = Color(0xFFBA1A1A);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onErrorContainer = Color(0xFF93000A);
  
  // Background Colors
  static const Color background = Color(0xFFFFFBDC);
  static const Color onBackground = Color(0xFF1D1C0A);
  static const Color surfaceVariant = Color(0xFFE7E4C5);
  
  // Midnight Theme (Dark Mode) - simplified for now
  static const Color midnightBackground = Color(0xFF1C1B14);
  static const Color midnightSurface = Color(0xFF2A2920);
  static const Color midnightOnSurface = Color(0xFFE7E4C5);
  static const Color midnightPrimary = Color(0xFF77D9B6);
}

class AppThemeState {
  final AppThemeMode mode;
  const AppThemeState(this.mode);

  ThemeData get themeData {
    switch (mode) {
      case AppThemeMode.sunlight:
        return _buildSunlightTheme();
      case AppThemeMode.midnight:
        return _buildMidnightTheme();
    }
  }

  ThemeData _buildSunlightTheme() {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.light(
        brightness: Brightness.light,
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        primaryContainer: AppColors.primaryContainer,
        onPrimaryContainer: AppColors.onPrimaryContainer,
        secondary: AppColors.secondary,
        onSecondary: AppColors.onSecondary,
        secondaryContainer: AppColors.secondaryContainer,
        onSecondaryContainer: AppColors.onSecondaryContainer,
        tertiary: AppColors.tertiary,
        onTertiary: AppColors.onTertiary,
        tertiaryContainer: AppColors.tertiaryContainer,
        onTertiaryContainer: AppColors.onTertiaryContainer,
        error: AppColors.error,
        onError: AppColors.onError,
        errorContainer: AppColors.errorContainer,
        onErrorContainer: AppColors.onErrorContainer,
        surface: AppColors.surface,
        onSurface: AppColors.onSurface,
        surfaceContainerHighest: AppColors.surfaceVariant,
        onSurfaceVariant: AppColors.onSurfaceVariant,
        outline: AppColors.outline,
        outlineVariant: AppColors.outlineVariant,
        inverseSurface: AppColors.inverseSurface,
        onInverseSurface: AppColors.inverseOnSurface,
        inversePrimary: AppColors.inversePrimary,
        surfaceTint: AppColors.surfaceTint,
      ),
      textTheme: _buildTextTheme(),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.onSurface,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 2,
        shadowColor: AppColors.primary.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: const Color(0xFFE3BDBD).withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          elevation: 4,
          shadowColor: AppColors.primary.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      useMaterial3: true,
    );
  }

  ThemeData _buildMidnightTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.midnightBackground,
      colorScheme: const ColorScheme.dark(
        brightness: Brightness.dark,
        primary: AppColors.midnightPrimary,
        onPrimary: AppColors.midnightBackground,
        surface: AppColors.midnightSurface,
        onSurface: AppColors.midnightOnSurface,
      ),
      textTheme: _buildTextTheme().apply(
        bodyColor: AppColors.midnightOnSurface,
        displayColor: AppColors.midnightOnSurface,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.midnightBackground,
        foregroundColor: AppColors.midnightOnSurface,
        elevation: 0,
        centerTitle: true,
      ),
      useMaterial3: true,
    );
  }

  TextTheme _buildTextTheme() {
    return const TextTheme(
      displayLarge: TextStyle(
        fontFamily: 'Newsreader',
        fontSize: 48,
        fontWeight: FontWeight.w600,
        height: 1.1,
        letterSpacing: -0.02,
      ),
      headlineLarge: TextStyle(
        fontFamily: 'Newsreader',
        fontSize: 32,
        fontWeight: FontWeight.w600,
        height: 1.2,
      ),
      headlineMedium: TextStyle(
        fontFamily: 'Newsreader',
        fontSize: 24,
        fontWeight: FontWeight.w500,
        height: 1.3,
      ),
      bodyLarge: TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontSize: 18,
        fontWeight: FontWeight.w400,
        height: 1.6,
      ),
      bodyMedium: TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.6,
      ),
      labelMedium: TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.4,
        letterSpacing: 0.01,
      ),
      labelSmall: TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.4,
      ),
    );
  }
}

class AppThemeNotifier extends Notifier<AppThemeState> {
  @override
  AppThemeState build() => const AppThemeState(AppThemeMode.sunlight);

  void setMode(AppThemeMode mode) {
    state = AppThemeState(mode);
  }
}

final appThemeNotifierProvider = NotifierProvider<AppThemeNotifier, AppThemeState>(() {
  return AppThemeNotifier();
});
