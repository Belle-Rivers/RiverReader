import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/application/current_user_provider.dart';
import '../../library/data/book_api.dart';
import '../../vault/data/vault_api.dart';
import '../application/home_provider.dart';
import '../data/home_api.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/river_ui.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final String? userId = ref.watch(sessionUserIdProvider);
    final AsyncValue<HomeSummaryModel?> homeAsync = ref.watch(homeSummaryProvider);
    return RiverScaffold(
      title: 'River Reader',
      subtitle: homeAsync.maybeWhen(
        data: (home) => home?.displayName != null && home!.displayName!.trim().isNotEmpty
            ? 'Welcome back, ${home.displayName!.trim()}'
            : 'Welcome back, scholar',
        orElse: () => 'Welcome back, scholar',
      ),
      showLogo: false,
      tab: RiverTab.home,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
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
        children: <Widget>[

          Text('Pick up where you left off', style: RiverFonts.handwritten(size: 28, color: AppColors.mint)),
          const SizedBox(height: 6),
          if (userId == null) ...<Widget>[
            Row(
              children: <Widget>[
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
          if (userId != null) ...<Widget>[
            homeAsync.when(
              data: (HomeSummaryModel? home) {
                if (home == null) {
                  return const SizedBox.shrink();
                }
                return _HomeStatsRow(stats: home.stats);
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              ),
              error: (Object e, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('Could not load stats: $e', style: theme.textTheme.bodySmall),
              ),
            ),
            const SizedBox(height: 16),
            Text('Continue reading', style: theme.textTheme.headlineMedium?.copyWith(fontSize: 48 / 2)),
            const SizedBox(height: 12),
            homeAsync.when(
              data: (HomeSummaryModel? home) {
                if (home == null) {
                  return const SizedBox.shrink();
                }
                final BookApiModel? book = home.lastOpenedBook;
                if (book == null) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text('No reading session yet. Add a book from your shelf.'),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => context.go('/shelf'),
                          child: const Text('Open shelf'),
                        ),
                      ],
                    ),
                  );
                }
                final double pct = home.lastProgress?.progressPercent ?? book.progressPercent ?? 0;
                return InkWell(
                  onTap: () => context.push('/reader/${book.id}', extra: book),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 60,
                          height: 80,
                          decoration: BoxDecoration(
                            gradient: book.coverRef == null
                                ? const LinearGradient(
                                    colors: <Color>[Color(0xFF5A4432), Color(0xFF32261E)],
                                  )
                                : null,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: book.coverRef != null
                              ? Image.network(
                                  'http://localhost:8000/v1/books/${book.id}/cover?user_id=${ref.read(sessionUserIdProvider)}',
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => const Center(
                                    child: Icon(Icons.book_rounded, color: Colors.white, size: 24),
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                book.title,
                                style: theme.textTheme.titleMedium,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${pct.toStringAsFixed(1)}% · ${book.author ?? 'Unknown'}',
                                style: theme.textTheme.bodyMedium,
                              ),
                              if (home.lastProgress?.chapterTitle != null) ...<Widget>[
                                const SizedBox(height: 2),
                                Text(
                                  home.lastProgress!.chapterTitle!,
                                  style: theme.textTheme.bodySmall,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, size: 16),
                      ],
                    ),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (Object e, _) => Text('Error: $e'),
            ),
          ],
          const SizedBox(height: 20),
          Text('Fresh from the river', style: RiverFonts.handwritten(size: 28, color: AppColors.mint)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text('Latest captures', style: theme.textTheme.headlineMedium?.copyWith(fontSize: 42 / 2)),
              TextButton(
                onPressed: () => context.go('/vault'),
                child: Text('See all', style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.mint)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (userId != null)
            homeAsync.when(
              data: (HomeSummaryModel? home) {
                if (home == null) {
                  return const SizedBox.shrink();
                }
                if (home.recentVaultWords.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text('No words in vault yet. Tap words while reading to capture them.'),
                  );
                }
                return Column(
                  children: home.recentVaultWords.map((VaultItemRead item) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        child: ListTile(
                          title: Text(item.targetWord, style: theme.textTheme.titleMedium),
                          subtitle: Text(
                            item.bookTitle ?? 'Unknown book',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.go('/vault'),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (Object e, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text('Vault preview unavailable: $e'),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('Sign in to view your vault.'),
            ),
          const SizedBox(height: 8),
          homeAsync.when(
            data: (HomeSummaryModel? home) {
              final int due = home?.stats.dueReviewsCount ?? 0;
              return InkWell(
                onTap: () => context.go('/games'),
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(color: AppColors.lavender, borderRadius: BorderRadius.circular(22)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Restoration time', style: RiverFonts.handwritten(size: 28, color: Colors.black87)),
                      Text("Play with today's words", style: theme.textTheme.headlineMedium?.copyWith(fontSize: 46 / 2)),
                      const SizedBox(height: 6),
                      Text(
                        due > 0
                            ? '$due word${due == 1 ? '' : 's'} ready for review — cloze and matches from your vault.'
                            : 'Cloze tests and matches built from your own captures.',
                        style: theme.textTheme.bodyLarge?.copyWith(color: Colors.black87),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: .08),
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Text('Start a round', style: theme.textTheme.labelLarge),
                      ),
                    ],
                  ),
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _HomeStatsRow extends StatelessWidget {
  const _HomeStatsRow({required this.stats});

  final HomeStatsModel stats;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      children: <Widget>[
        Expanded(
          child: _StatChip(
            label: 'Books',
            value: stats.booksCount.toString(),
            theme: theme,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatChip(
            label: 'Vault',
            value: stats.vaultCount.toString(),
            theme: theme,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatChip(
            label: 'Due',
            value: stats.dueReviewsCount.toString(),
            theme: theme,
          ),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.theme,
  });

  final String label;
  final String value;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: <Widget>[
          Text(value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          Text(label, style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }
}
