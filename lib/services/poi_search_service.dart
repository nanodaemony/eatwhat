import 'package:flutter/foundation.dart';
import 'package:amap_flutter_base/amap_flutter_base.dart';
import 'package:amap_flutter_search/amap_flutter_search.dart' as amap_search;

import '../models/restaurant.dart';
import 'logger_service.dart';

/// Android Key 配置
const _androidDebugKey = '15ee4db9898582c0c65ac116d92b18d5';
const _androidReleaseKey = '2ae92fdbb3c6f8b615b6d0ff483c95a4';
const _iosKey = 'f8012fb518ecc1cecea2561897cb8cab';

/// 获取当前环境的 Android Key
String get _androidKey => kReleaseMode ? _androidReleaseKey : _androidDebugKey;

/// POI 搜索服务封装
class PoiSearchService {
  static bool _isInitialized = false;
  static final _logger = Logger();

  /// 初始化搜索 SDK
  static void _initialize() {
    if (_isInitialized) {
      _logger.log('PoiSearchService', '搜索服务已初始化，跳过');
      return;
    }

    _logger.log('PoiSearchService', '开始初始化搜索服务...');

    // 设置搜索 SDK 的 API Key（根据 DEBUG/Release 模式自动切换）
    _logger.log('PoiSearchService', '设置搜索 API Key... [${kReleaseMode ? "Release" : "Debug"}模式]');
    amap_search.AmapFlutterSearch.setApiKey(
      _androidKey, // 自动切换 Debug/Release Key
      _iosKey,
    );
    _logger.log('PoiSearchService', '搜索 API Key 设置完成');

    // 设置隐私合规（必须先设置才能使用搜索功能）
    _logger.log('PoiSearchService', '设置隐私合规声明...');
    amap_search.AmapFlutterSearch.updatePrivacyShow(true, true);
    amap_search.AmapFlutterSearch.updatePrivacyAgree(true);
    _logger.log('PoiSearchService', '隐私合规声明设置完成');

    _isInitialized = true;
    _logger.log('PoiSearchService', '搜索服务初始化完成');
  }
  /// 搜索周边餐馆
  ///
  /// [center] 搜索中心点
  /// [radius] 搜索半径（米），默认 2000
  /// [pageSize] 每页数量，默认 20
  static Future<(List<Restaurant>?, String?)> searchNearbyRestaurants({
    required LatLng center,
    int radius = 2000,
    int pageSize = 20,
  }) async {
    _logger.log('PoiSearchService', '=== 开始搜索附近餐馆 ===');
    _logger.log('PoiSearchService', '搜索参数: center=$center, radius=$radius, pageSize=$pageSize');

    try {
      // 初始化搜索 SDK
      _initialize();

      // 创建搜索中心点（使用 amap_flutter_search 的 Location 类）
      _logger.log('PoiSearchService', '创建搜索中心点: lat=${center.latitude}, lng=${center.longitude}');
      final location = amap_search.Location(
        latitude: center.latitude,
        longitude: center.longitude,
      );

      // 执行周边搜索
      _logger.log('PoiSearchService', '开始执行周边搜索，关键词: "餐厅"');
      final results = await amap_search.AmapFlutterSearch.searchAround(
        location,
        keyword: '餐厅',
        pageSize: pageSize,
        page: 1,
        radius: radius,
      );

      _logger.log('PoiSearchService', '搜索完成，返回 ${results.length} 条结果');

      // 转换为 Restaurant 列表
      final restaurants = results.map((poi) => _convertToRestaurant(poi)).toList();
      _logger.log('PoiSearchService', '转换为 ${restaurants.length} 个 Restaurant 对象');

      // 记录前几个结果
      if (restaurants.isNotEmpty) {
        _logger.log('PoiSearchService', '前3个结果:');
        for (var i = 0; i < restaurants.length && i < 3; i++) {
          _logger.log('PoiSearchService', '  [${i + 1}] ${restaurants[i].name} - ${restaurants[i].address}');
        }
      } else {
        _logger.warn('PoiSearchService', '⚠️ 搜索结果为空');
      }

      _logger.log('PoiSearchService', '=== 搜索流程结束 ===');
      return (restaurants, null);
    } catch (e, stackTrace) {
      _logger.error('PoiSearchService', '❌ 搜索发生异常', e, stackTrace);
      return (null, '搜索出错: $e');
    }
  }

  /// 根据关键词搜索
  static Future<(List<Restaurant>?, String?)> searchByKeyword({
    required String keyword,
    required LatLng center,
    int radius = 2000,
    int pageSize = 20,
  }) async {
    try {
      // 初始化搜索 SDK
      _initialize();

      final location = amap_search.Location(
        latitude: center.latitude,
        longitude: center.longitude,
      );

      final results = await amap_search.AmapFlutterSearch.searchAround(
        location,
        keyword: keyword,
        pageSize: pageSize,
        page: 1,
        radius: radius,
      );

      final restaurants = results.map((poi) => _convertToRestaurant(poi)).toList();
      return (restaurants, null);
    } catch (e) {
      return (null, '搜索出错: $e');
    }
  }

  /// 将 AMapPoi 转换为 Restaurant
  static Restaurant _convertToRestaurant(amap_search.AMapPoi poi) {
    return Restaurant(
      id: '${poi.name}_${poi.location?.latitude}_${poi.location?.longitude}',
      name: poi.name ?? '未知餐馆',
      address: poi.address ?? '',
      latLng: LatLng(
        poi.location?.latitude ?? 0.0,
        poi.location?.longitude ?? 0.0,
      ),
      distance: poi.distance,
      rating: null, // AMapPoi 没有评分字段
      averageCost: null, // AMapPoi 没有人均消费字段
      phone: null,
      type: poi.parkingType,
    );
  }
}
