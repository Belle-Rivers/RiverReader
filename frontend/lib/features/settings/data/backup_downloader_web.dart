// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;

class BackupDownloader {
  static Future<void> saveBackup(String contents, String? path) async {
    final List<int> bytes = utf8.encode(contents);
    final html.Blob blob = html.Blob(<Object>[bytes], 'application/json');
    final String url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..download = 'RiverReader_backup.json'
      ..style.display = 'none'
      ..click();
    html.Url.revokeObjectUrl(url);
  }
}
