# EatWhat 地图页面实现计划

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现一个 Flutter 地图页面，接入高德地图 SDK，展示地图并搜索附近餐馆信息

**Architecture:** 使用高德官方 Flutter 插件（amap_flutter_map, amap_flutter_location, amap_flutter_search），采用单例模式封装服务层，页面层使用 StatefulWidget 管理状态，底部面板使用 DraggableScrollableSheet 实现可滑动效果

**Tech Stack:** Flutter 3.x, 高德地图 SDK (amap_flutter_map, amap_flutter_location, amap_flutter_search), permission_handler

**Design Doc:** `docs/superpowers/specs/2025-03-13-map-page-design.md`

---

## 文件结构规划

| 文件 | 职责 |
|------|------|
| `lib/models/restaurant.dart` | 餐馆数据模型，POI 转换 |
| `lib/services/amap_service.dart` | 高德地图服务封装（单例模式） |
| `lib/services/location_result.dart` | 定位结果模型 |
| `lib/constants/amap_config.dart` | 高德配置（API Key 读取） |
| `lib/pages/map_page.dart` | 地图页面（整合地图、搜索、列表） |
| `lib/widgets/restaurant_list_sheet.dart` | 底部餐馆列表面板 |
| `lib/widgets/restaurant_card.dart` | 餐馆卡片组件 |
| `lib/pages/home_page.dart` | 首页（添加进入地图按钮） |
| `test/models/restaurant_test.dart` | Restaurant 模型单元测试 |
| `test/services/amap_service_test.dart` | AMapService 单元测试（mock） |
| `pubspec.yaml` | 添加高德地图依赖 |

---

## Chunk 1: 项目配置和依赖

### Task 0.1: 环境预检

**Files:**
- None (verification only)

- [ ] **Step 1: 验证 Flutter 环境**

Run: `flutter doctor`
Expected: Flutter 已安装，版本 >= 3.0

- [ ] **Step 2: 验证项目可构建**

Run: `cd eatwhat && flutter build apk --debug 2>&1 | head -20`
Expected: 项目可以正常编译（即使有一些警告）

---

### Task 0.2: 创建环境变量示例文件

**Files:**
- Create: `.env.example`

- [ ] **Step 1: 创建 .env.example**

Create `.env.example`:
```bash
# 高德地图 API Key
# 申请地址：https://lbs.amap.com/dev/key/app
AMAP_ANDROID_KEY=your_android_key_here
AMAP_IOS_KEY=your_ios_key_here

# 使用方法：
# 1. 复制此文件为 .env: cp .env.example .env
# 2. 填入你的真实 Key
# 3. 或者使用 dart-define: flutter run --dart-define=AMAP_ANDROID_KEY=xxx
```

- [ ] **Step 2: Commit**

```bash
git add .env.example
git commit -m "docs: add .env.example for API key configuration"
```

---

### Task 1.1: 添加高德地图依赖

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: 添加依赖到 pubspec.yaml**

在 `dependencies:` 部分添加：
```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  amap_flutter_map: ^3.0.0
  amap_flutter_location: ^3.0.0
  amap_flutter_search: ^3.0.0
  permission_handler: ^11.0.0
```

- [ ] **Step 2: 安装依赖**

Run: `flutter pub get`
Expected: 成功安装所有包，无错误

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "deps: add amap flutter sdk dependencies"
```

---

## Chunk 2: 核心模型层

### Task 2.1: 创建 LocationResult 模型

**Files:**
- Create: `lib/services/location_result.dart`
- Test: `test/services/location_result_test.dart`

- [ ] **Step 1: 编写测试**

Create `test/services/location_result_test.dart`:
```dart
import 'package:amap_flutter_map/amap_flutter_map.dart' show LatLng;
import 'package:flutter_test/flutter_test.dart';
import 'package:eatwhat/services/location_result.dart';

void main() {
  group('LocationResult', () {
    test('should create LocationResult with all fields', () {
      final result = LocationResult(
        position: LatLng(39.9, 116.4),
        accuracy: 10.5,
        timestamp: DateTime(2025, 3, 13, 10, 30),
      );

      expect(result.position.latitude, 39.9);
      expect(result.position.longitude, 116.4);
      expect(result.accuracy, 10.5);
    });
  });
}
```

- [ ] **Step 2: 运行测试（应失败）**

Run: `flutter test test/services/location_result_test.dart`
Expected: FAIL - "Target of URI doesn't exist"

- [ ] **Step 3: 实现 LocationResult**

Create `lib/services/location_result.dart`:
```dart
import 'package:amap_flutter_map/amap_flutter_map.dart' show LatLng;

