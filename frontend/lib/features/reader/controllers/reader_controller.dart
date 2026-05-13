import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/current_user_provider.dart';
import '../../library/data/book_api.dart';

final readerControllerProvider =
    AsyncNotifierProviderFamily<ReaderController, ReadingProgressModel?, String>(
  ReaderController.new,
);

class ReaderController extends FamilyAsyncNotifier<ReadingProgressModel?, String> {
  late String _bookId;

  @override
  Future<ReadingProgressModel?> build(String bookId) async {
    _bookId = bookId;
    final userId = ref.watch(sessionUserIdProvider);
    if (userId == null) return null;

    final api = BookApi();
    return api.getReadingProgress(userId: userId, bookId: bookId);
  }

  Future<void> saveProgress({
    String? cfi,
    int? chapterIndex,
    String? chapterTitle,
    double? progressPercent,
  }) async {
    final userId = ref.read(sessionUserIdProvider);
    if (userId == null) return;

    final newProgress = ReadingProgressModel(
      bookId: _bookId,
      cfi: cfi ?? state.valueOrNull?.cfi,
      chapterIndex: chapterIndex ?? state.valueOrNull?.chapterIndex,
      chapterTitle: chapterTitle ?? state.valueOrNull?.chapterTitle,
      progressPercent: progressPercent ?? state.valueOrNull?.progressPercent,
    );

    // Optimistic update
    state = AsyncValue.data(newProgress);

    final api = BookApi();
    try {
      await api.saveReadingProgress(
        userId: userId,
        bookId: _bookId,
        progress: newProgress,
      );
    } catch (e) {
      // Fire-and-forget: progress save failures are non-fatal.
    }
  }
}
