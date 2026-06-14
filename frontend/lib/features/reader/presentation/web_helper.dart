import 'web_helper_stub.dart'
    if (dart.library.html) 'web_helper_web.dart' as impl;

void disableWebviewPointerEvents() => impl.disableWebviewPointerEventsImpl();
void enableWebviewPointerEvents() => impl.enableWebviewPointerEventsImpl();
void initWebPostMessageListener(void Function(String?) onConsoleMessage) =>
    impl.initWebPostMessageListenerImpl(onConsoleMessage);
