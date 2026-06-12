import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/river_ui.dart';
import '../../vault/application/vault_provider.dart';

class GamesPage extends ConsumerWidget {
  const GamesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final vaultItemsAsync = ref.watch(vaultItemsProvider);

    return RiverScaffold(
      title: 'Restoration',
      tab: RiverTab.game,
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: vaultItemsAsync.when(
          data: (items) {
            if (items.isEmpty) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _poolBanner(context, theme, 0),
                ],
              );
            }
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _poolBanner(context, theme, items.length),
                  const SizedBox(height: 14),
                  _gameCard(
                    context,
                    Icons.extension_rounded,
                    AppColors.mint.withValues(alpha: .3),
                    'Complete the sentence',
                    'Fill in the blank using the right word from your vault.',
                    () => context.go('/games/complete-sentence'),
                  ),
                  const SizedBox(height: 12),
                  _gameCard(
                    context,
                    Icons.shuffle_rounded,
                    AppColors.lavender.withValues(alpha: .35),
                    'Match meanings',
                    'Pair each word with its definition.',
                    () => context.go('/games/match-meanings'),
                  ),
                  const SizedBox(height: 12),
                  _gameCard(
                    context,
                    Icons.compare_arrows_rounded,
                    const Color(0xFFEFD16A).withValues(alpha: .35),
                    'Context Clash',
                    'Pick the sentence that makes logical sense.',
                    () => context.go('/games/context-clash'),
                  ),
                  const SizedBox(height: 12),
                  _gameCard(
                    context,
                    Icons.rule_rounded,
                    AppColors.mint.withValues(alpha: .25),
                    'Odd One Out',
                    'Find the word that doesn\'t belong with the others.',
                    () => context.go('/games/odd-one-out'),
                  ),
                  const SizedBox(height: 12),
                  _gameCard(
                    context,
                    Icons.fact_check_rounded,
                    AppColors.lavender.withValues(alpha: .25),
                    'True or Bluff',
                    'Decide if the definition statement is true or a bluff.',
                    () => context.go('/games/true-or-bluff'),
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, st) => Center(child: Text('Error: $err')),
        ),
      ),
    );
  }

  Widget _poolBanner(BuildContext context, ThemeData theme, int count) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFECCB63),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("today's pool", style: RiverFonts.handwritten(size: 30, color: Colors.black87)),
          Text(
            '$count words ready to play',
            style: theme.textTheme.headlineMedium?.copyWith(fontSize: 48 / 2),
          ),
          Text(
            count == 0
                ? 'Capture words in your vault to unlock games.'
                : 'Pulled from your latest captures across all books.',
            style: theme.textTheme.bodyLarge?.copyWith(color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _gameCard(
    BuildContext context,
    IconData icon,
    Color iconBg,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: RiverCard(
        child: Row(
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(24)),
              child: Icon(icon, size: 38),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                  Text(subtitle, style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded),
          ],
        ),
      ),
    );
  }
}
