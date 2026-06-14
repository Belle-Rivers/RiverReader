import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:river_reader_backend/river_reader_backend.dart';

import '../../../core/storage/browser_download.dart';
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
    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
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
      final Map<String, dynamic> payload = await api.exportUserData(userId);
      final String fileName = await _backupFileName(userId);
      final String encoded = jsonEncode(payload);
      await FileStorageManager.writeTextFile(fileName, encoded);
      await FileStorageManager.writeTextFile('_user_$userId', encoded);
      // ignore: avoid_print
      print('[RiverReader] auto-export saved to $fileName');
      return fileName;
    } catch (err) {
      // ignore: avoid_print
      print('[RiverReader] auto-export failed: $err');
      return null;
    } finally {
      _exporting = false;
    }
  }

  Future<String?> exportAndDownload() async {
    final String? userId = _ref.read(sessionUserIdProvider);
    if (userId == null) {
      return null;
    }
    final RegistrationApi api = _ref.read(registrationApiProvider);
    final Map<String, dynamic> payload = await api.exportUserData(userId);
    final String fileName = await _backupFileName(userId);
    final String encoded = jsonEncode(payload);
    await FileStorageManager.writeTextFile(fileName, encoded);
    await FileStorageManager.writeTextFile('_user_$userId', encoded);
    await BrowserDownload.downloadText('$fileName.json', encoded);
    return fileName;
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

  Future<String> _backupFileName(String userId) async {
    final profile = await _ref.read(currentUserProfileProvider.future);
    final String? email = profile?.email.trim();
    final String? emailBase = email != null && email.contains('@') ? email.split('@').first.trim() : null;
    final String? displayBase = profile?.displayName?.trim();
    final String base = _sanitize(
      (emailBase != null && emailBase.isNotEmpty)
          ? emailBase
          : (displayBase != null && displayBase.isNotEmpty ? displayBase : userId),
    );
    return 'RiverReader_$base';
  }

  String _sanitize(String value) {
    final String cleaned = value.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
    return cleaned.isEmpty ? 'backup' : cleaned;
  }

  void dispose() {
    _timer?.cancel();
  }
}
