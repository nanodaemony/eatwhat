# 地图页功能实现计划

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现地图页功能，包括定位用户位置、搜索周边2000米内餐馆、在地图和列表中展示结果。

**架构：** 使用 Flutter 高德地图插件（amap_flutter_map, amap_flutter_location, amap_flutter_search），通过 StatefulWidget 管理状态，地图和列表各占屏幕一半。

**技术栈：** Flutter, Dart, amap_flutter_map ^3.0.0, amap_flutter_location ^3.0.0, amap_flutter_search ^0.0.4, permission_handler ^11.3.1

---

## 文件结构

| 文件 | 职责 |
|------|------|
| `lib/map_page.dart` | 地图页主组件（修改现有文件） |
| `lib/services/location_service.dart` | 定位服务封装（新增） |
| `lib/services/poi_search_service.dart` | POI搜索服务封装（新增） |
| `lib/models/restaurant.dart` | 餐馆数据模型（新增） |
| `lib/widgets/restaurant_list_item.dart` | 餐馆列表项组件（新增） |
| `android/app/src/main/AndroidManifest.xml` | Android 权限和 API Key 配置（修改） |
| `ios/Runner/Info.plist` | iOS API Key 配置（修改） |

---

## Chunk 1: 项目配置和权限设置

### Task 1: 配置 Android 权限和 API Key

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml`

- [ ] **Step 1: 添加高德 API Key 和所需权限**

在 `<application>` 标签内添加：
```xml
<meta-data
    android:name="com.amap.api.v2.apikey"
    android:value="2ae92fdbb3c6f8b615b6d0ff483c95a4" />

<service android:name="com.amap.api.location.APSService" />
```

在 `<manifest>` 标签内添加权限（如不存在）：
```xml
<!-- 定位权限 -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />

<!-- 网络权限 -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />

<!-- 存储权限 -->
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
```

- [ ] **Step 2: 验证配置**

检查文件内容，确保没有重复权限声明。

- [ ] **Step 3: Commit**

```bash
git add android/app/src/main/AndroidManifest.xml
git commit -m "config(android): add AMap API key and location permissions"
```

---

### Task 2: 配置 iOS API Key

**Files:**
- Modify: `ios/Runner/Info.plist`

- [ ] **Step 1: 在 Info.plist 中添加高德 API Key**

在 `<dict>` 内添加：
```xml
<key>AMapApiKey</key>
<string>f8012fb518ecc1cecea2561897cb8cab</string>
```

- [ ] **Step 2: Commit**

```bash
git add ios/Runner/Info.plist
git commit -m "config(ios): add AMap API key"
```

---

## Chunk 2: 数据模型和服务层

### Task 3: 创建餐馆数据模型

**Files:**
- Create: `lib/models/restaurant.dart`

- [ ] **Step 1: 创建 Restaurant 模型类**

```dart
import 'package:amap_flutter_base/amap_flutter_base.dart';

/// 餐馆数据模型
class Restaurant {
  /// POI ID
  final String id;

  /// 餐馆名称
  final String name;

  /// 地址
  final String address;

  /// 经纬度
  final LatLng latLng;

  /// 距离（米）
  final int? distance;

  /// 评分（0-5）
  final double? rating;

  /// 人均消费（元）
  final int? averageCost;

  /// 电话
  final String? phone;

  /// 类型
  final String? type;

  const Restaurant({
    required this.id,
    required this.name,
    required this.address,
    required this.latLng,
    this.distance,
    this.rating,
    this.averageCost,
    this.phone,
    this.type,
  });

  /// 从 POI 搜索结果创建
  factory Restaurant.fromPoiItem(dynamic poiItem) {
    return Restaurant(
      id: poiItem.poiId ?? '',
      name: poiItem.title ?? '',
      address: poiItem.snippet ?? '',
      latLng: LatLng(
        poiItem.latLng?.latitude ?? 0.0,
        poiItem.latLng?.longitude ?? 0.0,
      ),
      distance: poiItem.distance,
      rating: poiItem.rating != null ? (poiItem.rating as num).toDouble() : null,
      averageCost: poiItem.averageCost,
      phone: poiItem.tel,
      type: poiItem.type,
    );
  }

