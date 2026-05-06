import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';

class ThemeModeMenuButton extends ConsumerWidget {
  const ThemeModeMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppThemeMode currentMode = ref.watch(appThemeNotifierProvider).mode;
    return PopupMenuButton<AppThemeMode>(
      tooltip: 'Theme',
      initialValue: currentMode,
      onSelected: (AppThemeMode mode) {
        ref.read(appThemeNotifierProvider.notifier).setMode(mode);
      },
      itemBuilder: (BuildContext context) => const <PopupMenuEntry<AppThemeMode>>[
        PopupMenuItem<AppThemeMode>(
          value: AppThemeMode.sunlight,
          child: Text('Sunlight'),
        ),
        PopupMenuItem<AppThemeMode>(
          value: AppThemeMode.midnight,
          child: Text('Midnight'),
        ),
      ],
      icon: const Icon(Icons.palette_outlined),
    );
  }
}

