// Web bridge uses window.postMessage because addJavaScriptHandler is unsupported.
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

typedef ReaderJsMessageCallback = void Function(
  String handlerName,
  Map<String, dynamic> payload,
);

class ReaderJsBridgeHandle {
  ReaderJsBridgeHandle(this._dispose);

  final void Function() _dispose;

  void dispose() => _dispose();
}

ReaderJsBridgeHandle installReaderJsBridge({
  required InAppWebViewController controller,
  required ReaderJsMessageCallback onMessage,
  required String ghostCaptureHandlerName,
  required String dictionaryHintHandlerName,
  required String dictionaryDismissHandlerName,
}) {
  final StreamSubscription<html.MessageEvent> subscription =
      html.window.onMessage.listen((html.MessageEvent event) {
    final Object? data = event.data;
    if (data is! Map) {
      return;
    }
    final Map<String, dynamic> map = Map<String, dynamic>.from(data);
    if (map['source'] != 'river_reader') {
      return;
    }
    final Object? handler = map['handler'];
    final Object? payload = map['payload'];
    if (handler is! String) {
      return;
    }
    if (payload is Map) {
      onMessage(handler, Map<String, dynamic>.from(payload));
      return;
    }
    onMessage(handler, <String, dynamic>{});
  });
  return ReaderJsBridgeHandle(subscription.cancel);
}
