import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/application/current_user_provider.dart';
import '../../features/auth/data/registration_api.dart';

const _backupKey = 'auto_backup_v1';

/// Periodically saves a user-data export to localStorage so that if the
/// backend database is wiped (e.g. Render free-tier restarts) the frontend
/// can auto-restore the user's profile, books, highlights and progress.
class AutoBackupNotifier extends AutoDisposeNotifier<void> {
  Timer? _timer;

  @override
  void build() {
    ref.listen<String?>(sessionUserIdProvider, (prev, next) {
      _timer?.cancel();
      if (next != null) {
        _snapshotBackup(next);
        _timer = Timer.periodic(const Duration(seconds: 30), (_) {
          final userId = ref.read(sessionUserIdProvider);
          if (userId != null) _snapshotBackup(userId);
        });
      }
    });

    ref.onDispose(() => _timer?.cancel());
  }

  Future<void> _snapshotBackup(String userId) async {
    try {
      final Map<String, dynamic> data =
          await RegistrationApi().exportUserData(userId);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_backupKey, jsonEncode(data));
    } catch (_) {
      // Backup failures are non-fatal.
    }
  }
}

final autoBackupProvider = NotifierProvider.autoDispose<AutoBackupNotifier, void>(
  AutoBackupNotifier.new,
);

/// Returns the stored backup JSON string, or null if none exists.
Future<Map<String, dynamic>?> loadBackupFromStorage() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_backupKey);
  if (raw == null) return null;
  try {
    return jsonDecode(raw) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
}

/// Persists a backup map to localStorage.
Future<void> saveBackupToStorage(Map<String, dynamic> data) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_backupKey, jsonEncode(data));
}
