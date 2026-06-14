import 'dart:developer' as developer;

class ErrorLogger {
  const ErrorLogger._();

  static void logInfo(String message) {
    developer.log(message, name: 'RiverReader');
  }

  static void logWarning(String message) {
    developer.log(message, name: 'RiverReader', level: 900);
  }

  static void logError(
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    developer.log(
      message,
      name: 'RiverReader',
      level: 1000,
      error: error,
      stackTrace: stackTrace,
    );
  }

  static void logFatal(
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    developer.log(
      message,
      name: 'RiverReader',
      level: 1200,
      error: error,
      stackTrace: stackTrace,
    );
  }
}
