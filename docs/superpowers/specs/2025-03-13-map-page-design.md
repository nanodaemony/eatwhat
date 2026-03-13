# EatWhat 地图页面设计文档

## 1. 概述

### 1.1 目标
开发一个 Flutter 地图页面，接入高德地图 SDK，展示地图并搜索用户位置附近的餐馆信息。

### 1.2 使用场景
- 用户打开 App，点击首页按钮进入地图页面
- 自动定位用户当前位置并搜索附近餐馆
- 用户可以在地图上查看餐馆标记，或在底部列表中浏览
- 用户可以通过搜索框输入关键词筛选餐馆

### 1.3 平台支持
- **主要平台**：Android、iOS
- **Web**：本次迭代暂不支持，后续扩展

---

## 2. 用户体验设计

### 2.1 页面入口
首页显示一个明显的按钮，点击后导航到地图页面：
```
[🗺️ 查看附近餐馆]
```

### 2.2 页面布局
```
┌─────────────────────────────────┐
│ 🔍 搜索餐馆...          📍     │  ← AppBar（搜索框 + 定位按钮）
├─────────────────────────────────┤
│                                 │
│         🗺️ 高德地图              │
│                                 │
│      📍 当前位置                 │
│      🍽️ 餐馆标记1                │
│      🍽️ 餐馆标记2                │
│                                 │
├─────────────────────────────────┤ ← 可拖拽面板
│         ─── 拖拽条 ───          │
│  附近找到 15 家餐馆              │
│  ┌───────────────────────────┐  │
│  │ 🍜 麦当劳                 │  │
│  │ ⭐ 4.5  🚶 200m          │  │
│  │ 朝阳区建国路88号          │  │
│  └───────────────────────────┘  │
│  ┌───────────────────────────┐  │
│  │ 🍲 海底捞                 │  │
│  │ ⭐ 4.8  🚶 500m          │  │
│  │ 朝阳区三里屯路19号        │  │
│  └───────────────────────────┘  │
└─────────────────────────────────┘
```

### 2.3 交互流程

```
进入页面
    │
    ▼
请求定位权限 ←────── 拒绝 → 提示手动选择位置
    │                    │
    ▼                    ▼
获取当前坐标         显示默认位置（如北京市中心）
    │
    ▼
显示地图并标记当前位置
    │
    ▼
调用高德周边搜索 API
    │
    ▼
在地图上显示餐馆标记
在底部面板显示餐馆列表
    │
    ├────── 用户拖拽面板 → 展开/收起列表
    │
    ├────── 用户点击搜索框 → 输入关键词
    │                    │
    │                    ▼
    │              重新搜索并刷新结果
    │
    ├────── 用户点击标记 → 高亮对应列表项
    │
    └────── 用户点击列表项 → 未来可进入详情页
```

---

## 3. 技术架构

### 3.1 依赖库

| 包名 | 用途 | 版本 | 来源 |
|------|------|------|------|
| `amap_flutter_map` | 高德地图显示 | ^3.0.0 | 高德官方 |
| `amap_flutter_location` | 高德定位 | ^3.0.0 | 高德官方 |
| `amap_flutter_search` | 高德搜索服务 | ^3.0.0 | 高德官方 |
| `permission_handler` | 权限管理 | ^11.0.0 | 社区 |

### 3.2 目录结构
```
lib/
├── main.dart
├── pages/
│   ├── home_page.dart           # 首页（入口）
│   └── map_page.dart            # 地图页面（新）
├── widgets/
│   └── restaurant_list_sheet.dart  # 底部餐馆列表面板
├── models/
│   └── restaurant.dart          # 餐馆数据模型
├── services/
│   └── amap_service.dart        # 高德地图服务封装
└── constants/
    └── amap_config.dart         # 高德配置（Key等）
```

### 3.3 组件设计

#### MapPage
主页面，整合地图和列表。

```dart
class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  // 状态
  LatLng? _currentPosition;      // 当前位置
  List<Restaurant> _restaurants = [];  // 餐馆列表
  String? _searchKeyword;        // 搜索关键词
  bool _isLoading = false;       // 加载状态

  // 控制器
  AMapController? _mapController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  // 方法
  Future<void> _initLocation() async { ... }
  Future<void> _searchNearby() async { ... }
  void _onSearchSubmit(String keyword) { ... }
  void _onMarkerTap(String poiId) { ... }
}

#### RestaurantListSheet
底部可滑动面板，展示餐馆列表。

```dart
class RestaurantListSheet extends StatelessWidget {
  final List<Restaurant> restaurants;
  final Function(Restaurant) onRestaurantTap;
  final bool isLoading;

