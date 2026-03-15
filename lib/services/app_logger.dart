import 'dart:collection';

enum LogLevel { debug, info, warn, error }

class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String category;
  final String message;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.category,
    required this.message,
  });

  @override
  String toString() {
    final time = timestamp.toIso8601String().substring(11, 23);
    final lvl = level.name.toUpperCase().padRight(5);
    return '[$time] $lvl [$category] $message';
  }
}

/// Centralized app logger with in-memory ring buffer.
/// Access logs from the debug panel in AI Insights.
class AppLogger {
  static final List<LogEntry> _logs = [];
  static final List<void Function()> _listeners = [];
  static const int _maxLogs = 500;

  static UnmodifiableListView<LogEntry> get logs => UnmodifiableListView(_logs);

  static String get logsText => _logs.map((e) => e.toString()).join('\n');

  static int get count => _logs.length;

  static void addListener(void Function() listener) => _listeners.add(listener);
  static void removeListener(void Function() listener) => _listeners.remove(listener);

  static void _add(LogLevel level, String category, String message) {
    _logs.add(LogEntry(
      timestamp: DateTime.now(),
      level: level,
      category: category,
      message: message,
    ));
    if (_logs.length > _maxLogs) {
      _logs.removeRange(0, _logs.length - _maxLogs);
    }
    for (final l in _listeners) {
      l();
    }
  }

  static void debug(String category, String message) => _add(LogLevel.debug, category, message);
  static void info(String category, String message) => _add(LogLevel.info, category, message);
  static void warn(String category, String message) => _add(LogLevel.warn, category, message);
  static void error(String category, String message) => _add(LogLevel.error, category, message);

  static void clear() {
    _logs.clear();
    for (final l in _listeners) {
      l();
    }
  }

  /// Get logs filtered by category.
  static List<LogEntry> forCategory(String category) =>
      _logs.where((e) => e.category == category).toList();

  /// Get logs filtered by level (and above).
  static List<LogEntry> atLevel(LogLevel minLevel) =>
      _logs.where((e) => e.level.index >= minLevel.index).toList();
}
