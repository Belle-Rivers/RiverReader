import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:river_reader_backend/river_reader_backend.dart';

import '../../../core/storage/epub_browser_store.dart';
import '../../games/application/game_session_controller.dart';
import '../../library/data/book_api.dart';
import '../../settings/application/backup_autosave_provider.dart';
import '../data/registration_api.dart';
import 'auth_providers.dart';
import 'current_user_provider.dart';

final sessionRestoreServiceProvider = Provider<SessionRestoreService>((ref) {
  return SessionRestoreService(ref);
});

class SessionRestoreService {
  SessionRestoreService(this._ref);

  final Ref _ref;

  Future<void> restoreIfNeeded() async {
    final String? userId = _ref.read(sessionUserIdProvider);
    if (userId == null) {
      return;
    }

    final RegistrationApi api = _ref.read(registrationApiProvider);
    await api.waitForBackend();

    try {
      await api.getUserProfile(userId);
      await _syncMissingEpubs(userId);
      return;
    } on RegistrationApiNotFoundException {
      await _restoreFromLocalBackup(userId);
    }
  }

  Future<void> _restoreFromLocalBackup(String userId) async {
    final String contents = await FileStorageManager.readTextFile('_user_$userId');
    if (contents.trim().isEmpty) {
      _ref.read(sessionUserIdProvider.notifier).clearUserId();
      return;
    }

    await _ref.read(backupAutoExportProvider).importFromText(contents);
    await _syncMissingEpubs(userId);
    _ref.read(gameApiProvider).triggerBackfill(userId);
  }

  Future<void> _syncMissingEpubs(String userId) async {
    final BookApi bookApi = BookApi();
    final List<BookApiModel> books = await bookApi.listBooks(userId);
    for (final BookApiModel book in books) {
      final bool hasFile = await bookApi.bookFileExists(userId: userId, bookId: book.id);
      if (hasFile) {
        continue;
      }
      final StoredEpub? epub = await EpubBrowserStore.read(book.id);
      if (epub == null) {
        continue;
      }
      await bookApi.restoreBookFile(
        userId: userId,
        bookId: book.id,
        fileName: epub.fileName,
        fileBytes: epub.bytes,
      );
    }
  }
}
