import 'dart:typed_data';

import 'stored_epub.dart';

class EpubBrowserStore {
  static Future<void> save(String bookId, String fileName, Uint8List bytes) async {}

  static Future<StoredEpub?> read(String bookId) async => null;

  static Future<void> delete(String bookId) async {}

  static Future<List<String>> listBookIds() async => const <String>[];
}
