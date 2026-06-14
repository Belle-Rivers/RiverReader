// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

void disableWebviewPointerEventsImpl() {
  final elements = html.document.querySelectorAll('iframe');
  for (final el in elements) {
    el.style.setProperty('pointer-events', 'none', 'important');
  }
}

void enableWebviewPointerEventsImpl() {
  final elements = html.document.querySelectorAll('iframe');
  for (final el in elements) {
    el.style.removeProperty('pointer-events');
  }
}

void initWebPostMessageListenerImpl(void Function(String?) onConsoleMessage) {
  html.window.onMessage.listen((html.MessageEvent event) {
    final dynamic data = event.data;
    if (data is! String) return;
    const String prefix = 'RiverReaderBridge:';
    if (!data.startsWith(prefix)) return;
    onConsoleMessage(data);
  });
}

