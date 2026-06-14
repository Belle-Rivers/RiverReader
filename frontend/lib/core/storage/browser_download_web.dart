// Web-only download helper.
// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:convert';
import 'dart:html' as html;

class BrowserDownload {
  static Future<void> downloadText(String fileName, String contents) async {
    final String normalizedName = fileName.endsWith('.json') ? fileName : '$fileName.json';
    final html.Blob blob = html.Blob(<Object>[utf8.encode(contents)], 'application/json');
    final String url = html.Url.createObjectUrlFromBlob(blob);
    final html.AnchorElement anchor = html.AnchorElement(href: url)
      ..download = normalizedName
      ..style.display = 'none';
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
  }
}
