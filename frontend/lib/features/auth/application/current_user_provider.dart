import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/registration_api.dart';

/// In-memory active profile id for this app session (cleared when the app restarts).
final sessionUserIdProvider = NotifierProvider<SessionUserIdNotifier, String?>(
  SessionUserIdNotifier.new,
);

class SessionUserIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setUserId(String id) {
    state = id;
  }

  void clearUserId() {
    state = null;
  }
}

final currentUserProfileProvider = FutureProvider<RegistrationResponse?>((ref) async {
  final userId = ref.watch(sessionUserIdProvider);
  if (userId == null) return null;
  final api = RegistrationApi();
  return api.getUserProfile(userId);
});
