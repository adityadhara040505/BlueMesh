import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// Structured logging wrapper for BlueMesh with an in-memory diagnostic buffer.
class AppLogger {
  AppLogger._();

  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 80,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  );

  /// Fixed-capacity log ring buffer for live in-app Diagnostics screen viewing.
  static final Queue<LogEntry> _recentLogs = Queue<LogEntry>();
  static const int _maxInMemoryLogs = 500;

  /// Retrieve an unmodifiable list of recent in-memory log entries.
  static List<LogEntry> get recentLogs => List.unmodifiable(_recentLogs);

  /// Event notifier triggered whenever a new log entry is appended.
  static final ValueNotifier<int> logUpdateNotifier = ValueNotifier<int>(0);

  static void _record(Level level, String message, [Object? error, StackTrace? stackTrace]) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      message: message,
      error: error?.toString(),
    );

    if (_recentLogs.length >= _maxInMemoryLogs) {
      _recentLogs.removeFirst();
    }
    _recentLogs.addLast(entry);
    logUpdateNotifier.value++;

    // Print directly to stdout for terminal and runtime diagnosis
    print('[BlueMesh ${level.name.toUpperCase()}] $message');
    if (error != null) {
      print('[BlueMesh ${level.name.toUpperCase()} CAUSE] $error');
    }
  }

  /// Debug level logging for verbose internal traces.
  static void d(String message, [Object? error, StackTrace? stackTrace]) {
    _record(Level.debug, message, error, stackTrace);
    _logger.d(message, error: error, stackTrace: stackTrace);
  }

  /// Info level logging for major milestones (connection made, peer found).
  static void i(String message, [Object? error, StackTrace? stackTrace]) {
    _record(Level.info, message, error, stackTrace);
    _logger.i(message, error: error, stackTrace: stackTrace);
  }

  /// Warning level logging for non-fatal retries and dropped duplicates.
  static void w(String message, [Object? error, StackTrace? stackTrace]) {
    _record(Level.warning, message, error, stackTrace);
    _logger.w(message, error: error, stackTrace: stackTrace);
  }

  /// Error level logging for GATT failures, permission rejections, etc.
  static void e(String message, [Object? error, StackTrace? stackTrace]) {
    _record(Level.error, message, error, stackTrace);
    _logger.e(message, error: error, stackTrace: stackTrace);
  }

  /// Clear in-memory log buffer.
  static void clear() {
    _recentLogs.clear();
    logUpdateNotifier.value++;
  }
}

/// A structured entry in the diagnostics ring buffer.
class LogEntry {
  final DateTime timestamp;
  final Level level;
  final String message;
  final String? error;

  const LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    this.error,
  });

  @override
  String toString() {
    final timeStr =
        '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';
    final errStr = error != null ? ' | ERR: $error' : '';
    return '[$timeStr] [${level.name.toUpperCase()}] $message$errStr';
  }
}
