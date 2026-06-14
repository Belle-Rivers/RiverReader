// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js' as js;

class FileStorageManager {
  const FileStorageManager._();

  // ---------------------------------------------------------------------------
  // IndexedDB — dart:html event streams (avoids dart:js callback wrapping).
  // ---------------------------------------------------------------------------

  static dynamic _db;

  static Future<dynamic> _openDatabase() async {
    if (_db != null) return _db;
    try {
      final dynamic idbFactory = html.window.indexedDB;
      if (idbFactory == null) return null;

      final Completer<dynamic> completer = Completer<dynamic>();
      final dynamic request =
          idbFactory.open('river_reader_backup', 1);

      request.onUpgradeNeeded.listen((dynamic event) {
        final db = event.target.result;
        if (!db.objectStoreNames.contains('file_handles')) {
          db.createObjectStore('file_handles');
        }
      });

      request.onSuccess.listen((dynamic event) {
        if (!completer.isCompleted) {
          _db = event.target.result;
          completer.complete(_db);
        }
      });

      request.onError.listen((dynamic event) {
        if (!completer.isCompleted) completer.complete(null);
      });

      return completer.future;
    } catch (_) {
      return null;
    }
  }

  /// Wait for an IDBRequest to fire onsuccess and return its result.
  static Future<dynamic> _requestResult(dynamic request) {
    final Completer<dynamic> completer = Completer<dynamic>();
    request.onSuccess.listen((dynamic event) {
      if (!completer.isCompleted) {
        completer.complete(event.target.result);
      }
    });
    request.onError.listen((dynamic event) {
      if (!completer.isCompleted) completer.complete(null);
    });
    return completer.future;
  }

  /// Wait for an IDBTransaction to fire oncomplete.
  static Future<void> _txComplete(dynamic tx) {
    final Completer<void> completer = Completer<void>();
    tx.onComplete.listen((dynamic event) {
      if (!completer.isCompleted) completer.complete();
    });
    tx.onError.listen((dynamic event) {
      if (!completer.isCompleted) completer.complete();
    });
    tx.onAbort.listen((dynamic event) {
      if (!completer.isCompleted) completer.complete();
    });
    return completer.future;
  }

  static Future<void> _storeHandle(String key, dynamic handle) async {
    final db = await _openDatabase();
    if (db == null) return;
    try {
      final dynamic tx = db.transaction('file_handles', 'readwrite');
      final dynamic store = tx.objectStore('file_handles');
      store.put(handle, key);
      await _txComplete(tx);
    } catch (e) {
      // ignore: avoid_print
      print('[RiverReader] _storeHandle failed: $e');
    }
  }

  static Future<dynamic> _getHandle(String key) async {
    final db = await _openDatabase();
    if (db == null) return null;
    try {
      final dynamic tx = db.transaction('file_handles', 'readonly');
      final dynamic store = tx.objectStore('file_handles');
      final dynamic request = store.get(key);
      return _requestResult(request);
    } catch (e) {
      // ignore: avoid_print
      print('[RiverReader] _getHandle failed: $e');
      return null;
    }
  }

  static Future<void> _removeHandle(String key) async {
    final db = await _openDatabase();
    if (db == null) return;
    try {
      final dynamic tx = db.transaction('file_handles', 'readwrite');
      final dynamic store = tx.objectStore('file_handles');
      store.delete(key);
      await _txComplete(tx);
    } catch (_) {
      // Non-fatal.
    }
  }

  // ---------------------------------------------------------------------------
  // JS promise → Dart Future
  // ---------------------------------------------------------------------------

  static Future<T> _promiseToFuture<T>(dynamic jsPromise) {
    final Completer<T> completer = Completer<T>();
    try {
      final js.JsFunction onResolve =
          js.JsFunction.withThis((dynamic self, dynamic value) {
        if (!completer.isCompleted) completer.complete(value as T);
      });
      final js.JsFunction onReject =
          js.JsFunction.withThis((dynamic self, dynamic error) {
        if (!completer.isCompleted) {
          completer.completeError(error ?? 'Unknown JS error');
        }
      });
      (jsPromise as js.JsObject)
          .callMethod('then', <dynamic>[onResolve, onReject]);
    } catch (e) {
      if (!completer.isCompleted) completer.completeError(e);
    }
    return completer.future;
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  static Future<Object> getAppDirectory() async => const _WebDirectory('');

  static Future<String> getBackupsPath() async => 'downloads';

  static bool get isFileSystemAccessSupported {
    try {
      return js.context.hasProperty('showSaveFilePicker');
    } catch (_) {
      return false;
    }
  }

  static Future<bool> hasStoredHandle(String fileName) async {
    try {
      final dynamic handle = await _getHandle(fileName);
      return handle != null;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> pickSaveFile(String suggestedName) async {
    if (!isFileSystemAccessSupported) return false;
    try {
      final js.JsObject options = js.JsObject.jsify(<String, dynamic>{
        'suggestedName': suggestedName,
        'types': <dynamic>[
          js.JsObject.jsify(<String, dynamic>{
            'description': 'JSON Backup',
            'accept': <String, dynamic>{
              'application/json': <String>['.json'],
            },
          }),
        ],
      });
      final dynamic handle = await _promiseToFuture<dynamic>(
        js.context.callMethod('showSaveFilePicker', <dynamic>[options]),
      );
      await _storeHandle(suggestedName, handle);
      // ignore: avoid_print
      print('[RiverReader] pickSaveFile: handle stored for $suggestedName');
      return true;
    } catch (e) {
      // ignore: avoid_print
      print('[RiverReader] pickSaveFile failed: $e');
      return false;
    }
  }

  static Future<String> writeTextFile(
    String fileName,
    String contents, {
    bool forceDownload = false,
  }) async {
    final String normalizedName =
        fileName.endsWith('.json') ? fileName : '$fileName.json';

    if (!forceDownload) {
      try {
        final dynamic handle = await _getHandle(normalizedName);
        // ignore: avoid_print
        print('[RiverReader] writeTextFile: handle for "$normalizedName" is ${handle == null ? "null" : "present"}');
        if (handle != null) {
          final js.JsObject handleJs = handle as js.JsObject;
          final dynamic writable = await _promiseToFuture<dynamic>(
            handleJs.callMethod('createWritable', <dynamic>[]),
          );
          final js.JsObject writableJs = writable as js.JsObject;
          await _promiseToFuture<dynamic>(
            writableJs.callMethod('write', <dynamic>[contents]),
          );
          await _promiseToFuture<dynamic>(
            writableJs.callMethod('close', <dynamic>[]),
          );
          // ignore: avoid_print
          print('[RiverReader] writeTextFile: wrote via handle to $normalizedName');
          return normalizedName;
        }
      } catch (e) {
        // ignore: avoid_print
        print('[RiverReader] writeTextFile handle path failed: $e');
        await _removeHandle(normalizedName);
      }
    }

    // Fallback: browser download.
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
