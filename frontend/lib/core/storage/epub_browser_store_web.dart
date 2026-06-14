// Web-only IndexedDB implementation (analyzer uses the idb_shim VM stub).
// ignore_for_file: undefined_function, avoid_web_libraries_in_flutter

import 'dart:typed_data';

import 'package:idb_shim/idb.dart';
import 'package:idb_shim/idb_browser.dart' as idb_browser;

import 'stored_epub.dart';

class EpubBrowserStore {
  static const String _dbName = 'river_reader_epubs';
  static const String _storeName = 'epubs';
  static const int _version = 1;

  static Database? _db;

  static Future<Database> _database() async {
    if (_db != null) {
      return _db!;
    }
    final IdbFactory? factory = idb_browser.getIdbFactory();
    if (factory == null) {
      throw StateError('IndexedDB is not available');
    }
    _db = await factory.open(
      _dbName,
      version: _version,
      onUpgradeNeeded: (VersionChangeEvent event) {
        final Database db = event.database;
        if (!db.objectStoreNames.contains(_storeName)) {
          db.createObjectStore(_storeName);
        }
      },
    );
    return _db!;
  }

  static Future<void> save(String bookId, String fileName, Uint8List bytes) async {
    final Database db = await _database();
    final Transaction txn = db.transaction(_storeName, idbModeReadWrite);
    await txn.objectStore(_storeName).put(<String, Object>{
      'fileName': fileName,
      'bytes': bytes.toList(),
    }, bookId);
    await txn.completed;
  }

  static Future<StoredEpub?> read(String bookId) async {
    final Database db = await _database();
    final Transaction txn = db.transaction(_storeName, idbModeReadOnly);
    final Object? value = await txn.objectStore(_storeName).getObject(bookId);
    await txn.completed;
    if (value is! Map) {
      return null;
    }
    final Object? rawBytes = value['bytes'];
    final Object? fileName = value['fileName'];
    if (rawBytes is! List || fileName is! String) {
      return null;
    }
    return StoredEpub(
      fileName: fileName,
      bytes: Uint8List.fromList(rawBytes.cast<int>()),
    );
  }

  static Future<void> delete(String bookId) async {
    final Database db = await _database();
    final Transaction txn = db.transaction(_storeName, idbModeReadWrite);
    await txn.objectStore(_storeName).delete(bookId);
    await txn.completed;
  }

  static Future<List<String>> listBookIds() async {
    final Database db = await _database();
    final Transaction txn = db.transaction(_storeName, idbModeReadOnly);
    final List<Object?> keys = await txn.objectStore(_storeName).getAllKeys();
    await txn.completed;
    return keys.map((Object? key) => key.toString()).toList();
  }
}
