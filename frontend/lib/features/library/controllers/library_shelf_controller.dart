
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/current_user_provider.dart';
import '../../home/application/home_provider.dart';
import '../data/book_api.dart';

final bookApiProvider = Provider<BookApi>((ref) => BookApi());

class LibraryShelfController extends AsyncNotifier<List<BookApiModel>> {
  @override
  Future<List<BookApiModel>> build() async {
    final userId = ref.watch(sessionUserIdProvider);
    if (userId == null) return [];
    
    final api = ref.read(bookApiProvider);
    return api.listBooks(userId);
  }

  Future<void> uploadBook(String filePath, String fileName, List<int> fileBytes) async {
    final userId = ref.read(sessionUserIdProvider);
    if (userId == null) return;

    final api = ref.read(bookApiProvider);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await api.uploadBook(userId, filePath, fileName, fileBytes);
      ref.invalidate(homeSummaryProvider);
      return api.listBooks(userId);
    });
  }

  Future<void> deleteBook(String bookId) async {
    final userId = ref.read(sessionUserIdProvider);
    if (userId == null) return;

    final api = ref.read(bookApiProvider);
    final previousState = state;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await api.deleteBook(userId, bookId);
      ref.invalidate(homeSummaryProvider);
      return api.listBooks(userId);
    });
    
    if (state.hasError) {
      state = previousState;
    }
  }
}

final libraryShelfControllerProvider =
    AsyncNotifierProvider<LibraryShelfController, List<BookApiModel>>(() {
  return LibraryShelfController();
});

