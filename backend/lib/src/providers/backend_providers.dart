import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../database/database_service.dart';
import '../error/error_logger.dart';
import '../library/book_repository.dart';
import '../storage/file_storage_manager.dart';
import '../vault/highlight_repository.dart';

final databaseProvider = FutureProvider<Database>((ref) async {
  return DatabaseService.database;
});

final bookRepositoryProvider = Provider<BookRepository>((ref) {
  return BookRepository();
});

final highlightRepositoryProvider = Provider<HighlightRepository>((ref) {
  return HighlightRepository();
});

final fileStorageManagerProvider = Provider<FileStorageManager>((ref) {
  return FileStorageManager();
});

final errorLoggerProvider = Provider<ErrorLogger>((ref) {
  return ErrorLogger();
});

