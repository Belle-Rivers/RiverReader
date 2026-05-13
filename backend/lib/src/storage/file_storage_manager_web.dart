class FileStorageManager {
  static Future<Object> getAppDirectory() async => const _WebDirectory('');

  static Future<String> getEpubAssetsPath() async => 'epubs';

  static Future<String> getCoversPath() async => 'covers';

  static Future<String> getDictionaryPath() async => 'dictionary';
}

class _WebDirectory {
  const _WebDirectory(this.path);

  final String path;
}
