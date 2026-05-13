import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/current_user_provider.dart';
import '../../home/application/home_provider.dart';
import '../../vault/application/vault_provider.dart';
import '../data/game_api.dart';

enum GameSessionKind { completeSentence, matchMeanings }

enum GameLoadStatus { loading, ready, empty, error, complete }

const Object _unset = Object();

@immutable
class GameSessionVm {
  const GameSessionVm({
    required this.status,
    this.errorMessage,
    this.deck = const <GameDeckItemRead>[],
    this.currentIndex = 0,
    this.showingFeedback = false,
    this.lastSelection,
    this.lastCorrect,
    this.shuffledChoices = const <String>[],
    this.comboStreak = 0,
    this.xp = 0,
    this.lives = 3,
    this.secondsLeftCloze = 45,
    this.matchSecondsLeft = 90,
    this.matchedSrsIds = const <String>{},
    this.selectedWordSrsId,
    this.selectedDefinition,
    this.outOfLives = false,
    this.matchTimeUp = false,
  });

  final GameLoadStatus status;
  final String? errorMessage;
  final List<GameDeckItemRead> deck;
  final int currentIndex;
  final bool showingFeedback;
  final String? lastSelection;
  final bool? lastCorrect;
  final List<String> shuffledChoices;
  final int comboStreak;
  final int xp;
  final int lives;
  final int secondsLeftCloze;
  final int matchSecondsLeft;
  final Set<String> matchedSrsIds;
  final String? selectedWordSrsId;
  final String? selectedDefinition;
  final bool outOfLives;
  final bool matchTimeUp;

  GameDeckItemRead? get currentCloze =>
      deck.isEmpty || currentIndex >= deck.length ? null : deck[currentIndex];

  bool get matchRoundComplete =>
      deck.isNotEmpty && matchedSrsIds.length >= deck.length;

  GameSessionVm copyWith({
    GameLoadStatus? status,
    Object? errorMessage = _unset,
    List<GameDeckItemRead>? deck,
    int? currentIndex,
    bool? showingFeedback,
    Object? lastSelection = _unset,
    Object? lastCorrect = _unset,
    List<String>? shuffledChoices,
    int? comboStreak,
    int? xp,
    int? lives,
    int? secondsLeftCloze,
    int? matchSecondsLeft,
    Set<String>? matchedSrsIds,
    Object? selectedWordSrsId = _unset,
    Object? selectedDefinition = _unset,
    bool? outOfLives,
    bool? matchTimeUp,
    bool clearSelection = false,
  }) {
    return GameSessionVm(
      status: status ?? this.status,
      errorMessage: identical(errorMessage, _unset) ? this.errorMessage : errorMessage as String?,
      deck: deck ?? this.deck,
      currentIndex: currentIndex ?? this.currentIndex,
      showingFeedback: showingFeedback ?? this.showingFeedback,
      lastSelection: identical(lastSelection, _unset) ? this.lastSelection : lastSelection as String?,
      lastCorrect: identical(lastCorrect, _unset) ? this.lastCorrect : lastCorrect as bool?,
      shuffledChoices: shuffledChoices ?? this.shuffledChoices,
      comboStreak: comboStreak ?? this.comboStreak,
      xp: xp ?? this.xp,
      lives: lives ?? this.lives,
      secondsLeftCloze: secondsLeftCloze ?? this.secondsLeftCloze,
      matchSecondsLeft: matchSecondsLeft ?? this.matchSecondsLeft,
      matchedSrsIds: matchedSrsIds ?? this.matchedSrsIds,
      selectedWordSrsId: clearSelection
          ? null
          : (identical(selectedWordSrsId, _unset) ? this.selectedWordSrsId : selectedWordSrsId as String?),
      selectedDefinition: clearSelection
          ? null
          : (identical(selectedDefinition, _unset)
              ? this.selectedDefinition
              : selectedDefinition as String?),
      outOfLives: outOfLives ?? this.outOfLives,
      matchTimeUp: matchTimeUp ?? this.matchTimeUp,
    );
  }
}

final gameApiProvider = Provider<GameApi>((Ref ref) => GameApi());

final gameSessionProvider =
    StateNotifierProvider.autoDispose.family<GameSessionNotifier, GameSessionVm, GameSessionKind>(
  GameSessionNotifier.new,
);

class GameSessionNotifier extends StateNotifier<GameSessionVm> {
  GameSessionNotifier(this.ref, this.kind)
      : super(const GameSessionVm(status: GameLoadStatus.loading)) {
    ref.onDispose(_cancelTimer);
    Future<void>.microtask(_load);
  }

  final Ref ref;
  final GameSessionKind kind;
  Timer? _timer;
  bool _clozeTimeoutInProgress = false;

