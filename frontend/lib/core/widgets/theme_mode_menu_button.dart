import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';

class ThemeModeMenuButton extends ConsumerWidget {
  const ThemeModeMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMode = ref.watch(appThemeNotifierProvider).mode;
    return PopupMenuButton<AppThemeMode>(
      tooltip: 'Theme',
      onSelected: (mode) => ref.read(appThemeNotifierProvider.notifier).setMode(mode),
      itemBuilder: (_) => const [
        PopupMenuItem(value: AppThemeMode.sunlight, child: Text('Sunlight')),
        PopupMenuItem(value: AppThemeMode.midnight, child: Text('Midnight')),
      ],
      icon: Icon(currentMode == AppThemeMode.midnight ? Icons.wb_sunny_outlined : Icons.nightlight_round),
    );
  }
}
