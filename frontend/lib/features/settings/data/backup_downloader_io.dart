import 'dart:io';

class BackupDownloader {
  static Future<void> saveBackup(String contents, String? path) async {
    if (path == null) return;
    await File(path).writeAsString(contents);
  }
}
