import 'package:web/web.dart' as web;

class FileStorageManager {
  static const String _keyPrefix = 'river_reader_backup:';

  static Future<Object> getAppDirectory() async => const _WebDirectory('');

  static Future<String> getEpubAssetsPath() async => 'epubs';

  static Future<String> getCoversPath() async => 'covers';

  static Future<String> getDictionaryPath() async => 'dictionary';

  static Future<String> getBackupsPath() async => 'backups';

  static Future<String> writeTextFile(String fileName, String contents) async {
    web.window.localStorage.setItem(_storageKey(fileName), contents);
    return fileName;
  }

  static Future<String> readTextFile(String path) async {
    final String? contents = web.window.localStorage.getItem(_storageKey(path));
    return contents ?? '';
  }

  static String _storageKey(String fileName) => '$_keyPrefix$fileName';
}

class _WebDirectory {
  const _WebDirectory(this.path);

  final String path;
}
