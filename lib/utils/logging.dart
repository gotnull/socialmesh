// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:logger/logger.dart';

/// Creates a logger instance with standard formatting
Logger createLogger({String? name}) {
  return Logger(
    filter: ProductionFilter(),
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
    output: ConsoleOutput(),
  );
}

/// Log levels
enum LogLevel { verbose, debug, info, warning, error }

/// Extension methods for logging
extension LoggerExtensions on Logger {
  void log(
    LogLevel level,
    String message, {
    dynamic error,
    StackTrace? stackTrace,
  }) {
    switch (level) {
      case LogLevel.verbose:
        t(message, error: error, stackTrace: stackTrace);
      case LogLevel.debug:
        d(message, error: error, stackTrace: stackTrace);
      case LogLevel.info:
        i(message, error: error, stackTrace: stackTrace);
      case LogLevel.warning:
        w(message, error: error, stackTrace: stackTrace);
      case LogLevel.error:
        e(message, error: error, stackTrace: stackTrace);
    }
  }
}
