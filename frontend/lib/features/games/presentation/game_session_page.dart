import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/river_ui.dart';
import '../application/game_session_controller.dart';
import '../data/game_api.dart';

class GameSessionPage extends ConsumerStatefulWidget {
  const GameSessionPage({super.key, required this.kind});

  final GameSessionKind kind;

  @override
  ConsumerState<GameSessionPage> createState() => _GameSessionPageState();
}

class _GameSessionPageState extends ConsumerState<GameSessionPage> {
  bool get _isSentence => widget.kind == GameSessionKind.completeSentence;

  @override
  Widget build(BuildContext context) {
    final GameSessionVm vm = ref.watch(gameSessionProvider(widget.kind));
    final GameSessionNotifier notifier = ref.read(gameSessionProvider(widget.kind).notifier);
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final String title = _isSentence ? 'Complete the sentence' : 'Match meanings';
    return RiverScaffold(
      title: title,
      tab: RiverTab.game,
      onBack: () => context.go('/games'),
      body: _body(context, theme, cs, vm, notifier),
    );
  }

  Widget _body(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
    GameSessionVm vm,
    GameSessionNotifier notifier,
  ) {
    switch (vm.status) {
      case GameLoadStatus.loading:
        return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
      case GameLoadStatus.empty:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'No words ready for this game yet.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  'Capture a few words while reading, then come back.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        );
      case GameLoadStatus.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(vm.errorMessage ?? 'Something went wrong.', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(onPressed: () => notifier.retryLoad(), child: const Text('Retry')),
              ],
            ),
          ),
        );
      case GameLoadStatus.complete:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Round complete', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text('XP earned this session: ${vm.xp}', style: theme.textTheme.bodyLarge),
                const SizedBox(height: 20),
                FilledButton(onPressed: () => context.go('/games'), child: const Text('Back to games')),
              ],
            ),
          ),
        );
      case GameLoadStatus.ready:
        return _gameplay(context, theme, cs, vm, notifier);
    }
  }

  TextStyle _serif(BuildContext context, {double size = 17, FontWeight weight = FontWeight.w600}) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return TextStyle(fontSize: size, height: 1.35, fontWeight: weight, color: cs.onSurface);
  }

  TextStyle _sansUi(BuildContext context, {double size = 13, FontWeight weight = FontWeight.w600}) {
    return Theme.of(context).textTheme.labelLarge!.copyWith(fontSize: size, fontWeight: weight);
  }

  Widget _gameplay(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
    GameSessionVm vm,
    GameSessionNotifier notifier,
  ) {
    final int total = vm.deck.length;
    final double progress = _isSentence
        ? ((vm.currentIndex + (vm.showingFeedback ? 1 : 0.5)) / (total == 0 ? 1 : total)).clamp(0.0, 1.0)
        : (vm.matchedSrsIds.isEmpty ? 0.03 : vm.matchedSrsIds.length / (total == 0 ? 1 : total)).clamp(0.0, 1.0);
    final int comboShow = vm.comboStreak == 0 ? 0 : vm.comboStreak;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _statPill(context, Icons.local_fire_department_outlined, 'x$comboShow'),
            if (_isSentence)
              _hearts(vm.lives)
            else
              _statPill(context, Icons.timer_outlined, '${vm.matchSecondsLeft}s'),
            _statPill(context, Icons.auto_awesome_outlined, '${vm.xp}'),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _isSentence ? 'ROUND ${vm.currentIndex + 1} / $total' : 'PAIRS ${vm.matchedSrsIds.length} / $total',
              style: theme.textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant, letterSpacing: 0.6),
            ),
            if (_isSentence)
              Text('${vm.secondsLeftCloze}s', style: theme.textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant))
            else
              Text('${(progress * 100).round()}%', style: theme.textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 5,
            backgroundColor: cs.outline.withValues(alpha: .35),
            color: AppColors.mint,
          ),
        ),
        const SizedBox(height: 16),
        if (vm.matchTimeUp)
          RiverCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text("Time's up", style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text('Your combo and XP are saved for the next round.', style: theme.textTheme.bodySmall),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => notifier.retryLoad(),
                  child: const Text('Play again'),
                ),
              ],
            ),
          )
        else if (_isSentence)
          _clozeSection(context, theme, cs, vm, notifier)
        else
          _matchSection(context, theme, cs, vm, notifier),
      ],
    );
  }

  Widget _statPill(BuildContext context, IconData icon, String text) {
    final ThemeData theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: .5)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 6),
            Text(text, style: _sansUi(context, size: 13)),
          ],
        ),
      ),
    );
  }

  Widget _hearts(int lives) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List<Widget>.generate(3, (int i) {
        final bool filled = i < lives;
        return Padding(
          padding: const EdgeInsets.only(left: 2),
          child: Icon(
            filled ? Icons.favorite : Icons.favorite_border,
            size: 20,
            color: filled ? const Color(0xFFFF585D) : const Color(0xFF9EA5C0),
          ),
        );
      }),
    );
  }

  Widget _clozeSection(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
    GameSessionVm vm,
    GameSessionNotifier notifier,
  ) {
    final GameDeckItemRead? item = vm.currentCloze;
    if (item == null) {
      return const SizedBox.shrink();
    }
    final String? book = item.bookTitle;
    final String fromLine = book != null && book.isNotEmpty ? 'FROM "$book"' : 'FROM YOUR VAULT';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RiverCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fromLine,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Text(item.prompt, style: _serif(context, size: 17)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints c) {
            final double w = (c.maxWidth - 10) / 2;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: vm.shuffledChoices.map((String option) {
                return SizedBox(
                  width: w,
                  child: _clozeChoiceTile(
                    context,
                    option,
                    vm,
                    notifier,
                    width: w,
                  ),
                );
              }).toList(),
            );
          },
        ),
        if (vm.showingFeedback) ...[
          const SizedBox(height: 14),
          _clozeFeedback(context, theme, cs, vm, notifier),
        ],
      ],
    );
  }

  Widget _clozeChoiceTile(
    BuildContext context,
    String option,
    GameSessionVm vm,
    GameSessionNotifier notifier, {
    required double width,
  }) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final bool chosen = option == vm.lastSelection;
    final bool correct = option.toLowerCase() == (vm.currentCloze?.correctAnswer ?? '').toLowerCase();
    Color border = cs.outline;
    Color fill = cs.surface;
    if (vm.showingFeedback) {
      if (correct) {
        border = AppColors.mint;
        fill = AppColors.mint.withValues(alpha: .16);
      } else if (chosen) {
        border = cs.error;
        fill = cs.error.withValues(alpha: .12);
      }
    }
    return Material(
      color: fill,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: vm.showingFeedback || vm.outOfLives ? null : () => notifier.selectClozeOption(option),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: width,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border, width: chosen || (vm.showingFeedback && correct) ? 2 : 1),
          ),
          alignment: Alignment.center,
          child: Text(
            option,
            textAlign: TextAlign.center,
            style: _serif(context, size: 15, weight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  Widget _clozeFeedback(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
    GameSessionVm vm,
    GameSessionNotifier notifier,
  ) {
    final GameDeckItemRead? item = vm.currentCloze;
    if (item == null) {
      return const SizedBox.shrink();
    }
    final bool? ok = vm.lastCorrect;
    final String correctWord = item.correctAnswer;
    final String? def = item.definition;
    final String explain = def != null && def.isNotEmpty ? '$correctWord — $def' : correctWord;
    final String headline = ok == true
        ? 'Exactly right.'
        : ok == false && vm.lastSelection == null
            ? "Time's up."
            : 'Not quite.';
    return RiverCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(headline, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(explain, style: theme.textTheme.bodyMedium?.copyWith(height: 1.35)),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: vm.outOfLives ? () => context.go('/games') : () => notifier.clozeAdvance(),
            child: Text(vm.outOfLives ? 'Done' : 'Next →'),
          ),
        ],
      ),
    );
  }

  Widget _matchSection(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
    GameSessionVm vm,
    GameSessionNotifier notifier,
  ) {
    final List<String> defs = vm.deck.isNotEmpty ? vm.deck.first.choices : <String>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Tap a word, then its meaning. Misses cost 3 seconds.',
          style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant, height: 1.3),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints c) {
            final double tileW = (c.maxWidth - 10) / 2;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: vm.deck.map((GameDeckItemRead row) {
                final bool matched = vm.matchedSrsIds.contains(row.srsItemId);
                final bool sel = vm.selectedWordSrsId == row.srsItemId;
                Color b = cs.outline;
                Color bg = cs.surface;
                if (matched) {
                  b = AppColors.mint;
                  bg = AppColors.mint.withValues(alpha: .12);
                } else if (sel) {
                  b = AppColors.lavender;
                  bg = AppColors.lavender.withValues(alpha: .14);
                }
                return SizedBox(
                  width: tileW,
                  child: Material(
                    color: bg,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      onTap: matched ? null : () => notifier.selectMatchWord(row.srsItemId),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: b, width: sel || matched ? 2 : 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              row.targetWord,
                              style: _serif(context, size: 15),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'vocab.',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: cs.onSurfaceVariant,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 14),
        Divider(height: 1, color: cs.outline.withValues(alpha: .4)),
        const SizedBox(height: 12),
        ...defs.map((String d) {
          final bool isMatchedDef = vm.deck.any(
            (GameDeckItemRead r) => vm.matchedSrsIds.contains(r.srsItemId) && r.correctAnswer == d,
          );
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: cs.surface,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: isMatchedDef
                    ? null
                    : () {
                        notifier.selectMatchDefinition(d);
                      },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isMatchedDef ? AppColors.mint : cs.outline,
                      width: isMatchedDef ? 2 : 1,
                    ),
                  ),
                  child: Text(
                    d,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.3,
                      decoration: isMatchedDef ? TextDecoration.lineThrough : null,
                      color: isMatchedDef ? cs.onSurfaceVariant : cs.onSurface,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
