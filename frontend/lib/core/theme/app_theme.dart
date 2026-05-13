import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

enum AppThemeMode { sunlight, midnight }

class AppColors {
  static const Color mint = Color(0xFF73D8B4);
  static const Color lavender = Color(0xFFA894ED);

  static const Color lightBg = Color(0xFFF1F0CC);
  static const Color lightSurface = Color(0xFFF7F7F7);
  static const Color lightText = Color(0xFF1F1B14);
  static const Color lightMuted = Color(0xFF605B51);

  static const Color darkBg = Color(0xFF030A23);
  static const Color darkSurface = Color(0xFF1A223C);
  static const Color darkText = Color(0xFFF9F4DA);
  static const Color darkMuted = Color(0xFFA0A7C0);
}

class RiverFonts {
  static TextStyle handwritten({
    double size = 32,
    Color? color,
    FontWeight fontWeight = FontWeight.w600,
  }) {
    return GoogleFonts.caveat(
      fontSize: size,
      fontWeight: fontWeight,
      color: color,
      height: 1,
    );
  }
}

class AppThemeState {
  const AppThemeState(this.mode);

  final AppThemeMode mode;

  bool get isDark => mode == AppThemeMode.midnight;

  ThemeData get themeData => isDark ? _buildMidnightTheme() : _buildSunlightTheme();

  ThemeData _buildSunlightTheme() {
    const scheme = ColorScheme.light(
      primary: AppColors.mint,
      onPrimary: Color(0xFF08392E),
      surface: AppColors.lightSurface,
      onSurface: AppColors.lightText,
      onSurfaceVariant: AppColors.lightMuted,
      outline: Color(0xFFC9C5B5),
      secondary: AppColors.lavender,
      tertiary: Color(0xFFEFD16A),
      error: Color(0xFFE73B3B),
    );
    return _baseTheme(scheme, AppColors.lightBg, false);
  }

  ThemeData _buildMidnightTheme() {
    const scheme = ColorScheme.dark(
      primary: AppColors.mint,
      onPrimary: Color(0xFF042117),
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkText,
      onSurfaceVariant: AppColors.darkMuted,
      outline: Color(0xFF313C62),
      secondary: AppColors.lavender,
      tertiary: Color(0xFFD8BA59),
      error: Color(0xFFFF6D7A),
    );
    return _baseTheme(scheme, AppColors.darkBg, true);
  }

  ThemeData _baseTheme(ColorScheme scheme, Color background, bool dark) {
    final textTheme = TextTheme(
      displayLarge: TextStyle(
        fontFamily: 'Georgia',
        fontSize: 44,
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
      headlineLarge: TextStyle(
        fontFamily: 'Georgia',
        fontSize: 36,
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
      headlineMedium: TextStyle(
        fontFamily: 'Georgia',
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
      titleLarge: TextStyle(
        fontFamily: 'Georgia',
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
      bodyLarge: TextStyle(
        fontFamily: 'Trebuchet MS',
        fontSize: 17,
        height: 1.4,
        color: scheme.onSurface,
      ),
      bodyMedium: TextStyle(
        fontFamily: 'Trebuchet MS',
        fontSize: 14,
        height: 1.4,
        color: scheme.onSurfaceVariant,
      ),
      labelLarge: TextStyle(
        fontFamily: 'Trebuchet MS',
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      labelMedium: TextStyle(
        fontFamily: 'Trebuchet MS',
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: scheme.onSurfaceVariant,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: dark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: background,
      colorScheme: scheme,
      textTheme: textTheme,
      dividerColor: scheme.outline,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outline, width: 1.3),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        hintStyle: textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: scheme.outline, width: 1.4),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: scheme.outline, width: 1.4),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: AppColors.mint, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
          backgroundColor: AppColors.mint,
          foregroundColor: scheme.onPrimary,
          textStyle: textTheme.labelLarge,
          minimumSize: const Size.fromHeight(52),
        ),
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

final appThemeNotifierProvider = NotifierProvider<AppThemeNotifier, AppThemeState>(
  AppThemeNotifier.new,
);
