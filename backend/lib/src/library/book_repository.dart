import '../database/database_service.dart';

class Book {
  final int? id;
  final String title;
  final String? author;
  final String? coverPath;
  final String epubPath;

  Book({this.id, required this.title, this.author, this.coverPath, required this.epubPath});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'cover_path': coverPath,
      'epub_path': epubPath,
    };
  }

  factory Book.fromMap(Map<String, dynamic> map) {
    return Book(
      id: map['id'],
      title: map['title'],
      author: map['author'],
      coverPath: map['cover_path'],
      epubPath: map['epub_path'],
    );
  }
}

class BookRepository {
  Future<int> insertBook(Book book) async {
    final db = await DatabaseService.database;
    return await db.insert('books', book.toMap());
  }

  Future<List<Book>> getAllBooks() async {
    final db = await DatabaseService.database;
    final List<Map<String, dynamic>> maps = await db.query('books');
    return List.generate(maps.length, (i) => Book.fromMap(maps[i]));
  }

  Future<void> deleteBook(int id) async {
    final db = await DatabaseService.database;
    await db.delete('books', where: 'id = ?', whereArgs: [id]);
  }
}
