import 'dart:io';

import 'package:path_provider/path_provider.dart';

class FileStorageManager {
  const FileStorageManager._();

  static Future<Directory> getAppDirectory() async {
    return getApplicationDocumentsDirectory();
  }

  static Future<String> getBackupsPath() async {
    final Directory dir = await getAppDirectory();
    final String path = '${dir.path}/backups';
    await Directory(path).create(recursive: true);
    return path;
  }

  /// Always `false` on native — File System Access API is web-only.
  static bool get isFileSystemAccessSupported => false;

  /// Not used on native (always returns `false`).
  static Future<bool> hasStoredHandle(String fileName) async => false;

  /// No-op on native — native already overwrites the same file.
  static Future<bool> pickSaveFile(String suggestedName) async => false;

  static Future<String> writeTextFile(
    String fileName,
    String contents, {
    bool forceDownload = false,
  }) async {
    final String path = '${await getBackupsPath()}/$fileName.json';
    final File file = File(path);
    await file.writeAsString(contents, flush: true);
    return path;
  }

  static Future<String> readTextFile(String path) async {
    return File(path).readAsString();
  }
}