  static const int _baseXp = 10;
  static const int _clozeLimit = 8;
  static const int _matchLimit = 5;
  static const int _clozePerQuestionSeconds = 45;
  static const int _matchRoundSeconds = 90;
  static const int _matchMissPenaltySeconds = 3;

  Future<void> _load() async {
    final String? userId = ref.read(sessionUserIdProvider);
    final int carryXp = state.xp;
    final int carryCombo = state.comboStreak;
    if (userId == null) {
      state = const GameSessionVm(
        status: GameLoadStatus.error,
        errorMessage: 'No profile loaded. Register or sign in from Settings.',
      );
      return;
    }
    state = const GameSessionVm(status: GameLoadStatus.loading);
    try {
      final GameApi api = ref.read(gameApiProvider);
      final String type = kind == GameSessionKind.completeSentence ? 'cloze' : 'meaning_match';
      final int limit = kind == GameSessionKind.completeSentence ? _clozeLimit : _matchLimit;
      final List<GameDeckItemRead> deck = await api.getDeck(userId: userId, type: type, limit: limit);
      if (deck.isEmpty) {
        state = const GameSessionVm(status: GameLoadStatus.empty);
        return;
      }
      if (kind == GameSessionKind.completeSentence) {
        final List<String> shuffled = _shuffleChoices(deck.first.choices);
        state = GameSessionVm(
          status: GameLoadStatus.ready,
          deck: deck,
          shuffledChoices: shuffled,
          secondsLeftCloze: _clozePerQuestionSeconds,
        );
        _startClozeTimer();
      } else {
        state = GameSessionVm(
          status: GameLoadStatus.ready,
          deck: deck,
          matchSecondsLeft: _matchRoundSeconds,
          xp: carryXp,
          comboStreak: carryCombo,
        );
        _startMatchTimer();
      }
    } catch (e) {
      state = GameSessionVm(status: GameLoadStatus.error, errorMessage: e.toString());
    }
  }

  List<String> _shuffleChoices(List<String> choices) {
    final List<String> copy = List<String>.of(choices);
    copy.shuffle(Random());
    return copy;
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _startClozeTimer() {
    _cancelTimer();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => tickCloze());
  }

