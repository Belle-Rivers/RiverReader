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

  static Future<String> writeTextFile(String fileName, String contents) async {
    final String path = '${await getBackupsPath()}/$fileName.json';
    final File file = File(path);
    await file.writeAsString(contents, flush: true);
    return path;
  }

  static Future<String> readTextFile(String path) async {
    return File(path).readAsString();
  }
}