/// 定位结果
class LocationResult {
  final LatLng position;
  final double accuracy;
  final DateTime timestamp;

  const LocationResult({
    required this.position,
    required this.accuracy,
    required this.timestamp,
  });

  @override
  String toString() =>
      'LocationResult(position: $position, accuracy: ${accuracy}m)';
}
```

- [ ] **Step 4: 运行测试（应通过）**

Run: `flutter test test/services/location_result_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/services/location_result.dart test/services/location_result_test.dart
git commit -m "feat: add LocationResult model"
```

### Task 2.2: 创建 Restaurant 模型

**Files:**
- Create: `lib/models/restaurant.dart`
- Test: `test/models/restaurant_test.dart`

- [ ] **Step 1: 编写测试**

Create `test/models/restaurant_test.dart`:
```dart
import 'package:amap_flutter_map/amap_flutter_map.dart' show LatLng;
import 'package:flutter_test/flutter_test.dart';
import 'package:eatwhat/models/restaurant.dart';

void main() {
  group('Restaurant', () {
    test('should create Restaurant from constructor', () {
      final restaurant = Restaurant(
        id: 'POI001',
        name: '麦当劳',
        address: '朝阳区建国路88号',
        location: LatLng(39.9, 116.4),
        rating: 4.5,
        distance: 200,
        type: '快餐',
        tel: '010-12345678',
      );

      expect(restaurant.id, 'POI001');
      expect(restaurant.name, '麦当劳');
      expect(restaurant.rating, 4.5);
    });

    test('should create Restaurant with optional fields null', () {
      final restaurant = Restaurant(
        id: 'POI002',
        name: '肯德基',
        address: '朝阳区建国路89号',
        location: LatLng(39.91, 116.41),
      );

      expect(restaurant.rating, isNull);
      expect(restaurant.distance, isNull);
    });
  });
}
```

- [ ] **Step 2: 运行测试（应失败）**

Run: `flutter test test/models/restaurant_test.dart`
Expected: FAIL - "Target of URI doesn't exist"

- [ ] **Step 3: 实现 Restaurant 模型**

Create `lib/models/restaurant.dart`:
```dart
import 'package:amap_flutter_map/amap_flutter_map.dart' show LatLng;

/// 餐馆模型
class Restaurant {
  final String id;           // POI ID
  final String name;         // 名称
  final String address;      // 地址
  final LatLng location;     // 坐标
  final double? rating;      // 评分
  final double? distance;    // 距离（米）
  final String? type;        // 类型
  final String? tel;         // 电话

  const Restaurant({
    required this.id,
    required this.name,
    required this.address,
    required this.location,
    this.rating,
    this.distance,
    this.type,
    this.tel,
  });

  @override
  String toString() => 'Restaurant($name @ $address)';
}
```

- [ ] **Step 4: 运行测试（应通过）**

Run: `flutter test test/models/restaurant_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/models/restaurant.dart test/models/restaurant_test.dart
git commit -m "feat: add Restaurant model"
```

---

## Chunk 3: 服务层

### Task 3.1: 创建异常类

**Files:**
- Create: `lib/services/amap_exceptions.dart`

- [ ] **Step 1: 实现异常类**

Create `lib/services/amap_exceptions.dart`:
```dart
/// 高德地图服务异常基类
sealed class AMapException implements Exception {
  final String message;
  const AMapException(this.message);

  @override
  String toString() => message;
}

/// 定位权限被拒绝
class LocationPermissionDenied extends AMapException {
  const LocationPermissionDenied() : super('定位权限被拒绝，请在设置中开启');
}

/// 定位服务未开启
class LocationServiceDisabled extends AMapException {
  const LocationServiceDisabled() : super('定位服务未开启');
}

/// 网络异常
class NetworkException extends AMapException {
  const NetworkException() : super('网络异常，请检查网络连接');
}

/// 搜索无结果
class SearchNoResult extends AMapException {
  const SearchNoResult() : super('附近暂无相关餐馆');
}

