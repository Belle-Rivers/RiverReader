import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/current_user_provider.dart';
import '../data/game_api.dart';
import 'game_session_controller.dart';

/// All game decks fetched in a single API call and shared across sessions.
final gameDecksProvider = AsyncNotifierProvider<GameDecksNotifier, GameDecksBundle>(
  GameDecksNotifier.new,
);

class GameDecksNotifier extends AsyncNotifier<GameDecksBundle> {
  static const int _defaultLimit = 8;

  @override
  Future<GameDecksBundle> build() async {
    final String? userId = ref.watch(sessionUserIdProvider);
    if (userId == null) {
      return const GameDecksBundle();
    }
    return ref.read(gameApiProvider).getAllDecks(userId: userId, limit: _defaultLimit);
  }

  Future<void> refreshDecks({bool replayRefresh = false}) async {
    final String? userId = ref.read(sessionUserIdProvider);
    if (userId == null) {
      state = const AsyncData(GameDecksBundle());
      return;
    }
    state = const AsyncLoading<GameDecksBundle>();
    state = await AsyncValue.guard(
      () => ref.read(gameApiProvider).getAllDecks(
            userId: userId,
            limit: _defaultLimit,
            replayRefresh: replayRefresh,
          ),
    );
  }
}

void invalidateGameDecks(WidgetRef ref) {
  ref.invalidate(gameDecksProvider);
}

void invalidateGameDecksFromRef(Ref ref) {
  ref.invalidate(gameDecksProvider);
}

List<GameDeckItemRead> deckForKind(GameDecksBundle bundle, GameSessionKind kind) {
  switch (kind) {
    case GameSessionKind.completeSentence:
      return bundle.cloze;
    case GameSessionKind.matchMeanings:
      return bundle.meaningMatch;
    case GameSessionKind.contextClash:
      return bundle.contextClash;
    case GameSessionKind.oddOneOut:
      return bundle.oddOneOut;
    case GameSessionKind.trueOrBluff:
      return bundle.trueOrBluff;
  }
}
