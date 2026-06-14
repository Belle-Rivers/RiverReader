class FileStorageManager {
  static Future<Object> getAppDirectory() async => const _WebDirectory('');

  static Future<String> getEpubAssetsPath() async => 'epubs';

  static Future<String> getCoversPath() async => 'covers';

  static Future<String> getDictionaryPath() async => 'dictionary';

  static Future<String> getBackupsPath() async => 'backups';

  static Future<String> writeTextFile(String fileName, String contents) async => fileName;

  static Future<String> readTextFile(String path) async => '';
}

class _WebDirectory {
  const _WebDirectory(this.path);

  final String path;
}