  void _startMatchTimer() {
    _cancelTimer();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => tickMatch());
  }

  void tickCloze() {
    if (state.status != GameLoadStatus.ready || kind != GameSessionKind.completeSentence) {
      return;
    }
    if (state.showingFeedback || state.outOfLives) {
      return;
    }
    if (state.secondsLeftCloze <= 1) {
      _applyClozeTimeout();
      return;
    }
    state = state.copyWith(secondsLeftCloze: state.secondsLeftCloze - 1);
  }

  void tickMatch() {
    if (state.status != GameLoadStatus.ready || kind != GameSessionKind.matchMeanings) {
      return;
    }
    if (state.matchRoundComplete || state.matchTimeUp) {
      return;
    }
    if (state.matchSecondsLeft <= 1) {
      state = state.copyWith(matchTimeUp: true);
      _cancelTimer();
      return;
    }
    state = state.copyWith(matchSecondsLeft: state.matchSecondsLeft - 1);
  }

  Future<void> _applyClozeTimeout() async {
    if (_clozeTimeoutInProgress || state.showingFeedback || state.outOfLives) {
      return;
    }
    final GameDeckItemRead? item = state.currentCloze;
    final String? userId = ref.read(sessionUserIdProvider);
    if (item == null || userId == null) {
      return;
    }
    _clozeTimeoutInProgress = true;
    _cancelTimer();
    final int nextLives = state.lives - 1;
    const int comboMult = 1;
    try {
      await ref.read(gameApiProvider).submitAnswer(
            userId: userId,
            srsItemId: item.srsItemId,
            gameType: 'cloze',
            selectedAnswer: null,
            isCorrect: false,
            comboMultiplier: comboMult,
            xpEarned: 0,
            responseTimeMs: _clozePerQuestionSeconds * 1000,
          );
      ref.invalidate(vaultItemsProvider);
      ref.invalidate(homeSummaryProvider);
      state = state.copyWith(
        showingFeedback: true,
        lastSelection: null,
        lastCorrect: false,
        lives: nextLives,
        comboStreak: 0,
        secondsLeftCloze: 0,
        outOfLives: nextLives <= 0,
      );
    } catch (e) {
      state = GameSessionVm(status: GameLoadStatus.error, errorMessage: e.toString());
    } finally {
      _clozeTimeoutInProgress = false;
    }
  }

  Future<void> selectClozeOption(String option) async {
    final GameDeckItemRead? item = state.currentCloze;
    final String? userId = ref.read(sessionUserIdProvider);
    if (item == null ||
        userId == null ||
        state.showingFeedback ||
        state.outOfLives ||
        state.status != GameLoadStatus.ready) {
      return;
    }
    final bool correct = option.toLowerCase() == item.correctAnswer.toLowerCase();
    final int elapsed = _clozePerQuestionSeconds - state.secondsLeftCloze;
    int nextStreak = state.comboStreak;
    int xpGain = 0;
    int comboMult = 1;
    if (correct) {
      nextStreak = state.comboStreak + 1;
      comboMult = nextStreak < 1 ? 1 : nextStreak;
      xpGain = _baseXp * comboMult;
    } else {
      nextStreak = 0;
    }
    await ref.read(gameApiProvider).submitAnswer(
          userId: userId,
          srsItemId: item.srsItemId,
          gameType: 'cloze',
          selectedAnswer: option,
          isCorrect: correct,
          comboMultiplier: comboMult,
          xpEarned: xpGain,
          responseTimeMs: elapsed * 1000,
        );
    ref.invalidate(vaultItemsProvider);
    ref.invalidate(homeSummaryProvider);
    final int nextLives = correct ? state.lives : state.lives - 1;
    _cancelTimer();
    state = state.copyWith(
      showingFeedback: true,
      lastSelection: option,
      lastCorrect: correct,
      comboStreak: nextStreak,
      xp: state.xp + xpGain,
      lives: nextLives,
    );
    if (!correct && nextLives <= 0) {
      state = state.copyWith(outOfLives: true);
    }
  }

  void clozeAdvance() {
    if (!state.showingFeedback) {
      return;
    }
    if (state.outOfLives) {
      return;
    }
    final bool wasLast = state.currentIndex >= state.deck.length - 1;
    if (wasLast) {
      _cancelTimer();
      state = GameSessionVm(
        status: GameLoadStatus.complete,
        xp: state.xp,
        comboStreak: state.comboStreak,
      );
      return;
    }
    final int nextIndex = state.currentIndex + 1;
    final List<String> shuffled = _shuffleChoices(state.deck[nextIndex].choices);
    state = GameSessionVm(
      status: GameLoadStatus.ready,
      deck: state.deck,
      currentIndex: nextIndex,
      shuffledChoices: shuffled,
      secondsLeftCloze: _clozePerQuestionSeconds,
      comboStreak: state.comboStreak,
      xp: state.xp,
      lives: state.lives,
    );
    _startClozeTimer();
  }

  void selectMatchWord(String srsItemId) {
    if (state.status != GameLoadStatus.ready ||
        state.matchTimeUp ||
        state.matchedSrsIds.contains(srsItemId)) {
      return;
    }
    state = state.copyWith(selectedWordSrsId: srsItemId);
  }

  Future<void> selectMatchDefinition(String definition) async {
    final String? wordId = state.selectedWordSrsId;
    final String? userId = ref.read(sessionUserIdProvider);
    if (wordId == null ||
        userId == null ||
        state.status != GameLoadStatus.ready ||
        state.matchTimeUp) {
      state = state.copyWith(clearSelection: true);
      return;
    }
    final GameDeckItemRead? row = _rowForSrs(wordId);
    if (row == null) {
      state = state.copyWith(clearSelection: true);
      return;
    }
    final bool correct = row.correctAnswer == definition;
    if (!correct) {
      final int nextT = max(0, state.matchSecondsLeft - _matchMissPenaltySeconds);
      state = state.copyWith(
        matchSecondsLeft: nextT,
        clearSelection: true,
      );
      return;
    }
    final int elapsedMs = (_matchRoundSeconds - state.matchSecondsLeft) * 1000;
    final int nextStreak = state.comboStreak + 1;
    final int comboMult = nextStreak < 1 ? 1 : nextStreak;
    final int xpGain = _baseXp * comboMult;
    await ref.read(gameApiProvider).submitAnswer(
          userId: userId,
          srsItemId: row.srsItemId,
          gameType: 'meaning_match',
          selectedAnswer: definition,
          isCorrect: true,
          comboMultiplier: comboMult,
          xpEarned: xpGain,
          responseTimeMs: elapsedMs,
        );
    ref.invalidate(vaultItemsProvider);
    ref.invalidate(homeSummaryProvider);
    final Set<String> matched = Set<String>.of(state.matchedSrsIds)..add(row.srsItemId);
    state = state.copyWith(
      matchedSrsIds: matched,
      comboStreak: nextStreak,
      xp: state.xp + xpGain,
      clearSelection: true,
    );
    if (matched.length >= state.deck.length) {
      _cancelTimer();
      Future<void>.delayed(const Duration(milliseconds: 400), _load);
    }
  }

  GameDeckItemRead? _rowForSrs(String srsItemId) {
    for (final GameDeckItemRead item in state.deck) {
      if (item.srsItemId == srsItemId) {
        return item;
      }
    }
    return null;
  }

  Future<void> retryLoad() => _load();
}
