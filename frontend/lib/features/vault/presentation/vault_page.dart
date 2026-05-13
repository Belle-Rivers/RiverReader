import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/river_ui.dart';
import '../../auth/application/current_user_provider.dart';
import '../../library/controllers/library_shelf_controller.dart';
import '../../library/data/book_api.dart';
import '../../reader/data/dictionary_api.dart';
import '../application/vault_provider.dart';
import '../data/vault_api.dart';

class VaultPage extends ConsumerStatefulWidget {
  const VaultPage({super.key});

  @override
  ConsumerState<VaultPage> createState() => _VaultPageState();
}

class _VaultPageState extends ConsumerState<VaultPage> {
  final TextEditingController _searchController = TextEditingController();
  bool _didReadInitialBookFilter = false;
  _VaultSort _sort = _VaultSort.recent;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vaultItemsAsync = ref.watch(vaultItemsProvider);
    final booksAsync = ref.watch(libraryShelfControllerProvider);
    final selectedBookId = ref.watch(vaultSelectedBookIdProvider);

    if (!_didReadInitialBookFilter) {
      _didReadInitialBookFilter = true;
      final String? routeBookId = GoRouterState.of(context).uri.queryParameters['bookId'];
      if (routeBookId != null && routeBookId.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(vaultSelectedBookIdProvider.notifier).state = routeBookId;
        });
      }
    }

    return RiverScaffold(
      title: 'The Vault',
      tab: RiverTab.vault,
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _searchController,
              onChanged: (String value) {
                ref.read(vaultSearchQueryProvider.notifier).state = value;
              },
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search words or meanings...',
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _bookFilterPill(
                    theme: theme,
                    selectedBookId: selectedBookId,
                    booksAsync: booksAsync,
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 190,
                  child: _sortPill(theme),
                ),
              ],
            ),
            const SizedBox(height: 12),
            vaultItemsAsync.when(
              data: (items) => Text('${_sortItems(items).length} words', style: theme.textTheme.bodyLarge),
              loading: () => Text('Loading...', style: theme.textTheme.bodyLarge),
              error: (e, st) => Text('Failed to load', style: theme.textTheme.bodyLarge),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: vaultItemsAsync.when(
                data: (items) {
                  final sortedItems = _sortItems(items);
                  if (sortedItems.isEmpty) {
                    return const Center(child: Text('No words in vault yet.'));
                  }
                  return ListView.builder(
                    itemCount: sortedItems.length,
                    itemBuilder: (_, i) {
                      final item = sortedItems[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: RiverCard(
                          child: InkWell(
                            onTap: () => _openWordDetails(item),
                            borderRadius: BorderRadius.circular(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.targetWord,
                                        style: theme.textTheme.titleLarge?.copyWith(fontStyle: FontStyle.italic),
                                      ),
                                    ),
                                    Text(item.bookTitle ?? 'Unknown Book', style: theme.textTheme.bodyLarge),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      onPressed: () => _confirmDelete(item),
                                      icon: const Icon(Icons.delete_outline),
                                      tooltip: 'Delete word',
                                    ),
                                  ],
                                ),
                                Text(
                                  '"${item.contextSentence}"',
                                  style: theme.textTheme.bodyLarge,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => Center(child: Text('Error: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<VaultItemRead> _sortItems(List<VaultItemRead> items) {
    final sorted = List<VaultItemRead>.from(items);
    switch (_sort) {
      case _VaultSort.recent:
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case _VaultSort.alphabetical:
        sorted.sort((a, b) => a.targetWord.toLowerCase().compareTo(b.targetWord.toLowerCase()));
      case _VaultSort.book:
        sorted.sort((a, b) => (a.bookTitle ?? '').toLowerCase().compareTo((b.bookTitle ?? '').toLowerCase()));
    }
    return sorted;
  }

  Widget _bookFilterPill({
    required ThemeData theme,
    required String? selectedBookId,
    required AsyncValue<List<BookApiModel>> booksAsync,
  }) {
    final selectedBookName = booksAsync.maybeWhen(
      data: (books) => books
          .firstWhere(
            (book) => book.id == selectedBookId,
            orElse: () => const BookApiModel(id: '', title: 'All books'),
          )
          .title,
      orElse: () => 'All books',
    );
    final label = selectedBookId == null ? 'All books' : selectedBookName;
    return PopupMenuButton<String?>(
      onSelected: (value) {
        ref.read(vaultSelectedBookIdProvider.notifier).state = value;
      },
      itemBuilder: (context) {
        final items = <PopupMenuEntry<String?>>[
          const PopupMenuItem<String?>(
            value: null,
            child: Text('All books'),
          ),
        ];
        booksAsync.whenData((books) {
          for (final book in books) {
            items.add(
              PopupMenuItem<String?>(
                value: book.id,
                child: Text(book.title),
              ),
            );
          }
        });
        return items;
      },
      child: _pill(theme, label),
    );
  }

  Widget _sortPill(ThemeData theme) {
    return PopupMenuButton<_VaultSort>(
      onSelected: (value) {
        setState(() {
          _sort = value;
        });
      },
      itemBuilder: (context) => const [
        PopupMenuItem<_VaultSort>(
          value: _VaultSort.recent,
          child: Text('Recent'),
        ),
        PopupMenuItem<_VaultSort>(
          value: _VaultSort.alphabetical,
          child: Text('A-Z'),
        ),
        PopupMenuItem<_VaultSort>(
          value: _VaultSort.book,
          child: Text('Book'),
        ),
      ],
      child: _pill(theme, _sort.label),
    );
  }

  Widget _pill(ThemeData theme, String label) {
    return RiverCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyLarge),
          const Icon(Icons.expand_more),
        ],
      ),
    );
  }

  Future<void> _openWordDetails(VaultItemRead item) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        return _VaultWordDetailSheet(item: item);
      },
    );
  }

  Future<void> _confirmDelete(VaultItemRead item) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Delete "${item.targetWord}"?'),
          content: const Text('Are you sure you want to delete this word from the vault?'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
          ],
        );
      },
    );
    
    if (shouldDelete != true) return;
    if (!mounted) return;

    final userId = ref.read(sessionUserIdProvider);
    if (userId == null) return;
    
    try {
      await ref.read(vaultApiProvider).deleteHighlight(item.id, userId);
      ref.invalidate(vaultItemsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Word deleted')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete word: $e')));
    }
  }
}

