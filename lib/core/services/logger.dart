import 'dart:developer' as developer;

class Logger {
  const Logger._();

  static void d(String message, {Object? error, StackTrace? stackTrace}) {
    developer.log(
      message,
      level: 500,
      error: error,
      stackTrace: stackTrace,
      name: 'DEBUG',
    );
  }

  static void i(String message, {Object? error, StackTrace? stackTrace}) {
    developer.log(
      message,
      level: 800,
      error: error,
      stackTrace: stackTrace,
      name: 'INFO',
    );
  }

  static void w(String message, {Object? error, StackTrace? stackTrace}) {
    developer.log(
      message,
      level: 900,
      error: error,
      stackTrace: stackTrace,
      name: 'WARN',
    );
  }

  static void e(String message, {Object? error, StackTrace? stackTrace}) {
    developer.log(
      message,
      level: 1000,
      error: error,
      stackTrace: stackTrace,
      name: 'ERROR',
    );
  }
}
