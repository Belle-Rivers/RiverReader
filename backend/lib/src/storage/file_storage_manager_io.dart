import 'dart:io';
import 'package:path_provider/path_provider.dart';

class FileStorageManager {
  static Future<Directory> getAppDirectory() async {
    return await getApplicationDocumentsDirectory();
  }

  static Future<String> getEpubAssetsPath() async {
    final dir = await getAppDirectory();
    final path = '${dir.path}/epubs';
    await Directory(path).create(recursive: true);
    return path;
  }

  static Future<String> getCoversPath() async {
    final dir = await getAppDirectory();
    final path = '${dir.path}/covers';
    await Directory(path).create(recursive: true);
    return path;
  }

  static Future<String> getDictionaryPath() async {
    final dir = await getAppDirectory();
    final path = '${dir.path}/dictionary';
    await Directory(path).create(recursive: true);
    return path;
  }

  static Future<String> getBackupsPath() async {
    final dir = await getAppDirectory();
    final path = '${dir.path}/backups';
    await Directory(path).create(recursive: true);
    return path;
  }

  static Future<String> writeTextFile(String fileName, String contents) async {
    final path = '${await getBackupsPath()}/$fileName';
    final file = File(path);
    await file.writeAsString(contents, flush: true);
    return path;
  }

  static Future<String> readTextFile(String path) async {
    return File(path).readAsString();
  }
}