  @override
  String toString() {
    return 'Restaurant(id: $id, name: $name, distance: $distance)';
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/models/restaurant.dart
git commit -m "feat(models): add Restaurant data model"
```

---

### Task 4: 创建定位服务

**Files:**
- Create: `lib/services/location_service.dart`

- [ ] **Step 1: 创建 LocationService 类**

```dart
import 'dart:async';

import 'package:amap_flutter_base/amap_flutter_base.dart';
import 'package:amap_flutter_location/amap_flutter_location.dart';
import 'package:amap_flutter_location/amap_location_option.dart';
import 'package:permission_handler/permission_handler.dart';

/// 定位结果回调
typedef LocationCallback = void Function(LatLng? position, String? error);

/// 定位服务封装
class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  final AMapFlutterLocation _location = AMapFlutterLocation();
  bool _isInitialized = false;

  /// 检查定位权限
  Future<bool> checkPermission() async {
    final status = await Permission.location.status;
    return status.isGranted;
  }

  /// 请求定位权限
  Future<bool> requestPermission() async {
    final status = await Permission.location.request();
    return status.isGranted;
  }

  /// 初始化定位
  void initialize() {
    if (_isInitialized) return;
    _location.setLocationApiKey(
      iOSKey: 'f8012fb518ecc1cecea2561897cb8cab',
      androidKey: '2ae92fdbb3c6f8b615b6d0ff483c95a4',
    );
    _isInitialized = true;
  }

  /// 获取单次定位
  Future<(LatLng?, String?)> getCurrentLocation() async {
    // 检查权限
    final hasPermission = await checkPermission();
    if (!hasPermission) {
      final granted = await requestPermission();
      if (!granted) {
        return (null, '定位权限被拒绝');
      }
    }

    initialize();

    // 设置定位选项
    final option = AMapLocationOption(
      locationMode: AMapLocationMode.Hight_Accuracy, // 高精度模式
      onceLocation: true, // 单次定位
      needAddress: true, // 需要地址信息
      geoLanguage: GeoLanguage.DEFAULT,
    );

    // 开始定位
    _location.setLocationOption(option);

    // 监听定位结果
    final completer = Completer<(LatLng?, String?)>();
    StreamSubscription? subscription;

    subscription = _location.onLocationChanged().listen((Map<String, Object> result) {
      subscription?.cancel();

      // 解析定位结果
      final code = result['code'] as int?;
      if (code != 0) {
        final errorInfo = result['errorInfo'] as String? ?? '定位失败';
        completer.complete((null, errorInfo));
        return;
      }

      final latitude = result['latitude'] as double?;
      final longitude = result['longitude'] as double?;

      if (latitude != null && longitude != null) {
        final position = LatLng(latitude, longitude);
        completer.complete((position, null));
      } else {
        completer.complete((null, '无法获取位置信息'));
      }
    });

    _location.startLocation();

    // 设置超时
    final result = await completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        subscription?.cancel();
        _location.stopLocation();
        return (null, '定位超时');
      },
    );

