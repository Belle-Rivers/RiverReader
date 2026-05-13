import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/river_ui.dart';
import '../../auth/application/current_user_provider.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(appThemeNotifierProvider).mode;
    final notifier = ref.read(appThemeNotifierProvider.notifier);
    final theme = Theme.of(context);
    final profileAsync = ref.watch(currentUserProfileProvider);

    return RiverScaffold(
      title: 'Settings',
      tab: RiverTab.home,
      onBack: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/');
        }
      },
      showSettings: false,
      trailing: const SizedBox.shrink(),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text('THEME', style: theme.textTheme.headlineMedium?.copyWith(fontSize: 20, color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: _themeCard(
                context,
                selected: mode == AppThemeMode.sunlight,
                name: 'Sunlight',
                icon: Icons.wb_sunny_outlined,
                colors: const [Color(0xFFE9ECC7), Color(0xFF80DDB9)],
                onTap: () => notifier.setMode(AppThemeMode.sunlight),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _themeCard(
                context,
                selected: mode == AppThemeMode.midnight,
                name: 'Midnight',
                icon: Icons.nightlight_round,
                colors: const [Color(0xFF131D35), Color(0xFF4E947D)],
                onTap: () => notifier.setMode(AppThemeMode.midnight),
              ),
            ),
          ]),
          const SizedBox(height: 24),
          Text('ACCOUNT', style: theme.textTheme.headlineMedium?.copyWith(fontSize: 20, color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 10),
          profileAsync.when(
            data: (profile) => RiverCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(profile?.displayName ?? (profile != null ? 'Scholar' : 'Not logged in'), style: const TextStyle(fontFamily: 'Georgia', fontSize: 24, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(profile?.email ?? 'No active session', style: const TextStyle(fontSize: 18)),
                ],
              ),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, st) => Text('Error loading profile: $err'),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () {
              ref.read(sessionUserIdProvider.notifier).clearUserId();
              context.go('/register?mode=signin');
            },
            child: Text('  Sign out', style: theme.textTheme.headlineMedium?.copyWith(fontSize: 20, color: Colors.redAccent)),
          ),
          const SizedBox(height: 70),
          Text('River Reader · v0.1 prototype', textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }

  Widget _themeCard(BuildContext context, {required bool selected, required String name, required IconData icon, required List<Color> colors, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: selected ? AppColors.mint : Theme.of(context).colorScheme.outline, width: selected ? 3 : 1.5),
          color: Theme.of(context).colorScheme.surface,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(height: 80, decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), gradient: LinearGradient(colors: colors))),
          const SizedBox(height: 8),
          Row(children: [Icon(icon), const SizedBox(width: 8), Text(name, style: const TextStyle(fontFamily: 'Georgia', fontSize: 22, fontWeight: FontWeight.w700))]),
        ]),
      ),
    );
  }
}