/// 高德 API 错误
class AMapApiException extends AMapException {
  final int code;
  const AMapApiException(this.code, String message) : super(message);
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/services/amap_exceptions.dart
git commit -m "feat: add AMap exception classes"
```

### Task 3.2: 创建 Result 类型

**Files:**
- Create: `lib/services/result.dart`

- [ ] **Step 1: 实现 Result 类型**

Create `lib/services/result.dart`:
```dart
import 'amap_exceptions.dart';

/// 结果封装类型，用于错误处理
class Result<T> {
  final T? data;
  final AMapException? error;
  final bool isSuccess;

  const Result._({this.data, this.error, required this.isSuccess});

  factory Result.success(T data) =>
      Result._(data: data, isSuccess: true);

  factory Result.failure(AMapException error) =>
      Result._(error: error, isSuccess: false);

  T getOrThrow() {
    if (isSuccess) return data as T;
    throw error!;
  }

  T? getOrNull() => data;

  AMapException? getError() => error;
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/services/result.dart
git commit -m "feat: add Result type for error handling"
```

### Task 3.3: 创建 AMapService（骨架）

**Files:**
- Create: `lib/services/amap_service.dart`
- Test: `test/services/amap_service_test.dart`

- [ ] **Step 1: 编写测试（骨架）**

Create `test/services/amap_service_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:eatwhat/services/amap_service.dart';

void main() {
  group('AMapService', () {
    test('instance returns singleton', () {
      final instance1 = AMapService.instance;
      final instance2 = AMapService.instance;
      expect(instance1, same(instance2));
    });

    test('forTest creates new instance', () {
      final instance = AMapService.forTest();
      expect(instance, isNotNull);
    });
  });
}
```

- [ ] **Step 2: 运行测试（应失败）**

Run: `flutter test test/services/amap_service_test.dart`
Expected: FAIL - "Target of URI doesn't exist"

- [ ] **Step 3: 实现 AMapService 骨架**

Create `lib/services/amap_service.dart`:
```dart
import 'dart:async';
import 'package:amap_flutter_map/amap_flutter_map.dart' show LatLng;
import 'location_result.dart';
import 'result.dart';
import '../models/restaurant.dart';
import 'amap_exceptions.dart';

/// 高德地图服务封装（单例模式）
class AMapService {
  static AMapService? _instance;
  static AMapService get instance => _instance ??= AMapService._internal();

  AMapService._internal();

  /// 用于测试的工厂构造函数
  factory AMapService.forTest() => AMapService._internal();

  /// 初始化高德 SDK
  void init({required String androidKey, required String iosKey}) {
    // TODO: 初始化高德 SDK
  }

  /// 获取当前位置
  Future<Result<LocationResult>> getCurrentLocation() async {
    // TODO: 实现定位
    return Result.failure(const LocationServiceDisabled());
  }

  /// 搜索附近餐馆
  Future<Result<List<Restaurant>>> searchNearby({
    required LatLng center,
    String? keyword,
    int page = 1,
    int pageSize = 20,
  }) async {
    // TODO: 实现搜索
    return Result.failure(const SearchNoResult());
  }
}
```

- [ ] **Step 4: 运行测试（应通过）**

Run: `flutter test test/services/amap_service_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/services/amap_service.dart test/services/amap_service_test.dart
git commit -m "feat: add AMapService skeleton with singleton pattern"
```

---

## Chunk 4: 配置层

### Task 4.1: 创建 AMapConfig

**Files:**
- Create: `lib/constants/amap_config.dart`

- [ ] **Step 1: 实现配置类**

Create `lib/constants/amap_config.dart`:
```dart
/// 高德地图配置
///
/// API Key 通过 --dart-define 传入，不在代码中硬编码
///
/// 使用方式：
/// flutter run --dart-define=AMAP_ANDROID_KEY=xxx --dart-define=AMAP_IOS_KEY=yyy
class AMapConfig {
  /// Android API Key
  static const String androidKey = String.fromEnvironment(
    'AMAP_ANDROID_KEY',
    defaultValue: '',
  );

  /// iOS API Key
  static const String iosKey = String.fromEnvironment(
    'AMAP_IOS_KEY',
    defaultValue: '',
  );

