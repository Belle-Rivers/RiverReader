// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

class FileStorageManager {
  const FileStorageManager._();

  static Future<Object> getAppDirectory() async => const _WebDirectory('');

  static Future<String> getBackupsPath() async => 'downloads';

  static Future<String> readTextFile(String path) async {
    throw UnsupportedError('Reading by path is not available on web.');
  }
}

class _WebDirectory {
  const _WebDirectory(this.path);
  final String path;
}
