import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/current_user_provider.dart';
import '../data/game_api.dart';
import 'game_decks_provider.dart';
import 'game_session_controller.dart';

/// Keeps AI game content generation running in the background while the user
/// is signed in — on login, after new highlights, and on a periodic poll.
final gameBackfillWorkerProvider = Provider<void>((Ref ref) {
  final String? userId = ref.watch(sessionUserIdProvider);
  if (userId == null) {
    return;
  }

  final GameApi api = ref.read(gameApiProvider);
  unawaited(api.triggerBackfill(userId));

  final Timer timer = Timer.periodic(const Duration(seconds: 30), (_) {
    unawaited(api.triggerBackfill(userId));
    invalidateGameDecksFromRef(ref);
  });

  ref.onDispose(timer.cancel);
});

void triggerGameBackfill(Ref ref) {
  final String? userId = ref.read(sessionUserIdProvider);
  if (userId == null) {
    return;
  }
  unawaited(ref.read(gameApiProvider).triggerBackfill(userId));
}
