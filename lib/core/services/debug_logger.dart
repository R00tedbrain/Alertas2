import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

/// Servicio de logging que captura todos los logs para debug
class DebugLogger {
  static const String _tag = 'DebugLogger';

  // Singleton
  static DebugLogger? _instance;
  static DebugLogger get instance => _instance ??= DebugLogger._();
  DebugLogger._();

  // Lista circular de logs (máximo 500 mensajes)
  final Queue<LogEntry> _logs = Queue<LogEntry>();
  static const int _maxLogs = 500;

  // Stream controller para notificar nuevos logs
  final StreamController<LogEntry> _logController =
      StreamController<LogEntry>.broadcast();

  // Getters públicos
  List<LogEntry> get logs => _logs.toList();
  Stream<LogEntry> get logStream => _logController.stream;

  /// Agregar un log
  void log(LogLevel level, String tag, String message) {
    final entry = LogEntry(
      level: level,
      tag: tag,
      message: message,
      timestamp: DateTime.now(),
    );

    // Agregar a la cola
    _logs.addLast(entry);

    // Mantener solo los últimos _maxLogs
    if (_logs.length > _maxLogs) {
      _logs.removeFirst();
    }

    // Notificar a los listeners
    _logController.add(entry);

    // También hacer print para desarrollo
    if (kDebugMode) {
      print('${entry.formattedTimestamp} ${entry.levelIcon} $tag: $message');
    }
  }

  /// Logs de diferentes niveles
  void debug(String tag, String message) => log(LogLevel.debug, tag, message);
  void info(String tag, String message) => log(LogLevel.info, tag, message);
  void warning(String tag, String message) =>
      log(LogLevel.warning, tag, message);
  void error(String tag, String message) => log(LogLevel.error, tag, message);
  void success(String tag, String message) =>
      log(LogLevel.success, tag, message);

  /// Método estático rápido para problemas de audio
  static void logAudioIssue(String message) {
    instance.error('AUDIO_DEBUG', '🎤 $message');
  }

  /// Método estático rápido para éxito de audio
  static void logAudioSuccess(String message) {
    instance.success('AUDIO_DEBUG', '🎤 $message');
  }

  /// Limpiar todos los logs
  void clear() {
    _logs.clear();
    _logController.add(LogEntry.cleared());
  }

  /// Exportar logs como texto
  String exportLogs() {
    final buffer = StringBuffer();
    buffer.writeln('=== DEBUG LOGS - AlertaTelegram ===');
    buffer.writeln(
      'Exportado: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}',
    );
    buffer.writeln('Total logs: ${_logs.length}');
    buffer.writeln('');

    for (final log in _logs) {
      buffer.writeln(
        '${log.formattedTimestamp} ${log.levelIcon} ${log.tag}: ${log.message}',
      );
    }

    return buffer.toString();
  }

  /// Limpiar recursos
  void dispose() {
    _logController.close();
  }
}

/// Niveles de log
enum LogLevel { debug, info, warning, error, success }

/// Extensión para iconos de nivel
extension LogLevelExtension on LogLevel {
  String get icon {
    switch (this) {
      case LogLevel.debug:
        return '🔍';
      case LogLevel.info:
        return 'ℹ️';
      case LogLevel.warning:
        return '⚠️';
      case LogLevel.error:
        return '❌';
      case LogLevel.success:
        return '✅';
    }
  }

  String get name {
    switch (this) {
      case LogLevel.debug:
        return 'DEBUG';
      case LogLevel.info:
        return 'INFO';
      case LogLevel.warning:
        return 'WARNING';
      case LogLevel.error:
        return 'ERROR';
      case LogLevel.success:
        return 'SUCCESS';
    }
  }
}

/// Entrada de log
class LogEntry {
  final LogLevel level;
  final String tag;
  final String message;
  final DateTime timestamp;

  const LogEntry({
    required this.level,
    required this.tag,
    required this.message,
    required this.timestamp,
  });

  /// Constructor para log de limpieza
  LogEntry.cleared()
    : level = LogLevel.info,
      tag = 'DebugLogger',
      message = 'Logs limpiados',
      timestamp = DateTime.now();

  /// Timestamp formateado
  String get formattedTimestamp => DateFormat('HH:mm:ss.SSS').format(timestamp);

  /// Icono del nivel
  String get levelIcon => level.icon;

  /// Texto completo del log
  String get fullText => '$formattedTimestamp $levelIcon $tag: $message';
}
