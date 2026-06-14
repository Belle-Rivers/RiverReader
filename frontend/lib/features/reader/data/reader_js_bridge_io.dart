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
  controller.addJavaScriptHandler(
    handlerName: ghostCaptureHandlerName,
    callback: (List<dynamic> args) {
      if (args.isEmpty || args.first is! Map) {
        return;
      }
      onMessage(
        ghostCaptureHandlerName,
        Map<String, dynamic>.from(args.first as Map),
      );
    },
  );
  controller.addJavaScriptHandler(
    handlerName: dictionaryHintHandlerName,
    callback: (List<dynamic> args) {
      if (args.isEmpty || args.first is! Map) {
        return;
      }
      onMessage(
        dictionaryHintHandlerName,
        Map<String, dynamic>.from(args.first as Map),
      );
    },
  );
  controller.addJavaScriptHandler(
    handlerName: dictionaryDismissHandlerName,
    callback: (List<dynamic> args) {
      onMessage(dictionaryDismissHandlerName, <String, dynamic>{});
    },
  );
  return ReaderJsBridgeHandle(() {});
}