class _VaultWordDetailSheet extends ConsumerStatefulWidget {
  const _VaultWordDetailSheet({required this.item});

  final VaultItemRead item;

  @override
  ConsumerState<_VaultWordDetailSheet> createState() => _VaultWordDetailSheetState();
}

class _VaultWordDetailSheetState extends ConsumerState<_VaultWordDetailSheet> {
  late Future<DictionaryEntryModel?> _dictionaryFuture;

  @override
  void initState() {
    super.initState();
    _dictionaryFuture =
        ref.read(dictionaryApiProvider).lookupWord(widget.item.targetWord);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final VaultItemRead item = widget.item;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.targetWord, style: theme.textTheme.headlineMedium),
              const SizedBox(height: 10),
              FutureBuilder<DictionaryEntryModel?>(
                future: _dictionaryFuture,
                builder: (BuildContext context, AsyncSnapshot<DictionaryEntryModel?> snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) {
                    return Text(
                      'Could not load dictionary entry.',
                      style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.error),
                    );
                  }
                  final DictionaryEntryModel? entry = snapshot.data;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry?.definition ?? 'No hint in dictionary yet. Add entries via POST /v1/dictionary on the dev backend.',
                        style: theme.textTheme.bodyLarge,
                      ),
                      if (entry != null && entry.synonyms.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Synonyms: ${entry.synonyms.join(', ')}',
                          style: theme.textTheme.bodyLarge,
                        ),
                      ],
                      if (entry?.exampleSentence != null &&
                          entry!.exampleSentence!.trim().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text('Example', style: theme.textTheme.titleSmall),
                        const SizedBox(height: 4),
                        Text(entry.exampleSentence!, style: theme.textTheme.bodyMedium),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              Text('Where it was mentioned', style: theme.textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(item.contextSentence, style: theme.textTheme.bodyLarge),
              if (item.contextBefore != null) ...[
                const SizedBox(height: 6),
                Text('Before: ${item.contextBefore}', style: theme.textTheme.bodyMedium),
              ],
              if (item.contextAfter != null) ...[
                const SizedBox(height: 6),
                Text('After: ${item.contextAfter}', style: theme.textTheme.bodyMedium),
              ],
              const SizedBox(height: 6),
              Text(
                'Book: ${item.bookTitle ?? 'Unknown'} · Chapter: ${item.chapterTitle ?? '-'}',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _VaultSort {
  recent('Recent'),
  alphabetical('A-Z'),
  book('Book');
  const _VaultSort(this.label);
  final String label;
}
