import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppThemeMode { parchment, midnight, ink }

const Color _parchmentBackground = Color(0xFFF4ECD8);
const Color _parchmentForeground = Color(0xFF2C2C2C);
const Color _midnightBackground = Color(0xFF1A1B26);
const Color _midnightForeground = Color(0xFFA9B1D6);
const Color _inkBackground = Color(0xFF000000);
const Color _inkForeground = Color(0xFFE0E0E0);

const double _bodyFontSize = 18;
const double _bodyLineHeight = 1.65;

class AppThemeState {
  final AppThemeMode mode;
  const AppThemeState(this.mode);

  ThemeData get themeData {
    final TextTheme baseTextTheme = const TextTheme().apply(
      bodyColor: _foregroundForMode(mode),
      displayColor: _foregroundForMode(mode),
    ).copyWith(
      bodyMedium: const TextStyle(fontSize: _bodyFontSize, height: _bodyLineHeight),
    );
    switch (mode) {
      case AppThemeMode.midnight:
        return ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: _midnightBackground,
          appBarTheme: const AppBarTheme(backgroundColor: _midnightBackground, foregroundColor: _midnightForeground),
          colorScheme: const ColorScheme.dark(
            surface: _midnightBackground,
            primary: _midnightForeground,
            onSurface: _midnightForeground,
            onPrimary: _midnightBackground,
          ),
          textTheme: baseTextTheme,
        );
      case AppThemeMode.ink:
        return ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: _inkBackground,
          appBarTheme: const AppBarTheme(backgroundColor: _inkBackground, foregroundColor: _inkForeground),
          colorScheme: const ColorScheme.dark(
            surface: _inkBackground,
            primary: _inkForeground,
            onSurface: _inkForeground,
            onPrimary: _inkBackground,
          ),
          textTheme: baseTextTheme,
        );
      case AppThemeMode.parchment:
        return ThemeData(
          brightness: Brightness.light,
          scaffoldBackgroundColor: _parchmentBackground,
          appBarTheme: const AppBarTheme(backgroundColor: _parchmentBackground, foregroundColor: _parchmentForeground),
          colorScheme: const ColorScheme.light(
            surface: _parchmentBackground,
            primary: _parchmentForeground,
            onSurface: _parchmentForeground,
            onPrimary: _parchmentBackground,
          ),
          textTheme: baseTextTheme,
        );
    }
  }

  static Color _foregroundForMode(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.midnight:
        return _midnightForeground;
      case AppThemeMode.ink:
        return _inkForeground;
      case AppThemeMode.parchment:
        return _parchmentForeground;
    }
  }
}

class AppThemeNotifier extends Notifier<AppThemeState> {
  @override
  AppThemeState build() => const AppThemeState(AppThemeMode.parchment);

  void setMode(AppThemeMode mode) {
    state = AppThemeState(mode);
  }
}

final appThemeNotifierProvider = NotifierProvider<AppThemeNotifier, AppThemeState>(() {
  return AppThemeNotifier();
});
