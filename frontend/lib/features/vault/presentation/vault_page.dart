import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class VaultPage extends ConsumerWidget {
  const VaultPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                    'My Vault',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 48), // Balance the back button
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Filter and Sort buttons
              Row(
                children: [
                  Expanded(
                    child: _buildFilterButton(
                      icon: Icons.filter_list,
                      label: 'Book Filter',
                      onTap: () {
                        // Show book filter
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildFilterButton(
                      icon: Icons.sort,
                      label: 'Sort by',
                      onTap: () {
                        // Show sort options
                      },
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Word list
              Expanded(
                child: ListView.builder(
                  itemCount: _getDemoWords().length,
                  itemBuilder: (context, index) {
                    final word = _getDemoWords()[index];
                    return _buildWordCard(word);
                  },
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Bottom Navigation
              _buildBottomNavigation(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: Colors.grey.shade600,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWordCard(WordEntry word) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      word.word,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      word.definition,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        height: 1.4,
                      ),
                    ),
                    if (word.book.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.purple.shade200),
                        ),
                        child: Text(
                          word.book,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.purple.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                children: [
                  _buildActionButton(
                    icon: Icons.info_outline,
                    color: Colors.blue.shade600,
                    onTap: () {
                      // Show details
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildActionButton(
                    icon: Icons.archive_outlined,
                    color: Colors.orange.shade600,
                    onTap: () {
                      // Archive word
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildActionButton(
                    icon: Icons.delete_outline,
                    color: Colors.red.shade600,
                    onTap: () {
                      // Delete word
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 20,
          color: color,
        ),
      ),
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
            onTap: () => context.go('/shelf'),
          ),
          _buildNavItem(
            icon: Icons.library_books,
            label: 'Vault',
            isActive: true,
            onTap: () {},
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
              color: isActive ? Colors.purple.shade600 : Colors.grey.shade600,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isActive ? Colors.purple.shade600 : Colors.grey.shade600,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<WordEntry> _getDemoWords() {
    return [
      WordEntry(
        word: 'Serendipity',
        definition: 'The occurrence of events by chance in a happy or beneficial way.',
        book: 'The Great Gatsby',
      ),
      WordEntry(
        word: 'Ephemeral',
        definition: 'Lasting for a very short time; transient.',
        book: '1984',
      ),
      WordEntry(
        word: 'Mellifluous',
        definition: 'Sweet or musical; pleasant to hear.',
        book: 'Pride and Prejudice',
      ),
      WordEntry(
        word: 'Petrichor',
        definition: 'The pleasant, earthy smell produced when rain falls on dry soil.',
        book: 'To Kill a Mockingbird',
      ),
      WordEntry(
        word: 'Limerence',
        definition: 'The state of being infatuated with another person.',
        book: 'The Catcher in the Rye',
      ),
    ];
  }
}

class WordEntry {
  final String word;
  final String definition;
  final String book;

  WordEntry({
    required this.word,
    required this.definition,
    required this.book,
  });
}

