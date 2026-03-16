import 'dart:async';
import 'package:flutter/foundation.dart';

import 'package:amap_flutter_base/amap_flutter_base.dart';
import 'package:amap_flutter_location/amap_flutter_location.dart';
import 'package:amap_flutter_location/amap_location_option.dart';
import 'package:permission_handler/permission_handler.dart';

import 'logger_service.dart';

/// Android Key 配置
const _androidDebugKey = '15ee4db9898582c0c65ac116d92b18d5';
const _androidReleaseKey = '2ae92fdbb3c6f8b615b6d0ff483c95a4';
const _iosKey = 'f8012fb518ecc1cecea2561897cb8cab';

/// 获取当前环境的 Android Key
String get _androidKey => kReleaseMode ? _androidReleaseKey : _androidDebugKey;

/// 定位结果回调
typedef LocationCallback = void Function(LatLng? position, String? error);

/// 定位服务封装
class LocationService {
  static bool _isInitialized = false;
  static final _logger = Logger();

  /// 检查定位权限
  Future<bool> checkPermission() async {
    _logger.log('LocationService', '检查定位权限...');
    final status = await Permission.location.status;
    _logger.log('LocationService', '定位权限状态: $status');
    return status.isGranted;
  }

  /// 请求定位权限
  Future<bool> requestPermission() async {
    _logger.log('LocationService', '请求定位权限...');
    final status = await Permission.location.request();
    _logger.log('LocationService', '权限请求结果: $status');
    return status.isGranted;
  }

  /// 初始化定位（静态方法，只需调用一次）
  static void initialize() {
    if (_isInitialized) {
      _logger.log('LocationService', '定位服务已初始化，跳过');
      return;
    }

    _logger.log('LocationService', '开始初始化定位服务...');

    // 设置高德隐私合规声明（必须在调用定位功能前设置）
    _logger.log('LocationService', '设置隐私合规声明...');
    AMapFlutterLocation.updatePrivacyShow(true, true);
    AMapFlutterLocation.updatePrivacyAgree(true);
    _logger.log('LocationService', '隐私合规声明设置完成');

    // 使用静态方法设置 API Key（根据 DEBUG/Release 模式自动切换）
    _logger.log('LocationService', '设置定位 API Key... [${kReleaseMode ? "Release" : "Debug"}模式]');
    AMapFlutterLocation.setApiKey(
      _androidKey, // 自动切换 Debug/Release Key
      _iosKey,
    );
    _logger.log('LocationService', '定位 API Key 设置完成');
    _isInitialized = true;
    _logger.log('LocationService', '定位服务初始化完成');
  }

  /// 获取单次定位（带自动重试）
  Future<(LatLng?, String?)> getCurrentLocation({int retryCount = 1}) async {
    _logger.log('LocationService', '=== 开始获取当前位置 (剩余重试: $retryCount) ===');

    // 检查权限
    final hasPermission = await checkPermission();
    if (!hasPermission) {
      _logger.log('LocationService', '定位权限未授予，请求权限...');
      final granted = await requestPermission();
      if (!granted) {
        _logger.error('LocationService', '定位权限被拒绝');
        return (null, '定位权限被拒绝');
      }
    }
    _logger.log('LocationService', '定位权限已获取');

    // 确保已初始化
    initialize();

    // 尝试定位
    final result = await _doLocation();

    // 处理快速失败情况 - 监听器未建立好，立即重试
    if (result.$2 == '__QUICK_FAIL__') {
      _logger.log('LocationService', '检测到监听器未就绪，立即快速重试...');
      return await getCurrentLocation(retryCount: retryCount); // 不减retryCount，因为这是技术重试不是业务重试
    }

    // 如果失败且还有重试次数，则延迟重试
    if (result.$2 != null && retryCount > 0) {
      _logger.log('LocationService', '首次定位失败，2秒后重试...');
      await Future.delayed(const Duration(seconds: 2));
      return await getCurrentLocation(retryCount: retryCount - 1);
    }

    _logger.log('LocationService', '=== 定位流程结束 ===');
    return result;
  }

