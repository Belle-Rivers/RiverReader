import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';


import '../../../core/widgets/river_ui.dart';
import '../controllers/library_shelf_controller.dart';
import '../data/book_api.dart';

class LibraryShelfPage extends ConsumerStatefulWidget {
  const LibraryShelfPage({super.key});

  @override
  ConsumerState<LibraryShelfPage> createState() => _LibraryShelfPageState();
}

class _LibraryShelfPageState extends ConsumerState<LibraryShelfPage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(libraryShelfControllerProvider);

    return RiverScaffold(
      title: 'My Shelf',
      tab: RiverTab.shelf,
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickAndUploadEpub,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: theme.colorScheme.outline, width: 2),
                ),
                child: Text(
                  '+  Add an EPUB',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(fontSize: 20),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: state.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(child: Text('Error: $error')),
                data: (books) {
                  if (books.isEmpty) {
                    return const Center(child: Text('Your shelf is empty.'));
                  }
                  return GridView.builder(
                    itemCount: books.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: .63,
                    ),
                    itemBuilder: (_, i) {
                      final book = books[i];
                      return GestureDetector(
                        onTap: () => context.push('/reader/${book.id}', extra: book),
                        onLongPress: () => _showBookActions(context, book),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(22),
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF5A4432), Color(0xFF32261E)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: Align(
                                  alignment: Alignment.bottomLeft,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(book.title, style: theme.textTheme.titleLarge?.copyWith(color: Colors.white)),
                                      Text(book.author ?? 'Unknown Author', style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white70)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text('${(book.progressPercent ?? 0).toStringAsFixed(1)}% · ${(book.lastReadAt != null ? "Started" : "New")}', style: theme.textTheme.bodyLarge),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadEpub() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['epub'],
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      if (file.bytes != null) {
        await ref.read(libraryShelfControllerProvider.notifier).uploadBook(
          file.path ?? file.name,
          file.name,
          file.bytes!.toList(),
        );
      }
    }
  }

  Future<void> _showBookActions(BuildContext context, BookApiModel book) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.play_arrow_rounded),
                  title: const Text('Open book'),
                  onTap: () => Navigator.of(context).pop('open'),
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('Delete'),
                  onTap: () => Navigator.of(context).pop('delete'),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (action == 'delete') {
      await ref.read(libraryShelfControllerProvider.notifier).deleteBook(book.id);
    } else if (action == 'open') {
      if (context.mounted) {
        context.push('/reader/${book.id}', extra: book);
      }
    }
  }
}

