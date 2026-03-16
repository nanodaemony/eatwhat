import 'dart:async';

import 'package:flutter/material.dart';
import 'package:amap_flutter_map/amap_flutter_map.dart';
import 'package:amap_flutter_base/amap_flutter_base.dart';

import 'models/restaurant.dart';
import 'services/location_service.dart';
import 'services/poi_search_service.dart';
import 'services/logger_service.dart';
import 'services/native_crash_log_service.dart';
import 'widgets/restaurant_list_item.dart';

/// 地图页
class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> with WidgetsBindingObserver {
  // 地图控制器
  AMapController? _mapController;

  // 定位服务
  final LocationService _locationService = LocationService();

  // 日志服务
  final Logger _logger = Logger();

  // 状态
  bool _isLoading = true;
  bool _isSearching = false;
  bool _isLocating = false; // 是否正在定位中
  String? _errorMessage;
  LatLng? _currentPosition;
  List<Restaurant> _restaurants = [];
  Restaurant? _selectedRestaurant;

  // 标记
  final Map<String, Marker> _markers = {};

  // 定位取消标志
  bool _locationCancelled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  @override
  void deactivate() {
    _logger.log('MapPage', '=== deactivate 开始 ===');
    // 在deactivate时就清理资源，防止dispose时崩溃
    _locationCancelled = true;
    _isLocating = false;
    _logger.log('MapPage', 'deactivate: 定位状态已清理');

    super.deactivate();
    _logger.log('MapPage', '=== deactivate 结束 ===');
  }

  @override
  void dispose() {
    _logger.log('MapPage', '=== dispose 开始 ===');

    WidgetsBinding.instance.removeObserver(this);
    _logger.log('MapPage', 'dispose: 生命周期观察者已移除');

    // 清除标记引用
    _markers.clear();
    _logger.log('MapPage', 'dispose: 标记已清除');

    // 重要：不要手动dispose地图控制器
    // AMapWidget会在自己的dispose中处理
    _mapController = null;
    _logger.log('MapPage', 'dispose: 地图控制器引用已清除');

    _logger.log('MapPage', 'dispose: 调用 super.dispose()...');
    super.dispose();
    _logger.log('MapPage', '=== dispose 结束 ===');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 处理应用生命周期变化
  }

  /// 初始化
  Future<void> _initialize() async {
    _logger.log('MapPage', '=== 地图页初始化开始 ===');

    // 初始化日志服务
    await _logger.initialize();
    _logger.log('MapPage', '日志服务初始化完成，日志文件: ${_logger.logFilePath}');

    // 注意：不自动开始定位，等待地图创建完成后由用户触发
    // 这样可以避免 GPS 冷启动超时问题
    _logger.log('MapPage', '等待地图创建完成...');
  }

  /// 开始定位（用户触发）
  Future<void> _startLocation() async {
    if (!mounted) return;

    // 防止重复点击
    if (_isLocating) {
      _logger.log('MapPage', '定位已在进行中，忽略重复点击');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('定位进行中，请稍候...'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _isLocating = true;
      _errorMessage = null;
    });

    await _getLocationAndSearch();
  }

  /// 获取位置并搜索
  Future<void> _getLocationAndSearch() async {
    _logger.log('MapPage', '开始获取当前位置...');
    final (position, error) = await _locationService.getCurrentLocation();

    // 检查是否已被取消（页面关闭或重新定位）
    if (_locationCancelled) {
      _logger.log('MapPage', '定位请求已取消，忽略结果');
      return;
    }

    if (error != null) {
      _logger.error('MapPage', '获取位置失败', error);
      if (mounted) {
        setState(() {
          _errorMessage = error;
          _isLoading = false;
          _isLocating = false;
        });
      }
      return;
    }

    if (position != null) {
      _logger.log('MapPage', '获取到位置: $position');
      if (mounted) {
        setState(() {
          _currentPosition = position;
          _isLoading = false;
          _isLocating = false;
        });
      }

      // 移动地图到当前位置
      _moveToPosition(position);

      // 搜索附近餐馆
      await _searchNearbyRestaurants(position);
    }
  }

