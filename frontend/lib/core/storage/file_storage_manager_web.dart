// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;

class FileStorageManager {
  const FileStorageManager._();

  static Future<Object> getAppDirectory() async => const _WebDirectory('');

  static Future<String> getBackupsPath() async => 'downloads';

  static Future<String> writeTextFile(String fileName, String contents) async {
    final String normalizedName = fileName.endsWith('.json') ? fileName : '$fileName.json';
    final List<int> bytes = utf8.encode(contents);
    final html.Blob blob = html.Blob(<Object>[bytes], 'application/json');
    final String url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..download = normalizedName
      ..style.display = 'none'
      ..click();
    html.Url.revokeObjectUrl(url);
    return normalizedName;
  }

  static Future<String> readTextFile(String path) async {
    throw UnsupportedError('Reading by path is not available on web.');
  }
}

class _WebDirectory {
  const _WebDirectory(this.path);

  final String path;
}