    _location.stopLocation();
    return result;
  }

  /// 销毁定位服务
  void dispose() {
    _location.stopLocation();
    _location.destroy();
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/services/location_service.dart
git commit -m "feat(services): add location service with permission handling"
```

---

### Task 5: 创建 POI 搜索服务

**Files:**
- Create: `lib/services/poi_search_service.dart`

- [ ] **Step 1: 创建 PoiSearchService 类**

```dart
import 'package:amap_flutter_base/amap_flutter_base.dart';
import 'package:amap_flutter_search/amap_flutter_search.dart';
import 'package:amap_flutter_search/models.dart';
import '../models/restaurant.dart';

/// POI 搜索服务封装
class PoiSearchService {
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
    try {
      // 创建搜索边界（周边搜索）
      final bound = PoiSearchBound(
        center: center,
        radius: radius,
      );

      // 执行搜索
      // 注意：根据 amap_flutter_search 实际 API 调整此处调用
      final result = await AmapSearch.poiSearch(
        keyword: '餐厅',
        bound: bound,
        pageSize: pageSize,
      );

      if (result == null) {
        return (null, '搜索失败');
      }

      // 解析结果
      final pois = result.poiList;
      if (pois == null || pois.isEmpty) {
        return (<Restaurant>[], null); // 空结果但不是错误
      }

      // 转换为 Restaurant 列表
      final restaurants = pois.map((poi) => Restaurant.fromPoiItem(poi)).toList();

      return (restaurants, null);
    } catch (e) {
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
      final bound = PoiSearchBound(
        center: center,
        radius: radius,
      );

      // 注意：根据 amap_flutter_search 实际 API 调整此处调用
      final result = await AmapSearch.poiSearch(
        keyword: keyword,
        bound: bound,
        pageSize: pageSize,
      );

      if (result == null) {
        return (null, '搜索失败');
      }

      final pois = result.poiList;
      if (pois == null || pois.isEmpty) {
        return (<Restaurant>[], null);
      }

      final restaurants = pois.map((poi) => Restaurant.fromPoiItem(poi)).toList();
      return (restaurants, null);
    } catch (e) {
      return (null, '搜索出错: $e');
    }
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/services/poi_search_service.dart
git commit -m "feat(services): add POI search service for nearby restaurants"
```

---

## Chunk 3: UI 组件

### Task 6: 创建餐馆列表项组件

**Files:**
- Create: `lib/widgets/restaurant_list_item.dart`

- [ ] **Step 1: 创建 RestaurantListItem 组件**

```dart
import 'package:flutter/material.dart';
import '../models/restaurant.dart';

/// 餐馆列表项组件
class RestaurantListItem extends StatelessWidget {
  final Restaurant restaurant;
  final bool isSelected;
  final VoidCallback onTap;

  const RestaurantListItem({
    super.key,
    required this.restaurant,
    required this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: isSelected ? 4 : 1,
      color: isSelected ? Colors.blue.shade50 : null,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 第一行：名称和评分/人均
              Row(
                children: [
                  Expanded(
                    child: Text(
                      restaurant.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (restaurant.rating != null)
                    Row(
                      children: [
                        const Icon(
                          Icons.star,
                          color: Colors.orange,
                          size: 16,
                        ),
                        Text(
                          '${restaurant.rating}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  if (restaurant.averageCost != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        '¥${restaurant.averageCost}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              // 第二行：距离和地址
              Row(
                children: [
                  Icon(
                    Icons.location_on,
                    color: Colors.grey.shade500,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${restaurant.distance != null ? '${restaurant.distance}米 · ' : ''}${restaurant.address}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/widgets/restaurant_list_item.dart
git commit -m "feat(widgets): add restaurant list item component"
```

---

## Chunk 4: 地图页主组件重构

### Task 7: 重构 MapPage 主组件

**Files:**
- Modify: `lib/map_page.dart`

- [ ] **Step 1: 完全重写 map_page.dart**

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:amap_flutter_map/amap_flutter_map.dart';
import 'package:amap_flutter_base/amap_flutter_base.dart';

import 'models/restaurant.dart';
import 'services/location_service.dart';
import 'services/poi_search_service.dart';
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

  // 状态
  bool _isLoading = true;
  bool _isSearching = false;
  String? _errorMessage;
  LatLng? _currentPosition;
  List<Restaurant> _restaurants = [];
  Restaurant? _selectedRestaurant;

  // 标记
  final Map<String, Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationService.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 处理应用生命周期变化
  }

  /// 初始化
  Future<void> _initialize() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // 获取当前位置
    final (position, error) = await _locationService.getCurrentLocation();

    if (error != null) {
      setState(() {
        _errorMessage = error;
        _isLoading = false;
      });
      return;
    }

    if (position != null) {
      setState(() {
        _currentPosition = position;
      });

      // 移动地图到当前位置
      _moveToPosition(position);

      // 搜索附近餐馆
      await _searchNearbyRestaurants(position);
    }

    setState(() {
      _isLoading = false;
    });
  }

  /// 移动地图到指定位置
  void _moveToPosition(LatLng position) {
    if (_mapController != null) {
      _mapController!.moveCamera(
        CameraUpdate.newLatLngZoom(position, 16), // 街道级缩放
      );
    }
  }

  /// 搜索附近餐馆
  Future<void> _searchNearbyRestaurants(LatLng position) async {
    setState(() {
      _isSearching = true;
    });

    final (restaurants, error) = await PoiSearchService.searchNearbyRestaurants(
      center: position,
      radius: 2000, // 2公里
    );

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
        title: restaurant.name,
        snippet: restaurant.address,
        icon: BitmapDescriptor.defaultMarkerWithHue(
          isSelected ? BitmapDescriptor.hueAzure : BitmapDescriptor.hueRed,
        ),
        infoWindowEnabled: true,
      );
      _markers[restaurant.id] = marker;
    }

    setState(() {});
  }

  /// 重新定位
  Future<void> _relocation() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final (position, error) = await _locationService.getCurrentLocation();

    if (error != null) {
      setState(() {
        _errorMessage = error;
        _isLoading = false;
      });
      return;
    }

    if (position != null) {
      setState(() {
        _currentPosition = position;
      });
      _moveToPosition(position);
      await _searchNearbyRestaurants(position);
    }

    setState(() {
      _isLoading = false;
    });
  }

  /// 选择餐馆
  void _selectRestaurant(Restaurant restaurant) {
    setState(() {
      _selectedRestaurant = restaurant;
    });

    // 更新标记颜色（选中的变为蓝色）
    _addRestaurantMarkers();

    // 移动地图到该餐馆位置
    _moveToPosition(restaurant.latLng);

    // 显示标记信息
    final marker = _markers[restaurant.id];
    if (marker != null && _mapController != null) {
      _mapController!.showMarkerInfoWindow(marker);
    }
  }

  /// 打开设置
  Future<void> _openSettings() async {
    await _locationService.requestPermission();
    // 重新尝试定位
    _relocation();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('附近餐馆'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
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
                    onPressed: _isLoading ? null : _relocation,
                    child: const Icon(Icons.my_location),
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
    );
  }

  /// 构建地图
  Widget _buildMap() {
    final initialPosition = _currentPosition ??
        const LatLng(39.909187, 116.397451); // 默认北京天安门

    return AMapWidget(
      initialCameraPosition: CameraPosition(
        target: initialPosition,
        zoom: 16,
      ),
      onMapCreated: (controller) {
        _mapController = controller;
        if (_currentPosition != null) {
          _moveToPosition(_currentPosition!);
        }
      },
      markers: Set<Marker>.of(_markers.values),
      myLocationEnabled: true, // 显示我的位置
      myLocationButtonEnabled: false, // 隐藏默认定位按钮（使用自定义）
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

    // 空状态
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
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/map_page.dart
git commit -m "feat(map): implement full map page with location and restaurant search"
```

---

## Chunk 5: 测试和验证

### Task 8: 验证 pubspec.yaml 依赖

**Files:**
- Check: `pubspec.yaml`

- [ ] **Step 1: 确认依赖项已配置**

```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8

  # 高德地图 SDK
  amap_flutter_map: ^3.0.0
  amap_flutter_location: ^3.0.0
  amap_flutter_search: ^0.0.4
  permission_handler: ^11.3.1
```

如未配置，添加这些依赖并运行：

```bash
flutter pub get
```

- [ ] **Step 2: Commit**（如有修改）

```bash
git add pubspec.yaml pubspec.lock
git commit -m "config(deps): ensure AMap dependencies are configured"
```

---

### Task 9: 运行 Flutter 分析

- [ ] **Step 1: 检查代码问题**

```bash
cd /Users/nano/claude/eatwhat/eatwhat
flutter analyze
```

**Expected:** 无错误，无警告（或仅显示无关警告）

- [ ] **Step 2: 修复任何问题**

如有错误，修复后重新运行分析。

---

### Task 10: 测试构建

- [ ] **Step 1: 测试 Android 构建**

```bash
cd /Users/nano/claude/eatwhat/eatwhat
flutter build apk --debug
```

**Expected:** 构建成功

- [ ] **Step 2: 测试 iOS 构建**（在 Mac 上）

```bash
cd /Users/nano/claude/eatwhat/eatwhat
flutter build ios --debug --no-codesign
```

**Expected:** 构建成功

---

## 验证清单

实现完成后，验证以下功能：

- [ ] 首页"进入地图"按钮可正常跳转到地图页
- [ ] 进入地图页自动请求定位权限
- [ ] 定位成功后地图移动到当前位置
- [ ] 地图下方显示附近餐馆列表
- [ ] 点击列表项地图移动到该餐馆位置
- [ ] 点击"定位到我"按钮回到当前位置
- [ ] 下拉列表可刷新搜索结果
- [ ] 定位失败显示错误提示和重试按钮
- [ ] 搜索无结果显示空状态

---

## 参考文档

- 设计文档: `docs/superpowers/specs/2025-03-16-map-page-design.md`
- Android 定位 Demo: `/Users/nano/claude/amap/AMap_Android_Demo/AMap_Android_API_Location_Demo/`
- Android POI 搜索 Demo: `/Users/nano/claude/amap/AMap_Android_Demo/AMap_Android_API_3DMap_Demo/`
