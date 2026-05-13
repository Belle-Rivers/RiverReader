import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';
import 'theme_mode_menu_button.dart';

enum RiverTab { home, shelf, game, vault }

class RiverScaffold extends StatelessWidget {
  const RiverScaffold({
    super.key,
    required this.title,
    required this.body,
    required this.tab,
    this.showLogo = false,
    this.subtitle,
    this.onBack,
    this.trailing,
    this.showSettings = true,
  });

  final String title;
  final String? subtitle;
  final Widget body;
  final RiverTab tab;
  final bool showLogo;
  final VoidCallback? onBack;
  final Widget? trailing;
  final bool showSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: cs.outline))),
              child: Row(
                children: [
                  if (onBack != null) ...[
                    IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back_rounded)),
                    const SizedBox(width: 4),
                  ],
                  if (showLogo)
                    Container(
                      width: 46,
                      height: 46,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(4)),
                      child: Image.asset('assets/images/RiverReader_logo.png', fit: BoxFit.cover),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: theme.textTheme.headlineMedium?.copyWith(fontSize: 24)),
                        if (subtitle != null)
                          Text(subtitle!, style: theme.textTheme.bodyLarge?.copyWith(color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  trailing ??
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const ThemeModeMenuButton(),
                          if (showSettings)
                            IconButton(
                              onPressed: () => context.go('/settings'),
                              icon: const Icon(Icons.settings_outlined),
                            ),
                        ],
                      ),
                ],
              ),
            ),
            Expanded(child: body),
          ],
        ),
      ),
      bottomNavigationBar: _RiverBottomNav(tab: tab),
    );
  }
}

class _RiverBottomNav extends StatelessWidget {
  const _RiverBottomNav({required this.tab});

  final RiverTab tab;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: cs.outline)),
      ),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 14),
      child: Row(
        children: [
          _item(context, RiverTab.home, Icons.home_outlined, Icons.home_rounded, 'Home', '/'),
          _item(context, RiverTab.shelf, Icons.view_agenda_outlined, Icons.view_agenda_rounded, 'Shelf', '/shelf'),
          _item(context, RiverTab.game, Icons.sports_esports_outlined, Icons.sports_esports_rounded, 'Game', '/games'),
          _item(context, RiverTab.vault, Icons.inventory_2_outlined, Icons.inventory_2_rounded, 'Vault', '/vault'),
        ],
      ),
    );
  }

  Widget _item(BuildContext context, RiverTab current, IconData icon, IconData activeIcon, String label, String path) {
    final active = tab == current;
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: InkWell(
        onTap: () => context.go(path),
        borderRadius: BorderRadius.circular(22),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? AppColors.mint : Colors.transparent,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(active ? activeIcon : icon, color: active ? cs.onPrimary : cs.onSurfaceVariant),
              const SizedBox(height: 2),
              Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: active ? cs.onPrimary : cs.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}

class RiverCard extends StatelessWidget {
  const RiverCard({super.key, required this.child, this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outline, width: 1.4),
      ),
      padding: padding,
      child: child,
    );
  }
}