  const RestaurantListSheet({
    super.key,
    required this.restaurants,
    required this.onRestaurantTap,
    this.isLoading = false,
  });
}
```

#### AMapService
封装高德地图相关操作，使用单例模式便于测试和依赖注入。

```dart
class AMapService {
  static AMapService? _instance;
  static AMapService get instance => _instance ??= AMapService._internal();

  AMapService._internal();

  // 用于测试的工厂构造函数
  @visibleForTesting
  factory AMapService.forTest() => AMapService._internal();

  // 初始化
  void init({required String apiKey}) {
    // 初始化高德 SDK
  }

  // 定位
  Future<LocationResult> getCurrentLocation() async {
    // 返回包含坐标、精度、时间戳的结果
  }

  // 周边搜索
  Future<List<Restaurant>> searchNearby({
    required LatLng center,
    String? keyword,
    int page = 1,
    int pageSize = 20,
  }) async {
    // 调用高德搜索 API
  }
}

// 定位结果
class LocationResult {
  final LatLng position;
  final double accuracy;  // 精度（米）
  final DateTime timestamp;

  LocationResult({
    required this.position,
    required this.accuracy,
    required this.timestamp,
  });
}
```

#### Restaurant 模型
```dart
import 'package:amap_flutter_map/amap_flutter_map.dart' show LatLng;

class Restaurant {
  final String id;           // POI ID
  final String name;         // 名称
  final String address;      // 地址
  final LatLng location;     // 坐标 (来自 amap_flutter_map)
  final double? rating;      // 评分
  final double? distance;    // 距离（米）
  final String? type;        // 类型（中餐、快餐等）
  final String? tel;         // 电话

  Restaurant({
    required this.id,
    required this.name,
    required this.address,
    required this.location,
    this.rating,
    this.distance,
    this.type,
    this.tel,
  });

  factory Restaurant.fromPOI(Poi poi) {
    return Restaurant(
      id: poi.poiId,
      name: poi.title,
      address: poi.address,
      location: LatLng(poi.latLonPoint.latitude, poi.latLonPoint.longitude),
      rating: poi.businessArea != null ? double.tryParse(poi.businessArea) : null,
      distance: poi.distance?.toDouble(),
      type: poi.typeCode,
      tel: poi.tel,
    );
  }
}
```

---

## 4. 数据流

### 4.1 页面初始化流程
```
MapPage.initState()
    │
    ▼
检查定位权限 → permission_handler
    │
    ▼
获取当前位置 → AMapLocation
    │
    ▼
移动地图到当前位置 → AMapController.moveCamera()
    │
    ▼
搜索附近餐馆 → AMapSearch.searchNearby()
    │
    ▼
更新状态 → setState()
    │
    ▼
UI 刷新：显示标记点 + 列表
```

### 4.2 搜索流程
```
用户输入关键词 → onSearchSubmit()
    │
    ▼
显示加载状态 → setState(isLoading: true)
    │
    ▼
调用搜索 API → AMapService.searchNearby(keyword: keyword)
    │
    ▼
更新餐馆列表 → setState(restaurants: results, isLoading: false)
    │
    ▼
刷新地图标记 → _updateMarkers()
```

---

## 5. 配置管理

### 5.1 高德 API Key 配置

**推荐方案：使用 `--dart-define`（安全，不提交到代码库）**

构建时传入：
```bash
flutter run --dart-define=AMAP_ANDROID_KEY=your_android_key --dart-define=AMAP_IOS_KEY=your_ios_key
```

代码中读取：
```dart
class AMapConfig {
  static const String androidKey = String.fromEnvironment(
    'AMAP_ANDROID_KEY',
    defaultValue: '',
  );
  static const String iosKey = String.fromEnvironment(
    'AMAP_IOS_KEY',
    defaultValue: '',
  );
}
```

**替代方案：使用 flutter_dotenv（开发阶段更方便）**

添加依赖：`flutter_dotenv: ^5.1.0`

创建 `.env` 文件（添加到 `.gitignore`）：
```
AMAP_ANDROID_KEY=your_android_key
AMAP_IOS_KEY=your_ios_key
```

代码中读取：
```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

