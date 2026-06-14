import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/registration_api.dart';

const _sessionUserKey = 'session_user_id';

/// Active profile id for this session. Restored from localStorage on startup.
final sessionUserIdProvider = NotifierProvider<SessionUserIdNotifier, String?>(
  SessionUserIdNotifier.new,
);

class SessionUserIdNotifier extends Notifier<String?> {
  SessionUserIdNotifier({String? initialUserId}) : _initialUserId = initialUserId;
  final String? _initialUserId;

  @override
  String? build() => _initialUserId;

  void setUserId(String id) {
    state = id;
    SharedPreferences.getInstance()
        .then((prefs) => prefs.setString(_sessionUserKey, id));
  }

  void clearUserId() {
    state = null;
    SharedPreferences.getInstance()
        .then((prefs) => prefs.remove(_sessionUserKey));
  }
}

final currentUserProfileProvider = FutureProvider<RegistrationResponse?>((ref) async {
  final userId = ref.watch(sessionUserIdProvider);
  if (userId == null) return null;
  final api = RegistrationApi();
  return api.getUserProfile(userId);
});
