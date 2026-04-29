import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:river_reader_backend/river_reader_backend.dart';

class LibraryShelfController extends AsyncNotifier<List<Book>> {
  @override
  Future<List<Book>> build() async {
    final BookRepository repository = ref.read(bookRepositoryProvider);
    return repository.getAllBooks();
  }

  Future<void> addDemoBook() async {
    final AsyncValue<List<Book>> previousValue = state;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard<List<Book>>(() async {
      final BookRepository repository = ref.read(bookRepositoryProvider);
      await repository.insertBook(
        Book(
          title: 'Demo Book',
          author: 'River Reader',
          coverPath: null,
          epubPath: '/demo.epub',
        ),
      );
      return repository.getAllBooks();
    });
    if (state.hasError) {
      state = previousValue;
    }
  }

  Future<void> deleteBook(int bookId) async {
    final AsyncValue<List<Book>> previousValue = state;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard<List<Book>>(() async {
      final BookRepository repository = ref.read(bookRepositoryProvider);
      await repository.deleteBook(bookId);
      return repository.getAllBooks();
    });
    if (state.hasError) {
      state = previousValue;
    }
  }
}

final libraryShelfControllerProvider =
    AsyncNotifierProvider<LibraryShelfController, List<Book>>(() {
  return LibraryShelfController();
});

