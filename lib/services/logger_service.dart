import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// 日志服务 - 同时输出到控制台和本地文件
class Logger {
  static final Logger _instance = Logger._internal();
  factory Logger() => _instance;
  Logger._internal();

  File? _logFile;
  bool _initialized = false;
  final List<String> _buffer = [];

  /// 初始化日志文件
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      final directory = await getApplicationDocumentsDirectory();
      final logDir = Directory('${directory.path}/logs');
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }

      final now = DateTime.now();
      final fileName = 'app_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}.log';
      _logFile = File('${logDir.path}/$fileName');

      await _logFile!.writeAsString('=== App Log Started at ${now.toString()} ===\n', mode: FileMode.append);

      // 写入缓冲区内容
      for (final line in _buffer) {
        await _logFile!.writeAsString('$line\n', mode: FileMode.append);
      }
      _buffer.clear();

      _initialized = true;
      debugPrint('[Logger] Log file initialized: ${_logFile!.path}');
    } catch (e) {
      debugPrint('[Logger] Failed to initialize log file: $e');
    }
  }

  /// 获取日志文件路径
  String? get logFilePath => _logFile?.path;

  /// 记录日志
  void log(String tag, String message, {LogLevel level = LogLevel.info}) {
    final now = DateTime.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}.${now.millisecond.toString().padLeft(3, '0')}';
    final logLine = '[$timeStr] [${level.name.toUpperCase()}] [$tag] $message';

    // 输出到控制台
    debugPrint(logLine);

    // 写入文件
    if (_initialized && _logFile != null) {
      _logFile!.writeAsString('$logLine\n', mode: FileMode.append);
    } else {
      _buffer.add(logLine);
      if (_buffer.length > 100) {
        _buffer.removeAt(0);
      }
    }
  }

  /// 记录错误
  void error(String tag, String message, [dynamic error, StackTrace? stackTrace]) {
    log(tag, '$message ${error != null ? 'Error: $error' : ''}', level: LogLevel.error);
    if (stackTrace != null) {
      log(tag, 'StackTrace: $stackTrace', level: LogLevel.error);
    }
  }

  /// 记录警告
  void warn(String tag, String message) {
    log(tag, message, level: LogLevel.warning);
  }

  /// 记录调试信息
  void debug(String tag, String message) {
    log(tag, message, level: LogLevel.debug);
  }

  /// 记录地图数据
  void mapData(String tag, Map<String, dynamic> data) {
    log(tag, 'Data: $data', level: LogLevel.debug);
  }

  /// 读取所有日志内容
  Future<String> readAllLogs() async {
    if (_logFile != null && await _logFile!.exists()) {
      return await _logFile!.readAsString();
    }
    return _buffer.join('\n');
  }

  /// 清除日志
  Future<void> clear() async {
    if (_logFile != null && await _logFile!.exists()) {
      await _logFile!.delete();
    }
    _buffer.clear();
  }
}

/// 日志级别
enum LogLevel {
  debug,
  info,
  warning,
  error,
}

/// 全局日志函数
void logInfo(String tag, String message) => Logger().log(tag, message);
void logError(String tag, String message, [dynamic error, StackTrace? stackTrace]) => Logger().error(tag, message, error, stackTrace);
void logWarn(String tag, String message) => Logger().warn(tag, message);
void logDebug(String tag, String message) => Logger().debug(tag, message);
void logMapData(String tag, Map<String, dynamic> data) => Logger().mapData(tag, data);
