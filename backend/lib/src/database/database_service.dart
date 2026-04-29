import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:path/path.dart';

class DatabaseService {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await initDB('river_reader.db');
    return _database!;
  }

  static Future<Database> initDB(String filePath) async {
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
    }
    final dbPath = kIsWeb ? '' : await getDatabasesPath();
    final path = kIsWeb ? filePath : join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onConfigure: (Database db) async {
        await db.execute('PRAGMA foreign_keys = ON;');
      },
      onCreate: _createDB,
    );
  }

  static Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE books (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        author TEXT,
        cover_path TEXT,
        epub_path TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE ghost_highlights (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        book_id INTEGER NOT NULL,
        target_word TEXT NOT NULL,
        context_sentence TEXT NOT NULL,
        cfi_location TEXT NOT NULL,
        mastery_level INTEGER DEFAULT 0,
        next_review_date INTEGER,
        FOREIGN KEY (book_id) REFERENCES books (id) ON DELETE CASCADE
      )
    ''');
  }
}
