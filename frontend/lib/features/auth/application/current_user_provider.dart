import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/registration_api.dart';
import 'session_store.dart';

/// In-memory active profile id, persisted across app restarts via [SessionStore].
final sessionUserIdProvider = NotifierProvider<SessionUserIdNotifier, String?>(
  SessionUserIdNotifier.new,
);

class SessionUserIdNotifier extends Notifier<String?> {
  SessionUserIdNotifier({this.initialUserId});

  final String? initialUserId;

  @override
  String? build() => initialUserId;

  void setUserId(String id) {
    state = id;
    unawaited(SessionStore.saveUserId(id));
  }

  void clearUserId() {
    state = null;
    unawaited(SessionStore.clearUserId());
  }
}

final currentUserProfileProvider = FutureProvider<RegistrationResponse?>((ref) async {
  final userId = ref.watch(sessionUserIdProvider);
  if (userId == null) return null;
  final api = RegistrationApi();
  try {
    return await api.getUserProfile(userId);
  } on RegistrationApiNotFoundException {
    return null;
  }
});
