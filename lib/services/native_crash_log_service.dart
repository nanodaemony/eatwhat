import 'dart:io';
import 'package:flutter/services.dart';

/// Native崩溃日志服务
class NativeCrashLogService {
  static const MethodChannel _channel = MethodChannel('com.nano.eatwhat/crash');

  /// 获取Native崩溃日志（从logcat监控）
  static Future<String> getNativeCrashLog() async {
    if (!Platform.isAndroid) {
      return '仅在Android平台可用';
    }
    try {
      final String result = await _channel.invokeMethod('getCrashLogs');
      return result;
    } catch (e) {
      return '获取Native崩溃日志失败: $e';
    }
  }

  /// 获取所有崩溃日志文件列表
  static Future<List<String>> getAllCrashLogFiles() async {
    if (!Platform.isAndroid) {
      return [];
    }
    try {
      final List<dynamic> result = await _channel.invokeMethod('getAllCrashLogFiles');
      return result.cast<String>();
    } catch (e) {
      return [];
    }
  }

  /// 获取指定崩溃日志文件内容
  static Future<String> getCrashLogContent(String fileName) async {
    if (!Platform.isAndroid) {
      return '仅在Android平台可用';
    }
    try {
      final String result = await _channel.invokeMethod('getCrashLogContent', {
        'fileName': fileName,
      });
      return result;
    } catch (e) {
      return '读取崩溃日志失败: $e';
    }
  }
}
