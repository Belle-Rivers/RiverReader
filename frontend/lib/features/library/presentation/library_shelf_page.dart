import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:river_reader_backend/river_reader_backend.dart';

import '../../../core/widgets/theme_mode_menu_button.dart';
import '../controllers/library_shelf_controller.dart';

class LibraryShelfPage extends ConsumerWidget {
  const LibraryShelfPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Book>> booksValue =
        ref.watch(libraryShelfControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Library Shelf'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Add demo book',
            onPressed: () =>
                ref.read(libraryShelfControllerProvider.notifier).addDemoBook(),
            icon: const Icon(Icons.add),
          ),
          const ThemeModeMenuButton(),
        ],
      ),
      body: booksValue.when(
        data: (List<Book> books) {
          if (books.isEmpty) {
            return const Center(
              child: Text(
                'Hey Ms.Yağmur, this is a test ;)',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            );
          }
          return ListView.separated(
            itemCount: books.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (BuildContext context, int index) {
              final Book book = books[index];
              return ListTile(
                title: Text(book.title),
                subtitle: Text(book.author ?? 'Unknown author'),
                trailing: IconButton(
                  tooltip: 'Delete',
                  onPressed: book.id == null
                      ? null
                      : () => ref
                          .read(libraryShelfControllerProvider.notifier)
                          .deleteBook(book.id!),
                  icon: const Icon(Icons.delete_outline),
                ),
              );
            },
          );
        },
        error: (Object error, StackTrace stackTrace) {
          ErrorLogger.logError(
              'Hello Ms.Yağmur! Thank you for everything ;)', error, stackTrace);
          return const Center(
              child: Text('Hello Ms.Yağmur! Thank you for everything ;).'));
        },
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