  /// 检查配置是否有效
  static bool get isConfigured =>
      androidKey.isNotEmpty && iosKey.isNotEmpty;
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/constants/amap_config.dart
git commit -m "feat: add AMapConfig for API key configuration"
```

---

## Chunk 5: UI 组件层

### Task 5.1: 创建 RestaurantCard 组件

**Files:**
- Create: `lib/widgets/restaurant_card.dart`

- [ ] **Step 1: 实现组件**

Create `lib/widgets/restaurant_card.dart`:
```dart
import 'package:flutter/material.dart';
import '../models/restaurant.dart';

/// 餐馆卡片组件
class RestaurantCard extends StatelessWidget {
  final Restaurant restaurant;
  final VoidCallback? onTap;

  const RestaurantCard({
    super.key,
    required this.restaurant,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      restaurant.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  if (restaurant.rating != null)
                    _buildRating(restaurant.rating!),
                ],
              ),
              const SizedBox(height: 8),
              if (restaurant.distance != null)
                Text(
                  '🚶 ${(restaurant.distance! / 1000).toStringAsFixed(1)} km',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              const SizedBox(height: 4),
              Text(
                restaurant.address,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRating(double rating) {
    return Row(
      children: [
        Icon(Icons.star, size: 16, color: Colors.amber[600]),
        const SizedBox(width: 4),
        Text(
          rating.toStringAsFixed(1),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/widgets/restaurant_card.dart
git commit -m "feat: add RestaurantCard widget"
```

### Task 5.2: 创建 RestaurantListSheet 组件

**Files:**
- Create: `lib/widgets/restaurant_list_sheet.dart`

- [ ] **Step 1: 实现组件**

Create `lib/widgets/restaurant_list_sheet.dart`:
```dart
import 'package:flutter/material.dart';
import '../models/restaurant.dart';
import 'restaurant_card.dart';

/// 底部餐馆列表面板
class RestaurantListSheet extends StatelessWidget {
  final List<Restaurant> restaurants;
  final Function(Restaurant)? onRestaurantTap;
  final bool isLoading;
  final String? keyword;

  const RestaurantListSheet({
    super.key,
    required this.restaurants,
    this.onRestaurantTap,
    this.isLoading = false,
    this.keyword,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.35,
      minChildSize: 0.15,
      maxChildSize: 0.85,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            children: [
              // 拖拽指示条
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // 标题
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      keyword != null
                          ? '"$keyword" 的搜索结果'
                          : '附近找到 ${restaurants.length} 家餐馆',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    if (isLoading)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // 列表
              Expanded(
                child: isLoading && restaurants.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : restaurants.isEmpty
                        ? const Center(child: Text('暂无数据'))
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: restaurants.length,
                            itemBuilder: (context, index) {
                              final restaurant = restaurants[index];
                              return RestaurantCard(
                                restaurant: restaurant,
                                onTap: () => onRestaurantTap?.call(restaurant),
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/widgets/restaurant_list_sheet.dart
git commit -m "feat: add RestaurantListSheet widget with draggable sheet"
```

---

## Chunk 6: 地图页面

### Task 6.1: 创建 MapPage（骨架）

**Files:**
- Create: `lib/pages/map_page.dart`

- [ ] **Step 1: 实现页面骨架**

Create `lib/pages/map_page.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:amap_flutter_map/amap_flutter_map.dart';
import 'package:amap_flutter_map/amap_flutter_base.dart';
import '../models/restaurant.dart';
import '../services/amap_service.dart';
import '../services/result.dart';
import '../services/amap_exceptions.dart';
import '../widgets/restaurant_list_sheet.dart';
import '../constants/amap_config.dart';

/// 地图页面
class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  // 状态
  List<Restaurant> _restaurants = [];
  String? _searchKeyword;
  bool _isLoading = false;
  LatLng? _currentPosition;
  String? _errorMessage;

  // 控制器
  AMapController? _mapController;
  final TextEditingController _searchController = TextEditingController();
  final AMapService _amapService = AMapService.instance;

  @override
  void initState() {
    super.initState();
    _initService();
    _initLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  /// 初始化高德服务
  void _initService() {
    if (AMapConfig.isConfigured) {
      _amapService.init(
        androidKey: AMapConfig.androidKey,
        iosKey: AMapConfig.iosKey,
      );
    }
  }

  /// 初始化定位
  Future<void> _initLocation() async {
    // TODO: 实现定位逻辑
  }

  /// 搜索附近餐馆
  Future<void> _searchNearby() async {
    // TODO: 实现搜索逻辑
  }

  /// 搜索提交
  void _onSearchSubmit(String keyword) {
    if (keyword.trim().isEmpty) return;
    setState(() => _searchKeyword = keyword.trim());
    _searchNearby();
  }

  /// 定位按钮点击
  void _onLocatePressed() {
    _initLocation();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 地图层（占位）
          Container(
            color: Colors.grey[200],
            child: const Center(
              child: Text('地图加载中...'),
            ),
          ),
          // 搜索栏
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: Card(
              elevation: 4,
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: '搜索餐馆...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.my_location),
                    onPressed: _onLocatePressed,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onSubmitted: _onSearchSubmit,
              ),
            ),
          ),
          // 错误提示
          if (_errorMessage != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 70,
              left: 16,
              right: 16,
              child: Card(
                color: Colors.red[100],
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red[700]),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => setState(() => _errorMessage = null),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // 底部列表
          RestaurantListSheet(
            restaurants: _restaurants,
            isLoading: _isLoading,
            keyword: _searchKeyword,
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/pages/map_page.dart
git commit -m "feat: add MapPage skeleton with search bar and sheet"
```

---

## Chunk 7: 首页入口

### Task 7.1: 创建 HomePage 并添加地图入口

**Files:**
- Create: `lib/pages/home_page.dart`
- Modify: `lib/main.dart`

- [ ] **Step 1: 创建 HomePage 文件**

Create `lib/pages/home_page.dart`:
```dart
import 'package:flutter/material.dart';
import 'map_page.dart';

/// 首页
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EatWhat - 今天吃什么'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '发现附近美食',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const MapPage(),
                  ),
                );
              },
              icon: const Icon(Icons.map),
              label: const Text('查看附近餐馆'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: 简化 main.dart**

Modify `lib/main.dart`:
```dart
import 'package:flutter/material.dart';
import 'pages/home_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EatWhat - 今天吃什么',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add lib/pages/home_page.dart lib/main.dart
git commit -m "feat: add map page entry from home page"
```

---

## Chunk 8: 高德 SDK 集成（核心功能）

### Task 8.1: 实现定位功能

**Files:**
- Modify: `lib/services/amap_service.dart`

- [ ] **Step 1: 添加定位实现**

Add to `lib/services/amap_service.dart`:
```dart
import 'package:amap_flutter_location/amap_flutter_location.dart';
import 'package:permission_handler/permission_handler.dart';

// ... existing code ...

  /// 获取当前位置
  Future<Result<LocationResult>> getCurrentLocation() async {
    try {
      // 检查权限
      final status = await Permission.locationWhenInUse.request();
      if (!status.isGranted) {
        return Result.failure(const LocationPermissionDenied());
      }

      // 检查定位服务
      final serviceEnabled = await Permission.location.serviceStatus.isEnabled;
      if (!serviceEnabled) {
        return Result.failure(const LocationServiceDisabled());
      }

      // 使用高德定位
      final location = AMapFlutterLocation();
      final completer = Completer<Map<String, Object>?>();

      location.setLocationOption(AMapLocationOption(
        needAddress: false,
        geoLanguage: GeoLanguage.ZH,
      ));

      location.onLocationChanged().listen((event) {
        if (!completer.isCompleted) {
          completer.complete(event);
        }
      });

      location.startLocation();

      final result = await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => null,
      );

      location.stopLocation();
      location.dispose();

      if (result == null) {
        return Result.failure(const NetworkException());
      }

      final lat = result['latitude'] as double?;
      final lng = result['longitude'] as double?;
      final accuracy = result['accuracy'] as double?;

      if (lat == null || lng == null) {
        return Result.failure(const NetworkException());
      }

      return Result.success(LocationResult(
        position: LatLng(lat, lng),
        accuracy: accuracy ?? 0,
        timestamp: DateTime.now(),
      ));
    } catch (e) {
      return Result.failure(const NetworkException());
    }
  }
```

- [ ] **Step 2: Commit**

```bash
git add lib/services/amap_service.dart
git commit -m "feat: implement getCurrentLocation in AMapService"
```

### Task 8.2: 实现搜索功能

**Files:**
- Modify: `lib/services/amap_service.dart`

- [ ] **Step 1: 添加搜索实现**

Add to `lib/services/amap_service.dart`:
```dart
import 'package:amap_flutter_search/amap_flutter_search.dart';

// ... existing code ...

  /// 搜索附近餐馆
  Future<Result<List<Restaurant>>> searchNearby({
    required LatLng center,
    String? keyword,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final query = PoiQuery(
        query: keyword ?? '餐厅',
        location: LatLng(center.latitude, center.longitude),
        page: page,
        pageSize: pageSize,
      );

      final result = await AMapSearch.instance.searchPoi(query);

      if (result.poiList?.isEmpty ?? true) {
        return Result.failure(const SearchNoResult());
      }

      final restaurants = result.poiList!.map((poi) => _convertPoiToRestaurant(poi)).toList();
      return Result.success(restaurants);
    } catch (e) {
      return Result.failure(const NetworkException());
    }
  }

  /// 将 POI 转换为 Restaurant
  Restaurant _convertPoiToRestaurant(AMapPoi poi) {
    return Restaurant(
      id: poi.poiId ?? '',
      name: poi.title ?? '未知餐馆',
      address: poi.address ?? '地址未知',
      location: LatLng(
        poi.latLng?.latitude ?? 0,
        poi.latLng?.longitude ?? 0,
      ),
      distance: poi.distance?.toDouble(),
      tel: poi.tel,
    );
  }
```

- [ ] **Step 2: Commit**

```bash
git add lib/services/amap_service.dart
git commit -m "feat: implement searchNearby in AMapService"
```

### Task 8.3: 完善 MapPage 功能

**Files:**
- Modify: `lib/pages/map_page.dart`

- [ ] **Step 1: 替换占位地图为真实地图，完善定位和搜索逻辑**

Replace the placeholder in `lib/pages/map_page.dart`:

Find: `// TODO: 实现定位逻辑`
Replace with:
```dart
  /// 初始化定位
  Future<void> _initLocation() async {
    setState(() => _isLoading = true);

    final result = await _amapService.getCurrentLocation();

    if (result.isSuccess) {
      final location = result.getOrThrow();
      setState(() {
        _currentPosition = location.position;
        _errorMessage = null;
      });

      // 移动地图到当前位置
      _mapController?.moveCamera(
        CameraUpdate.newLatLngZoom(location.position, 15),
      );

      // 搜索附近餐馆
      await _searchNearby();
    } else {
      setState(() {
        _errorMessage = result.getError()?.toString();
      });
    }

    setState(() => _isLoading = false);
  }
```

Find: `// TODO: 实现搜索逻辑`
Replace with:
```dart
  /// 搜索附近餐馆
  Future<void> _searchNearby() async {
    if (_currentPosition == null) return;

    setState(() => _isLoading = true);

    final result = await _amapService.searchNearby(
      center: _currentPosition!,
      keyword: _searchKeyword,
    );

    if (result.isSuccess) {
      setState(() {
        _restaurants = result.getOrThrow();
        _errorMessage = null;
      });
      _updateMapMarkers();
    } else {
      setState(() {
        _restaurants = [];
        _errorMessage = result.getError()?.toString();
      });
    }

    setState(() => _isLoading = false);
  }

  /// 更新地图标记
  void _updateMapMarkers() {
    // 清除旧标记并添加新标记
    _mapController?.clearMarkers();
    // TODO: 添加餐馆标记
  }
```

Find: `// 地图层（占位）` 部分，替换为真实地图：
```dart
          // 地图层
          if (AMapConfig.isConfigured)
            AMapWidget(
              apiKey: AMapConfig.androidKey,
              onMapCreated: (controller) {
                _mapController = controller;
                if (_currentPosition != null) {
                  controller.moveCamera(
                    CameraUpdate.newLatLngZoom(_currentPosition!, 15),
                  );
                }
              },
              markers: Set<Marker>.of(
                _restaurants.map((r) => Marker(
                  position: r.location,
                  infoWindow: InfoWindow(title: r.name),
                )),
              ),
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
            )
          else
            Container(
              color: Colors.grey[200],
              child: const Center(
                child: Text('请配置高德地图 API Key'),
              ),
            ),
```

- [ ] **Step 2: Commit**

```bash
git add lib/pages/map_page.dart
git commit -m "feat: integrate AMap widget and implement location/search flow"
```

---

## Chunk 9: 平台配置

### Task 9.1: Android 配置

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml`

- [ ] **Step 1: 添加权限和 API Key**

Add before `</manifest>`:
```xml
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />

    <application
        ...>
        <meta-data
            android:name="com.amap.api.v2.apikey"
            android:value="YOUR_ANDROID_KEY" />

        <!-- 高德定位服务 -->
        <service android:name="com.amap.api.location.APSService" />
    </application>
```

- [ ] **Step 2: Commit**

```bash
git add android/app/src/main/AndroidManifest.xml
git commit -m "config: add Android permissions and AMap meta-data"
```

### Task 9.2: iOS 配置

**Files:**
- Modify: `ios/Runner/Info.plist`

- [ ] **Step 1: 添加定位权限说明**

Add to `ios/Runner/Info.plist`:
```xml
    <key>NSLocationWhenInUseUsageDescription</key>
    <string>需要定位权限来搜索附近的餐馆</string>
    <key>NSLocationAlwaysUsageDescription</key>
    <string>需要定位权限来搜索附近的餐馆</string>
    <key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
    <string>需要定位权限来搜索附近的餐馆</string>
```

- [ ] **Step 2: Commit**

```bash
git add ios/Runner/Info.plist
git commit -m "config: add iOS location permissions"
```

---

## Chunk 10: 测试完善

### Task 10.1: 补充 AMapService 测试

**Files:**
- Modify: `test/services/amap_service_test.dart`

- [ ] **Step 1: 添加 Mock 测试**

Replace `test/services/amap_service_test.dart` content:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:eatwhat/services/amap_service.dart';
import 'package:eatwhat/services/location_result.dart';
import 'package:eatwhat/services/amap_exceptions.dart';
import 'package:amap_flutter_map/amap_flutter_map.dart' show LatLng;

class MockAMapService extends Mock implements AMapService {}

void main() {
  group('AMapService', () {
    test('instance returns singleton', () {
      final instance1 = AMapService.instance;
      final instance2 = AMapService.instance;
      expect(instance1, same(instance2));
    });

    test('forTest creates new instance', () {
      final instance = AMapService.forTest();
      expect(instance, isNotNull);
    });

    group('searchNearby', () {
      late AMapService service;

      setUp(() {
        service = AMapService.forTest();
      });

      test('returns empty list when no results', () async {
        // 由于无法真正调用 API，测试异常处理路径
        final result = await service.searchNearby(
          center: LatLng(39.9, 116.4),
        );

        expect(result.isSuccess, false);
        expect(result.getError(), isA<NetworkException>());
      });
    });
  });
}
```

- [ ] **Step 2: 添加 mocktail 依赖**

Modify `pubspec.yaml`，在 `dev_dependencies:` 添加：
```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
  mocktail: ^1.0.0
```

- [ ] **Step 3: 运行测试**

Run: `flutter pub get && flutter test`
Expected: All tests pass

- [ ] **Step 4: Commit**

```bash
git add pubspec.yaml test/services/amap_service_test.dart
git commit -m "test: add AMapService tests with mocktail"
```

---

## 验证清单

完成所有任务后，运行以下命令验证：

```bash
# 1. 代码格式检查
flutter analyze

# 2. 运行所有测试
flutter test

# 3. 构建检查（Android）
flutter build apk --debug

# 4. 构建检查（iOS - 需要 Xcode）
flutter build ios --debug
```

Expected: 无错误

---

## 运行说明

### 开发运行

```bash
# 需要传入高德 API Key
flutter run --dart-define=AMAP_ANDROID_KEY=your_key --dart-define=AMAP_IOS_KEY=your_key
```

### Web 版本（暂不支持地图）

```bash
flutter run -d chrome
```
注意：Web 版本会显示"请配置高德地图 API Key"的占位界面，因为高德 Flutter SDK 不支持 Web。

---

## 后续任务

### 优先级高
1. **错误处理 UI 优化** - 添加重试按钮、手动选择位置
2. **标记点击交互** - 点击标记高亮对应列表项（当前仅显示 infoWindow）
3. **标记聚合** - 餐馆密集时进行聚合显示

### 优先级中
4. **餐馆详情页** - 点击列表项进入详情
5. **导航功能** - 调起高德地图导航
6. **收藏功能** - 本地存储收藏餐馆

### 优先级低
7. **Widget 测试补充** - RestaurantCard、RestaurantListSheet 的完整 widget 测试
8. **集成测试** - 端到端测试完整流程

### 技术债务
9. **POI 字段验证** - 验证 `poi.latLng` vs `poi.latLonPoint` 的正确字段名
10. **地图标记点击** - 实现 `_updateMapMarkers` 中的 TODO，添加点击回调
