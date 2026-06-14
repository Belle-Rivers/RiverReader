import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../../auth/application/current_user_provider.dart';
import '../../auth/data/registration_api.dart';

final backupAutoExportProvider = Provider<BackupAutoExportController>((ref) {
  final controller = BackupAutoExportController(ref);
  ref.onDispose(controller.dispose);
  return controller;
});

class BackupAutoExportController {
  BackupAutoExportController(this._ref) {
    _ref.listen<String?>(
      sessionUserIdProvider,
      (_, next) => _restart(next),
      fireImmediately: true,
    );
  }

  final Ref _ref;
  Timer? _timer;
  bool _exporting = false;

  void _restart(String? userId) {
    _timer?.cancel();
    _timer = null;
    if (userId == null) {
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(exportNow());
    });
    unawaited(exportNow());
  }

  Future<String?> exportNow() async {
    if (_exporting) {
      return null;
    }
    final String? userId = _ref.read(sessionUserIdProvider);
    if (userId == null) {
      return null;
    }
    _exporting = true;
    try {
      final RegistrationApi api = _ref.read(registrationApiProvider);
      await api.triggerBackup(userId);
      // ignore: avoid_print
      print('[RiverReader] auto-export saved to server');
      return 'server';
    } catch (err) {
      // ignore: avoid_print
      print('[RiverReader] auto-export failed: $err');
      return null;
    } finally {
      _exporting = false;
    }
  }

  Future<Map<String, dynamic>> importFromText(String contents) async {
    final RegistrationApi api = _ref.read(registrationApiProvider);
    final Map<String, dynamic> decoded = jsonDecode(contents) as Map<String, dynamic>;
    final Map<String, dynamic> response = await api.importUserData(decoded);
    final Map<String, dynamic> userJson = response['user'] as Map<String, dynamic>;
    final String userId = userJson['id'] as String;
    _ref.read(sessionUserIdProvider.notifier).setUserId(userId);
    _ref.invalidate(currentUserProfileProvider);
    return response;
  }

  void dispose() {
    _timer?.cancel();
  }
}