  /// 移动地图到指定位置
  void _moveToPosition(LatLng position) {
    if (!mounted) return;
    if (_mapController != null) {
      _logger.log('MapPage', '移动地图到: $position');
      _mapController!.moveCamera(
        CameraUpdate.newLatLngZoom(position, 16), // 街道级缩放
      );
    } else {
      _logger.log('MapPage', '地图控制器未就绪，跳过移动');
    }
  }

  /// 搜索附近餐馆
  Future<void> _searchNearbyRestaurants(LatLng position) async {
    if (!mounted) return;
    setState(() {
      _isSearching = true;
    });

    final (restaurants, error) = await PoiSearchService.searchNearbyRestaurants(
      center: position,
      radius: 2000, // 2公里
    );

    if (!mounted) return;

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('搜索失败: $error')),
      );
      setState(() {
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _restaurants = restaurants ?? [];
      _isSearching = false;
    });

    // 在地图上添加标记
    _addRestaurantMarkers();
  }

  /// 添加餐馆标记
  void _addRestaurantMarkers() {
    if (_mapController == null) return;

    // 清除旧标记
    _markers.clear();

    // 添加餐馆标记
    for (var i = 0; i < _restaurants.length; i++) {
      final restaurant = _restaurants[i];
      final isSelected = _selectedRestaurant?.id == restaurant.id;
      final marker = Marker(
        position: restaurant.latLng,
        infoWindow: InfoWindow(
          title: restaurant.name,
          snippet: restaurant.address,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          isSelected ? BitmapDescriptor.hueAzure : BitmapDescriptor.hueRed,
        ),
        infoWindowEnable: true,
      );
      _markers[restaurant.id] = marker;
    }

    if (!mounted) return;
    setState(() {});
  }

  /// 重新定位
  Future<void> _relocation() async {
    // 如果正在定位，先取消
    if (_isLocating) {
      _logger.log('MapPage', '取消之前的定位请求');
      _locationCancelled = true;
      // 短暂延迟后重置标志，允许新的定位请求
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
      _locationCancelled = false;
    }

    setState(() {
      _isLoading = true;
      _isLocating = true;
      _errorMessage = null;
    });

    await _getLocationAndSearch();
  }

  /// 选择餐馆
  void _selectRestaurant(Restaurant restaurant) {
    if (!mounted) return;
    setState(() {
      _selectedRestaurant = restaurant;
    });

    // 更新标记颜色（选中的变为蓝色）
    _addRestaurantMarkers();

    // 移动地图到该餐馆位置
    _moveToPosition(restaurant.latLng);

    // 注意：amap_flutter_map 3.0.0 没有 showMarkerInfoWindow 方法
    // 标记更新后会自动显示其 infoWindow
  }

  /// 打开设置
  Future<void> _openSettings() async {
    await _locationService.requestPermission();
    // 重新尝试定位
    _relocation();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _logger.log('MapPage', '用户点击返回，准备退出地图页...');
        // 先清理地图资源
        _mapController = null;
        _markers.clear();
        // 给地图SDK时间清理GL资源
        await Future.delayed(const Duration(milliseconds: 300));
        _logger.log('MapPage', '延迟完成，允许退出');
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('附近餐馆'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          actions: [
            // 查看Native崩溃日志按钮
            IconButton(
              icon: const Icon(Icons.bug_report),
              tooltip: '查看崩溃日志',
              onPressed: _showNativeCrashLogViewer,
            ),
            // 查看日志按钮
            IconButton(
              icon: const Icon(Icons.article),
              tooltip: '查看日志',
              onPressed: _showLogViewer,
            ),
            if (_isSearching)
              const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
          ],
        ),
        body: Column(
        children: [
          // 地图区域（上半部分）
          Expanded(
            flex: 1,
            child: Stack(
              children: [
                // 地图
                _buildMap(),

                // 定位按钮
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: FloatingActionButton(
                    mini: true,
                    onPressed: (_isLoading || _isLocating) ? null : _relocation,
                    child: _isLocating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.my_location),
                  ),
                ),

                // 加载指示器
                if (_isLoading)
                  Container(
                    color: Colors.black26,
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
              ],
            ),
          ),

          // 餐馆列表（下半部分）
          Expanded(
            flex: 1,
            child: _buildRestaurantList(),
          ),
        ],
      ),
    ),
  );
}

  /// 构建地图
  Widget _buildMap() {
    final initialPosition = _currentPosition ??
        const LatLng(39.909187, 116.397451); // 默认北京天安门

    return RepaintBoundary(
      child: AMapWidget(
        // 高德隐私合规声明（必须设置，否则地图白屏）
        privacyStatement: const AMapPrivacyStatement(
          hasContains: true, // 隐私权政策已包含高德隐私政策
          hasShow: true, // 已弹窗展示给用户
          hasAgree: true, // 已取得用户同意
        ),
        initialCameraPosition: CameraPosition(
          target: initialPosition,
          zoom: 16,
        ),
        onMapCreated: (controller) {
          _logger.log('MapPage', '地图创建完成');
          _mapController = controller;

          // 地图创建完成后，自动开始定位
          _logger.log('MapPage', '地图已就绪，自动开始定位...');
          _startLocation();
        },
        markers: Set<Marker>.of(_markers.values),
        myLocationStyleOptions: MyLocationStyleOptions(
          true, // 显示我的位置
        ),
      ),
    );
  }

  /// 构建餐馆列表
  Widget _buildRestaurantList() {
    // 显示错误
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.location_off,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _relocation,
              child: const Text('重试定位'),
            ),
            if (_errorMessage!.contains('权限'))
              TextButton(
                onPressed: _openSettings,
                child: const Text('去设置'),
              ),
          ],
        ),
      );
    }

    // 空状态 - 尚未定位
    if (_restaurants.isEmpty && !_isSearching && _currentPosition == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.location_searching,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              '点击定位按钮开始搜索附近餐馆',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              '首次定位可能需要 30-60 秒（GPS冷启动）',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              '请耐心等待，不要重复点击',
              style: TextStyle(color: Colors.orange.shade600, fontSize: 12),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isLocating ? null : _startLocation,
              icon: _isLocating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location),
              label: Text(_isLocating ? '定位中...' : '开始定位'),
            ),
          ],
        ),
      );
    }

    // 空状态 - 已定位但没有找到餐馆
    if (_restaurants.isEmpty && !_isSearching) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.restaurant,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              '附近没有找到餐馆',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                if (_currentPosition != null) {
                  _searchNearbyRestaurants(_currentPosition!);
                }
              },
              child: const Text('重新搜索'),
            ),
          ],
        ),
      );
    }

    // 餐馆列表
    return RefreshIndicator(
      onRefresh: () async {
        if (_currentPosition != null) {
          await _searchNearbyRestaurants(_currentPosition!);
        }
      },
      child: ListView.builder(
        itemCount: _restaurants.length,
        itemBuilder: (context, index) {
          final restaurant = _restaurants[index];
          return RestaurantListItem(
            restaurant: restaurant,
            isSelected: _selectedRestaurant?.id == restaurant.id,
            onTap: () => _selectRestaurant(restaurant),
          );
        },
      ),
    );
  }

  /// 显示日志查看器
  void _showLogViewer() async {
    final logs = await _logger.readAllLogs();
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('应用日志'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: SingleChildScrollView(
            child: SelectableText(
              logs,
              style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await _logger.clear();
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
            },
            child: const Text('清除日志'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  /// 显示Native崩溃日志查看器
  void _showNativeCrashLogViewer() async {
    final logs = await NativeCrashLogService.getNativeCrashLog();
    final files = await NativeCrashLogService.getAllCrashLogFiles();
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('崩溃日志'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: Column(
            children: [
              // 崩溃日志文件列表
              if (files.isNotEmpty) ...[
                const Text('崩溃日志文件:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: files.take(5).map((file) => ElevatedButton(
                    onPressed: () async {
                      final content = await NativeCrashLogService.getCrashLogContent(file);
                      if (dialogContext.mounted) {
                        showDialog(
                          context: dialogContext,
                          builder: (ctx) => AlertDialog(
                            title: Text(file),
                            content: SizedBox(
                              width: double.maxFinite,
                              height: 300,
                              child: SingleChildScrollView(
                                child: SelectableText(
                                  content,
                                  style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                                ),
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(),
                                child: const Text('关闭'),
                              ),
                            ],
                          ),
                        );
                      }
                    },
                    child: Text(file.substring(7, 19)), // 显示时间部分
                  )).toList(),
                ),
                const Divider(),
              ],
              // 实时Native日志
              const Text('实时Native日志监控:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  child: SelectableText(
                    logs,
                    style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}
