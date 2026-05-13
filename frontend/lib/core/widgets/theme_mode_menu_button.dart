import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';

class ThemeModeMenuButton extends ConsumerWidget {
  const ThemeModeMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(appThemeNotifierProvider);
    final currentMode = themeState.mode;
    return IconButton(
      tooltip: 'Toggle Theme',
      onPressed: () {
        final nextMode = currentMode == AppThemeMode.midnight
            ? AppThemeMode.sunlight
            : AppThemeMode.midnight;
        ref.read(appThemeNotifierProvider.notifier).setMode(nextMode);
      },
      icon: Icon(
        currentMode == AppThemeMode.midnight
            ? Icons.wb_sunny_outlined
            : Icons.nightlight_round,
      ),
    );
  }
}
