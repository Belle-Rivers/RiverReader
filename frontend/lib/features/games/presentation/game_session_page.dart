import 'dart:math';

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
  bool get _isMatch => widget.kind == GameSessionKind.matchMeanings;
  bool get _isGeneric =>
      widget.kind == GameSessionKind.contextClash ||
      widget.kind == GameSessionKind.oddOneOut ||
      widget.kind == GameSessionKind.trueOrBluff;

  String get _title {
    switch (widget.kind) {
      case GameSessionKind.completeSentence:
        return 'Complete the sentence';
      case GameSessionKind.matchMeanings:
        return 'Match meanings';
      case GameSessionKind.contextClash:
        return 'Context Clash';
      case GameSessionKind.oddOneOut:
        return 'Odd One Out';
      case GameSessionKind.trueOrBluff:
        return 'True or Bluff';
    }
  }

  @override
  Widget build(BuildContext context) {
    final GameSessionVm vm = ref.watch(gameSessionProvider(widget.kind));
    final GameSessionNotifier notifier = ref.read(gameSessionProvider(widget.kind).notifier);
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    return RiverScaffold(
      title: _title,
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
        return const Center(
          child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()),
        );
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
                FilledButton(
                  onPressed: () => context.go('/games'),
                  child: const Text('Back to games'),
                ),
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
    final double progress;
    if (_isMatch) {
      progress = (vm.matchedSrsIds.isEmpty ? 0.03 : vm.matchedSrsIds.length / (total == 0 ? 1 : total))
          .clamp(0.0, 1.0);
    } else {
      progress = ((vm.currentIndex + (vm.showingFeedback ? 1 : 0.5)) / (total == 0 ? 1 : total))
          .clamp(0.0, 1.0);
    }
    final int comboShow = vm.comboStreak == 0 ? 0 : vm.comboStreak;

    // Timer display for generic games
    final int timerSeconds = _isGeneric ? vm.secondsLeftGeneric : 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        // Top stat row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _statPill(context, Icons.local_fire_department_outlined, 'x$comboShow'),
            if (_isSentence)
              _hearts(vm.lives)
            else if (_isMatch)
              _statPill(context, Icons.timer_outlined, '${vm.matchSecondsLeft}s')
            else ...[
              _hearts(vm.lives),
              _statPill(context, Icons.timer_outlined, '${timerSeconds}s'),
            ],
            _statPill(context, Icons.auto_awesome_outlined, '${vm.xp}'),
          ],
        ),
        const SizedBox(height: 10),
        // Round info row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _isMatch
                  ? 'PAIRS ${vm.matchedSrsIds.length} / $total'
                  : 'ROUND ${vm.currentIndex + 1} / $total',
              style: theme.textTheme.labelMedium?.copyWith(
                color: cs.onSurfaceVariant,
                letterSpacing: 0.6,
              ),
            ),
            if (_isSentence)
              Text('${vm.secondsLeftCloze}s',
                  style: theme.textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant))
            else if (_isGeneric)
              Text('${timerSeconds}s',
                  style: theme.textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant))
            else
              Text('${(progress * 100).round()}%',
                  style: theme.textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
          ],
        ),
        const SizedBox(height: 6),
        // Progress bar
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
        // Time's up overlay for match
        if (vm.matchTimeUp)
          RiverCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text("Time's up", style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text('Your combo and XP are saved for the next round.',
                    style: theme.textTheme.bodySmall),
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
        else if (_isMatch)
          _matchSection(context, theme, cs, vm, notifier)
        else if (widget.kind == GameSessionKind.contextClash)
          _contextClashSection(context, theme, cs, vm, notifier)
        else if (widget.kind == GameSessionKind.oddOneOut)
          _oddOneOutSection(context, theme, cs, vm, notifier)
        else if (widget.kind == GameSessionKind.trueOrBluff)
          _trueOrBluffSection(context, theme, cs, vm, notifier),
      ],
    );
  }

  // ─── Stat pills & hearts ───────────────────────────────────────────────────

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

  // ─── Cloze section ─────────────────────────────────────────────────────────

  Widget _clozeSection(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
    GameSessionVm vm,
    GameSessionNotifier notifier,
  ) {
    final GameDeckItemRead? item = vm.currentCloze;
    if (item == null) return const SizedBox.shrink();
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
              Text(fromLine,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w600,
                  )),
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
                  child: _clozeChoiceTile(context, option, vm, notifier, width: w),
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
            border: Border.all(
              color: border,
              width: chosen || (vm.showingFeedback && correct) ? 2 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(option, textAlign: TextAlign.center, style: _serif(context, size: 15, weight: FontWeight.w600)),
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
    if (item == null) return const SizedBox.shrink();
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

  // ─── Match section ─────────────────────────────────────────────────────────

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
                            Text(row.targetWord, style: _serif(context, size: 15)),
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
                onTap: isMatchedDef ? null : () => notifier.selectMatchDefinition(d),
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

  // ─── Context Clash section ─────────────────────────────────────────────────

  Widget _contextClashSection(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
    GameSessionVm vm,
    GameSessionNotifier notifier,
  ) {
    final GameDeckItemRead? item = vm.currentCloze;
    if (item == null) return const SizedBox.shrink();

    final String sentenceA = item.correctSentence ?? '';
    final String sentenceB = item.clashSentence ?? '';
    // Randomly decide which slot is A and which is B (determined by item index for consistency)
    final bool swapOrder = item.targetWord.hashCode.isEven;
    final String topSentence = swapOrder ? sentenceB : sentenceA;
    final String bottomSentence = swapOrder ? sentenceA : sentenceB;
    final String topLabel = swapOrder ? item.clashSentence ?? '' : item.correctSentence ?? '';
    final String bottomLabel = swapOrder ? item.correctSentence ?? '' : item.clashSentence ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RiverCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tap the sentence that makes logical sense:',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _clashSentenceTile(
          context,
          theme,
          cs,
          'A',
          topSentence,
          vm,
          notifier,
          isCorrectChoice: topLabel == item.correctSentence,
        ),
        const SizedBox(height: 10),
        _clashSentenceTile(
          context,
          theme,
          cs,
          'B',
          bottomSentence,
          vm,
          notifier,
          isCorrectChoice: bottomLabel == item.correctSentence,
        ),
        if (vm.showingFeedback) ...[
          const SizedBox(height: 14),
          _clashFeedback(context, theme, cs, vm, notifier),
        ],
      ],
    );
  }

  Widget _clashSentenceTile(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
    String label,
    String sentence,
    GameSessionVm vm,
    GameSessionNotifier notifier, {
    required bool isCorrectChoice,
  }) {
    final bool chosen = vm.lastSelection == label;
    Color border = cs.outline;
    Color fill = cs.surface;
    if (vm.showingFeedback) {
      if (isCorrectChoice) {
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
        onTap: vm.showingFeedback || vm.outOfLives
            ? null
            : () => notifier.selectGenericAnswer(label),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: border,
              width: chosen || (vm.showingFeedback && isCorrectChoice) ? 2 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(label, style: _sansUi(context, size: 14, weight: FontWeight.w700)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(sentence, style: _serif(context, size: 15)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _clashFeedback(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
    GameSessionVm vm,
    GameSessionNotifier notifier,
  ) {
    final GameDeckItemRead? item = vm.currentCloze;
    if (item == null) return const SizedBox.shrink();
    final bool? ok = vm.lastCorrect;
    final String headline = ok == true ? 'Correct!' : ok == false ? 'Not quite.' : "Time's up.";
    final String explanation = item.explanation ?? '';
    final String correctSentence = item.correctSentence ?? '';
    final String clashSentence = item.clashSentence ?? '';
    return RiverCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(headline, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          // Show the correct sentence with green check
          if (correctSentence.isNotEmpty) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.mint),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    correctSentence,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.35,
                      color: AppColors.mint.withValues(alpha: .9),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          // Show the clash sentence with red X
          if (clashSentence.isNotEmpty) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.cancel_rounded, size: 18, color: cs.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    clashSentence,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.35,
                      color: cs.error.withValues(alpha: .8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          // Show the explanation
          if (explanation.isNotEmpty) ...[
            Text(explanation, style: theme.textTheme.bodyMedium?.copyWith(height: 1.35)),
          ],
          const SizedBox(height: 14),
          FilledButton(
            onPressed: vm.outOfLives ? () => context.go('/games') : () => notifier.genericAdvance(),
            child: Text(vm.outOfLives ? 'Done' : 'Next →'),
          ),
        ],
      ),
    );
  }

  // ─── Odd One Out section ───────────────────────────────────────────────────

  Widget _oddOneOutSection(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
    GameSessionVm vm,
    GameSessionNotifier notifier,
  ) {
    final GameDeckItemRead? item = vm.currentCloze;
    if (item == null) return const SizedBox.shrink();

    // Combine synonyms + misfit into 4 shuffled tiles
    final List<String> allWords = [...item.synonyms, item.misfitWord ?? ''];
    allWords.shuffle(Random(item.highlightId.hashCode));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RiverCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Which word does NOT belong with the others?',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (item.targetWord.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Target: ${item.targetWord}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: cs.primary,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints c) {
            final double tileW = (c.maxWidth - 10) / 2;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: allWords.map((String word) {
                final bool isMisfit = word == item.misfitWord;
                final bool chosen = vm.lastSelection == word;
                Color border = cs.outline;
                Color fill = cs.surface;
                if (vm.showingFeedback) {
                  if (isMisfit) {
                    border = AppColors.mint;
                    fill = AppColors.mint.withValues(alpha: .16);
                  } else if (chosen) {
                    border = cs.error;
                    fill = cs.error.withValues(alpha: .12);
                  }
                }
                return SizedBox(
                  width: tileW,
                  child: Material(
                    color: fill,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      onTap: vm.showingFeedback || vm.outOfLives
                          ? null
                          : () => notifier.selectGenericAnswer(word),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: border,
                            width: chosen || (vm.showingFeedback && isMisfit) ? 2 : 1,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          word,
                          style: _serif(context, size: 16),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
        if (vm.showingFeedback) ...[
          const SizedBox(height: 14),
          _oddOneOutFeedback(context, theme, cs, vm, notifier),
        ],
      ],
    );
  }

  Widget _oddOneOutFeedback(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
    GameSessionVm vm,
    GameSessionNotifier notifier,
  ) {
    final GameDeckItemRead? item = vm.currentCloze;
    if (item == null) return const SizedBox.shrink();
    final bool? ok = vm.lastCorrect;
    final String headline = ok == true
        ? 'Exactly right!'
        : ok == false
            ? 'Not quite.'
            : "Time's up.";
    final String? selected = vm.lastSelection;
    final String? targetDef = item.definition;
    String body;
    if (ok == true) {
      body = targetDef != null ? '${item.targetWord} — $targetDef' : item.targetWord;
    } else if (ok == false && selected != null) {
      final String? selectedDef = item.choiceDefinitions[selected];
      if (selectedDef != null) {
        body =
            '"$selected" means $selectedDef. It belongs with the others — the odd word was "${item.misfitWord}".';
      } else {
        body =
            '"$selected" is related to "${item.targetWord}". The odd word was "${item.misfitWord}".';
      }
    } else {
      body = targetDef != null
          ? 'The odd word was "${item.misfitWord}" — ${item.targetWord}: $targetDef'
          : 'The odd word was "${item.misfitWord}".';
    }
    return RiverCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(headline, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(body, style: theme.textTheme.bodyMedium?.copyWith(height: 1.35)),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: vm.outOfLives ? () => context.go('/games') : () => notifier.genericAdvance(),
            child: Text(vm.outOfLives ? 'Done' : 'Next →'),
          ),
        ],
      ),
    );
  }

  // ─── True or Bluff section ─────────────────────────────────────────────────

  Widget _trueOrBluffSection(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
    GameSessionVm vm,
    GameSessionNotifier notifier,
  ) {
    final GameDeckItemRead? item = vm.currentCloze;
    if (item == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RiverCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Is this statement true or bluff?',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                item.statement ?? '',
                style: _serif(context, size: 18),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _trueBluffButton(
                context,
                theme,
                cs,
                'TRUE',
                AppColors.mint,
                vm,
                notifier,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _trueBluffButton(
                context,
                theme,
                cs,
                'BLUFF',
                AppColors.lavender,
                vm,
                notifier,
              ),
            ),
          ],
        ),
        if (vm.showingFeedback) ...[
          const SizedBox(height: 14),
          _trueBluffFeedback(context, theme, cs, vm, notifier),
        ],
      ],
    );
  }

  Widget _trueBluffButton(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
    String label,
    Color color,
    GameSessionVm vm,
    GameSessionNotifier notifier,
  ) {
    final bool chosen = vm.lastSelection == label;
    final bool isCorrectAnswer = label.toLowerCase() == (vm.currentCloze?.correctAnswer ?? '').toLowerCase();
    Color border = cs.outline;
    Color fill = cs.surface;
    if (vm.showingFeedback) {
      if (isCorrectAnswer) {
        border = AppColors.mint;
        fill = AppColors.mint.withValues(alpha: .16);
      } else if (chosen) {
        border = cs.error;
        fill = cs.error.withValues(alpha: .12);
      }
    }
    return Material(
      color: fill,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: vm.showingFeedback || vm.outOfLives
            ? null
            : () => notifier.selectGenericAnswer(label),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: border,
              width: chosen || (vm.showingFeedback && isCorrectAnswer) ? 2.5 : 1.5,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: _serif(context, size: 20, weight: FontWeight.w700).copyWith(color: color),
          ),
        ),
      ),
    );
  }

  Widget _trueBluffFeedback(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
    GameSessionVm vm,
    GameSessionNotifier notifier,
  ) {
    final GameDeckItemRead? item = vm.currentCloze;
    if (item == null) return const SizedBox.shrink();
    final bool? ok = vm.lastCorrect;
    final String headline = ok == true
        ? 'Correct!'
        : ok == false
            ? 'Not quite.'
            : "Time's up.";
    final String statement = item.statement ?? '';
    final bool correctIsTrue = item.isTrue == true;
    final String correctLabel = correctIsTrue ? 'TRUE' : 'BLUFF';
    String body;
    if (ok == true) {
      body = 'Right — that statement is $correctLabel.';
    } else if (statement.isNotEmpty) {
      body = 'The statement is $correctLabel.';
      if (item.definition != null) {
        body += ' ${item.targetWord} — ${item.definition}';
      }
    } else if (item.definition != null) {
      body = '${item.targetWord} — ${item.definition}';
    } else {
      body = item.targetWord;
    }
    return RiverCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(headline, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (statement.isNotEmpty && ok != true) ...[
            Text(
              '"$statement"',
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.35,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Text(body, style: theme.textTheme.bodyMedium?.copyWith(height: 1.35)),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: vm.outOfLives ? () => context.go('/games') : () => notifier.genericAdvance(),
            child: Text(vm.outOfLives ? 'Done' : 'Next →'),
          ),
        ],
      ),
    );
  }
}
