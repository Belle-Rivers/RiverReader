import 'package:flutter_riverpod/flutter_riverpod.dart';

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