  /// 执行单次定位
  Future<(LatLng?, String?)> _doLocation() async {
    // 每次创建新的定位实例（避免流重复监听问题）
    _logger.log('LocationService', '创建 AMapFlutterLocation 实例...');
    final location = AMapFlutterLocation();

    // 设置定位选项 - 使用低功耗模式先快速获取粗略位置
    _logger.log('LocationService', '设置定位选项: 低功耗模式, 单次定位');
    final option = AMapLocationOption(
      locationMode: AMapLocationMode.Battery_Saving, // 低功耗模式，使用网络定位
      onceLocation: true, // 单次定位
      needAddress: true, // 需要地址信息
      geoLanguage: GeoLanguage.DEFAULT,
    );

    // 开始定位
    location.setLocationOption(option);
    _logger.log('LocationService', '定位选项已设置，准备开始定位...');

    // 监听定位结果
    final completer = Completer<(LatLng?, String?)>();
    StreamSubscription? subscription;
    var hasReceivedCallback = false; // 标记是否收到过任何回调

    subscription = location.onLocationChanged().listen((Map<String, Object> result) {
      hasReceivedCallback = true; // 标记收到回调
      _logger.log('LocationService', '收到定位回调数据');
      _logger.log('LocationService', '定位原始数据: $result');

      subscription?.cancel();

      // 解析定位结果
      final errorCode = result['errorCode'] as int?;
      _logger.log('LocationService', '解析 errorCode: $errorCode');

      if (errorCode != null && errorCode != 0) {
        final errorInfo = result['errorInfo'] as String? ?? '定位失败';
        _logger.error('LocationService', '定位失败', 'errorCode=$errorCode, errorInfo=$errorInfo');
        location.stopLocation();
        location.destroy();
        completer.complete((null, errorInfo));
        return;
      }

      final latitude = result['latitude'] as double?;
      final longitude = result['longitude'] as double?;
      _logger.log('LocationService', '解析经纬度: lat=$latitude, lng=$longitude');

      if (latitude != null && longitude != null) {
        final position = LatLng(latitude, longitude);
        _logger.log('LocationService', '✅ 定位成功: $position');
        location.stopLocation();
        location.destroy();
        completer.complete((position, null));
      } else {
        _logger.error('LocationService', '❌ 无法获取经纬度信息');
        location.stopLocation();
        location.destroy();
        completer.complete((null, '无法获取位置信息'));
      }
    }, onError: (e) {
      hasReceivedCallback = true;
      _logger.error('LocationService', '定位流发生错误', e);
      subscription?.cancel();
      location.stopLocation();
      location.destroy();
      if (!completer.isCompleted) {
        completer.complete((null, '定位发生错误: $e'));
      }
    });

    // 关键修复：使用双层超时机制
    // 第一层：快速检测（1秒）- 如果1秒内没有收到任何回调，说明监听器没建立好，快速失败
    // 第二层：正常定位超时（60秒）- 给GPS冷启动时间
    _logger.log('LocationService', '开始定位...');
    location.startLocation();
    _logger.log('LocationService', '设置快速检测超时: 1秒');
    final quickCheckResult = await completer.future.timeout(
      const Duration(seconds: 1),
      onTimeout: () {
        if (!hasReceivedCallback) {
          // 1秒内没有任何回调，说明监听器没建立好
          _logger.error('LocationService', '❌ 快速检测失败：1秒内未收到回调，监听器可能未建立');
          subscription?.cancel();
          location.stopLocation();
          location.destroy();
          return (null, '__QUICK_FAIL__'); // 特殊标记，表示需要快速重试
        }
        // 已经有回调了，但可能还在处理中，继续等待
        return (null, '__CONTINUE__');
      },
    );

    // 如果是快速失败标记，立即返回让上层重试
    if (quickCheckResult.$2 == '__QUICK_FAIL__') {
      return (null, '__QUICK_FAIL__');
    }

    // 如果已经有结果了（成功或失败），直接返回
    if (quickCheckResult.$2 != '__CONTINUE__') {
      return quickCheckResult;
    }

    // 收到回调但还没完成（继续等待完整结果）
    _logger.log('LocationService', '已收到回调，继续等待完整定位结果...');
    final timeoutResult = await completer.future.timeout(
      const Duration(seconds: 55), // 剩余55秒
      onTimeout: () {
        _logger.error('LocationService', '❌ 定位超时 (60秒)');
        subscription?.cancel();
        location.stopLocation();
        location.destroy();
        return (null, '定位超时，请重试');
      },
    );

    return timeoutResult;
  }
}
