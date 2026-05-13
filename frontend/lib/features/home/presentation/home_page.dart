import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/application/current_user_provider.dart';
import '../../library/controllers/library_shelf_controller.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/river_ui.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final userId = ref.watch(sessionUserIdProvider);
    return RiverScaffold(
      title: 'River Reader',
      subtitle: 'Welcome back, scholar',
      showLogo: true,
      tab: RiverTab.home,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_awesome, color: AppColors.mint, size: 30),
          const SizedBox(width: 4),
          IconButton(
            onPressed: () => context.go('/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text('Pick up where you left off', style: RiverFonts.handwritten(size: 28, color: AppColors.mint)),
          const SizedBox(height: 6),
          if (userId == null) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.go('/register?mode=signin'),
                    child: const Text('Sign in'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => context.go('/register'),
                    child: const Text('Register'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          if (userId != null) ...[
            Text('Continue reading', style: theme.textTheme.headlineMedium?.copyWith(fontSize: 48/2)),
            const SizedBox(height: 12),
            Consumer(builder: (context, ref, _) {
              final shelfState = ref.watch(libraryShelfControllerProvider);
              return shelfState.when(
                data: (books) {
                  if (books.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text('No books in your shelf yet.'),
                    );
                  }
                  final lastBook = books.last;
                  return InkWell(
                    onTap: () => context.push('/reader/${lastBook.id}', extra: lastBook),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 60,
                            height: 80,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF5A4432), Color(0xFF32261E)],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(lastBook.title, style: theme.textTheme.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 4),
                                Text('${(lastBook.progressPercent ?? 0).toStringAsFixed(1)}% · ${lastBook.author ?? 'Unknown'}', style: theme.textTheme.bodyMedium),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios, size: 16),
                        ],
                      ),
                    ),
                  );
                },
                loading: () => const CircularProgressIndicator(),
                error: (e, _) => Text('Error: $e'),
              );
            }),
          ],
          const SizedBox(height: 20),
          Text('Fresh from the river', style: RiverFonts.handwritten(size: 28, color: AppColors.mint)),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Latest captures', style: theme.textTheme.headlineMedium?.copyWith(fontSize: 42/2)),
            TextButton(
              onPressed: () => context.go('/vault'),
              child: Text('See all', style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.mint)),
            ),
          ]),
          const SizedBox(height: 8),
          if (userId != null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('No words in vault yet.'),
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('Sign in to view your vault.'),
            ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => context.go('/games'),
            borderRadius: BorderRadius.circular(22),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: AppColors.lavender, borderRadius: BorderRadius.circular(22)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Restoration time', style: RiverFonts.handwritten(size: 28, color: Colors.black87)),
                Text("Play with today's words", style: theme.textTheme.headlineMedium?.copyWith(fontSize: 46/2)),
                const SizedBox(height: 6),
                Text('Cloze tests and matches built from your own captures.', style: theme.textTheme.bodyLarge?.copyWith(color: Colors.black87)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: .08), borderRadius: BorderRadius.circular(28)),
                  child: Text('Start a round', style: theme.textTheme.labelLarge),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

