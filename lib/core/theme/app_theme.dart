import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppThemeMode { parchment, midnight, ink }

class AppThemeState {
  final AppThemeMode mode;
  const AppThemeState(this.mode);

  ThemeData get themeData {
    switch (mode) {
      case AppThemeMode.midnight:
        return ThemeData.dark().copyWith(
          scaffoldBackgroundColor: const Color(0xFF121212),
          // Add typography scale
        );
      case AppThemeMode.ink:
        return ThemeData.dark().copyWith(
          scaffoldBackgroundColor: Colors.black,
        );
      case AppThemeMode.parchment:
      default:
        return ThemeData.light().copyWith(
          scaffoldBackgroundColor: const Color(0xFFFBF5E6), // Parchment
        );
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
