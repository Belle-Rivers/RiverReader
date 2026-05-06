import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:river_reader_backend/river_reader_backend.dart';

import '../../../core/widgets/theme_mode_menu_button.dart';
import '../controllers/library_shelf_controller.dart';

class LibraryShelfPage extends ConsumerStatefulWidget {
  const LibraryShelfPage({super.key});

  @override
  ConsumerState<LibraryShelfPage> createState() => _LibraryShelfPageState();
}

class _LibraryShelfPageState extends ConsumerState<LibraryShelfPage> {
  int currentPage = 1;
  final int booksPerPage = 8;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Book>> booksValue =
        ref.watch(libraryShelfControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => context.go('/'),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const Text(
                    'My Shelf',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const ThemeModeMenuButton(),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Books Grid
              Expanded(
                child: booksValue.when(
                  data: (List<Book> books) {
                    // Add demo books if empty for visualization
                    final displayBooks = books.isEmpty ? _getDemoBooks() : books;
                    
                    return GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.7,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: booksPerPage + 1, // +1 for "Add new book"
                      itemBuilder: (BuildContext context, int index) {
                        if (index == 0) {
                          return _buildAddBookCard();
                        }
                        
                        final bookIndex = (currentPage - 1) * (booksPerPage - 1) + (index - 1);
                        if (bookIndex >= displayBooks.length) {
                          return const SizedBox.shrink();
                        }
                        
                        return _buildBookCard(displayBooks[bookIndex]);
                      },
                    );
                  },
                  error: (Object error, StackTrace stackTrace) {
                    ErrorLogger.logError('Error loading books', error, stackTrace);
                    return Center(
                      child: Text('Error loading books: $error'),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Pagination
              _buildPagination(),
              
              const SizedBox(height: 16),
              
              // Bottom Navigation
              _buildBottomNavigation(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddBookCard() {
    return InkWell(
      onTap: () {
        ref.read(libraryShelfControllerProvider.notifier).addDemoBook();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.grey.shade300,
            style: BorderStyle.solid,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_circle_outline,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 8),
            Text(
              'Add new book',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookCard(Book book) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade200, Colors.green.shade100],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Icon(
                Icons.book,
                size: 48,
                color: Colors.green.shade700,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    book.author ?? 'Unknown Author',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPagination() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: currentPage > 1
              ? () {
                  setState(() {
                    currentPage--;
                  });
                }
              : null,
          icon: const Icon(Icons.chevron_left),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.green.shade100,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$currentPage-9',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.green.shade700,
            ),
          ),
        ),
        IconButton(
          onPressed: () {
            setState(() {
              currentPage++;
            });
          },
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  Widget _buildBottomNavigation(BuildContext context) {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavItem(
            icon: Icons.home,
            label: 'Home',
            onTap: () => context.go('/'),
          ),
          _buildNavItem(
            icon: Icons.library_books,
            label: 'Shelf',
            isActive: true,
            onTap: () {},
          ),
          _buildNavItem(
            icon: Icons.library_books,
            label: 'Vault',
            onTap: () => context.go('/vault'),
          ),
          _buildNavItem(
            icon: Icons.menu_book,
            label: 'Reader',
            onTap: () => context.go('/reader'),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: isActive ? Colors.green.shade600 : Colors.grey.shade600,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isActive ? Colors.green.shade600 : Colors.grey.shade600,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Book> _getDemoBooks() {
    return [
      Book(id: 1, title: 'The Great Gatsby', author: 'F. Scott Fitzgerald', epubPath: ''),
      Book(id: 2, title: 'To Kill a Mockingbird', author: 'Harper Lee', epubPath: ''),
      Book(id: 3, title: '1984', author: 'George Orwell', epubPath: ''),
      Book(id: 4, title: 'Pride and Prejudice', author: 'Jane Austen', epubPath: ''),
      Book(id: 5, title: 'The Catcher in the Rye', author: 'J.D. Salinger', epubPath: ''),
      Book(id: 6, title: 'Animal Farm', author: 'George Orwell', epubPath: ''),
      Book(id: 7, title: 'Lord of the Flies', author: 'William Golding', epubPath: ''),
      Book(id: 8, title: 'Brave New World', author: 'Aldous Huxley', epubPath: ''),
    ];
  }
}
