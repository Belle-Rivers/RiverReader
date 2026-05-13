import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/river_ui.dart';

enum GameSessionType { completeSentence, matchMeanings }

class GameSessionPage extends StatefulWidget {
  const GameSessionPage({super.key, required this.type});

  final GameSessionType type;

  @override
  State<GameSessionPage> createState() => _GameSessionPageState();
}

class _GameSessionPageState extends State<GameSessionPage> {
  String? _selectedWord;
  String? _selectedDefinition;
  bool _showResult = false;

  bool get _isSentence => widget.type == GameSessionType.completeSentence;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return RiverScaffold(
      title: _isSentence ? 'Complete the sentence' : 'Match meanings',
      tab: RiverTab.game,
      onBack: () => context.go('/games'),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _chip(context, _isSentence ? 'x0' : 'combo x3', Icons.local_fire_department_outlined),
              if (_isSentence)
                const Row(
                  children: [
                    Icon(Icons.favorite, color: Color(0xFFFF585D)),
                    SizedBox(width: 4),
                    Icon(Icons.favorite, color: Color(0xFFFF585D)),
                    SizedBox(width: 4),
                    Icon(Icons.favorite_border, color: Color(0xFF9EA5C0)),
                  ],
                )
              else
                _chip(context, '33s', Icons.timer_outlined),
              _chip(context, _isSentence ? '0' : '110', Icons.auto_awesome_outlined),
            ],
          ),
          const SizedBox(height: 14),
          Text(_isSentence ? 'ROUND 1 / 6' : 'PAIRS 4 / 5', style: theme.textTheme.bodyLarge?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _isSentence ? .07 : .8,
              minHeight: 10,
              backgroundColor: cs.outline.withValues(alpha: .4),
              color: AppColors.mint,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(_isSentence ? '1S' : '80%', style: theme.textTheme.bodyLarge?.copyWith(color: cs.onSurfaceVariant)),
          ),
          const SizedBox(height: 18),
          if (_isSentence) ...[
            RiverCard(
              padding: const EdgeInsets.all(26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('FROM "THE GREAT GATSBY"', style: theme.textTheme.bodyLarge?.copyWith(color: cs.onSurfaceVariant)),
                  const SizedBox(height: 18),
                  Text(
                    'The ____ future that year by year recedes before us.',
                    style: theme.textTheme.headlineMedium?.copyWith(fontSize: 28, height: 1.45),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: _sentenceOptions.map((option) => _answerTile(context, option, _selectedWord, () {
                    setState(() {
                      _selectedWord = option;
                      _showResult = true;
                    });
                  })).toList(),
            ),
            if (_showResult) ...[
              const SizedBox(height: 18),
              RiverCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedWord == 'orgastic' ? 'Exactly right.' : 'Not quite.',
                      style: theme.textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'orgastic (adj.) - Of or relating to ecstatic, exuberant joy.',
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _selectedWord = null;
                          _showResult = false;
                        });
                      },
                      child: const Text('Next'),
                    ),
                  ],
                ),
              ),
            ],
          ] else ...[
            Text(
              'Tap a word, then its meaning. Misses cost 3 seconds.',
              style: theme.textTheme.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: _matchWords.map((word) => _wordCard(context, word)).toList(),
            ),
            const SizedBox(height: 18),
            Divider(color: cs.outline),
            const SizedBox(height: 18),
            ..._definitions.map((definition) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () => setState(() => _selectedDefinition = definition),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
                      decoration: BoxDecoration(
                        color: _selectedDefinition == definition ? AppColors.mint.withValues(alpha: .18) : theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _selectedDefinition == definition ? AppColors.mint : cs.outline,
                          width: 1.4,
                        ),
                      ),
                      child: Text(definition, style: theme.textTheme.bodyLarge),
                    ),
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String text, IconData icon) {
    return RiverCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(text, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }

  Widget _answerTile(BuildContext context, String option, String? selected, VoidCallback onTap) {
    final theme = Theme.of(context);
    final active = option == selected;
    Color border = theme.colorScheme.outline;
    Color fill = theme.colorScheme.surface;
    if (active && option == 'orgastic') {
      border = AppColors.mint;
      fill = AppColors.mint.withValues(alpha: .2);
    } else if (active) {
      border = const Color(0xFFFF6B6B);
      fill = const Color(0xFFFF6B6B).withValues(alpha: .15);
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 320,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: border, width: active ? 2.2 : 1.4),
        ),
        child: Center(
          child: Text(option, style: theme.textTheme.headlineMedium?.copyWith(fontSize: 24)),
        ),
      ),
    );
  }

  Widget _wordCard(BuildContext context, String word) {
    final theme = Theme.of(context);
    final selected = _selectedWord == word;
    return InkWell(
      onTap: () => setState(() => _selectedWord = word),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 328,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: selected ? AppColors.mint.withValues(alpha: .15) : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? AppColors.mint : theme.colorScheme.outline,
            width: selected ? 2.2 : 1.4,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(word, style: theme.textTheme.headlineMedium?.copyWith(fontSize: 24)),
            const SizedBox(height: 8),
            Text('adj.', style: theme.textTheme.bodyLarge?.copyWith(fontStyle: FontStyle.italic)),
          ],
        ),
      ),
    );
  }
}

const _sentenceOptions = ['ineffable', 'orgastic', 'epicene', 'sepulchral'];

const _matchWords = ['orgastic', 'perambulate', 'sepulchral', 'indefatigable', 'saturnine'];

const _definitions = [
  'Persisting tirelessly.',
  'Gloomy, dismal; reminiscent of a tomb.',
  'Walk or travel through or around a place.',
  'Of or relating to ecstatic, exuberant joy.',
  'Slow and gloomy; of a dark complexion.',
];