String androidKey = dotenv.env['AMAP_ANDROID_KEY'] ?? '';
```

**安全提示**：
- 生产环境务必使用 `--dart-define` 或 CI/CD 环境变量
- 在高德控制台中限制 Key 的使用范围（绑定 bundle ID / package name）
- 定期轮换 API Key

### 5.2 权限配置

**Android** (`android/app/src/main/AndroidManifest.xml`)：
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />

<application
    ...>
    <meta-data
        android:name="com.amap.api.v2.apikey"
        android:value="YOUR_ANDROID_KEY" />
</application>
```

**iOS** (`ios/Runner/Info.plist`)：
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>需要定位权限来搜索附近的餐馆</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>需要定位权限来搜索附近的餐馆</string>
```

---

## 6. 错误处理

### 6.1 错误处理模式

采用 **异常捕获 + 结果封装** 的方式：

```dart
// 自定义异常类
sealed class AMapException implements Exception {
  final String message;
  const AMapException(this.message);
}

class LocationPermissionDenied extends AMapException {
  const LocationPermissionDenied() : super('定位权限被拒绝');
}

class LocationServiceDisabled extends AMapException {
  const LocationServiceDisabled() : super('定位服务未开启');
}

class NetworkException extends AMapException {
  const NetworkException() : super('网络异常');
}

class SearchNoResult extends AMapException {
  const SearchNoResult() : super('未找到相关结果');
}

// 使用 Result 类型封装结果
class Result<T> {
  final T? data;
  final AMapException? error;
  final bool isSuccess;

  const Result._({this.data, this.error, required this.isSuccess});
  factory Result.success(T data) => Result._(data: data, isSuccess: true);
  factory Result.failure(AMapException error) => Result._(error: error, isSuccess: false);
}
```

### 6.2 定位失败
| 场景 | 处理方式 |
|------|----------|
| 权限被拒绝 | 显示提示，引导用户到设置开启 |
| 定位超时 | 显示重试按钮，或允许手动选择位置 |
| 定位服务关闭 | 提示开启系统定位服务 |

### 6.3 搜索失败
| 场景 | 处理方式 |
|------|----------|
| 网络错误 | 显示"网络异常，请重试" |
| API 限制 | 显示"请求过于频繁，请稍后再试" |
| 无搜索结果 | 显示"附近暂无相关餐馆" |

### 6.3 地图加载失败
| 场景 | 处理方式 |
|------|----------|
| Key 无效 | 日志提示检查配置 |
| 网络问题 | 显示占位图和重试按钮 |

---

## 7. 测试策略

### 7.1 单元测试
使用 `mocktail` 进行依赖模拟：

```dart
// 测试 AMapService
class MockAMapSearch extends Mock implements AMapSearch {}

void main() {
  late AMapService service;
  late MockAMapSearch mockSearch;

  setUp(() {
    mockSearch = MockAMapSearch();
    service = AMapService.forTest();
    // 注入 mock
  });

  test('searchNearby returns list of restaurants', () async {
    // arrange
    when(() => mockSearch.search(any()))
        .thenAnswer((_) async => mockPoiResult);

    // act
    final result = await service.searchNearby(center: testLocation);

    // assert
    expect(result, hasLength(2));
    expect(result.first.name, '麦当劳');
  });
}
```

### 7.2 Widget 测试
- `RestaurantListSheet` 列表渲染
- 搜索框输入提交
- 加载状态显示

### 7.3 集成测试
- 完整流程：进入页面 → 定位 → 搜索 → 显示结果

---

## 8. 后续扩展

### 8.1 第一阶段（当前）
- 基础地图展示
- 定位 + 周边搜索
- 列表展示

### 8.2 第二阶段
- 餐馆详情页
- 导航功能（调起高德/百度导航）
- 收藏功能

### 8.3 第三阶段
- ~~Web 平台支持~~（注：高德 Flutter SDK 暂不支持 Web，如需 Web 需考虑其他方案如 Google Maps 或 Mapbox）
- 筛选功能（价格、评分、距离）
- 地图模式切换（卫星/标准）
- 标记聚合（Marker Clustering）- 解决餐馆密集时的显示问题

---

## 9. 参考资源

- [高德地图 Flutter 文档](https://lbs.amap.com/api/flutter/guide/summary/flutter-summary)
- [amap_flutter_map](https://pub.dev/packages/amap_flutter_map)
- [amap_flutter_location](https://pub.dev/packages/amap_flutter_location)
- [amap_flutter_search](https://pub.dev/packages/amap_flutter_search)

---

## 10. 变更记录

| 日期 | 版本 | 变更内容 | 作者 |
|------|------|----------|------|
| 2025-03-13 | 1.0 | 初始设计 | Claude |
