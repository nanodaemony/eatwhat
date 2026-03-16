# 地图页功能设计文档

## 概述

为 EatWhat App 添加地图页功能，用户可以在首页点击进入地图页，页面会自动定位到用户当前位置并搜索附近餐馆，以列表形式展示在地图下方。

## 需求背景

- 用户需要快速发现周边的餐馆选项
- 结合地图可视化位置和列表详细信息，提升用户体验

## 功能需求

### 核心功能

1. **定位功能**
   - 进入页面自动请求定位权限
   - 获取用户当前位置（经纬度）
   - 定位失败时提供手动重试和搜索选项

2. **地图显示**
   - 使用高德地图 3D 地图 SDK
   - 默认显示街道级视图（zoom 16-17）
   - 在地图上标记用户当前位置
   - 在地图上标记搜索到的餐馆位置

3. **POI 搜索**
   - 搜索范围：2000米（2公里）
   - 搜索关键词：使用"餐厅"作为主要关键词（单一关键词策略，避免多关键词 OR 逻辑复杂）
   - 每页返回最多 20 条结果
   - 搜索类型：周边搜索（PoiSearch.SearchBound）

4. **餐馆列表展示**
   - 显示在地图下方，占据屏幕下半部分
   - 列表项信息：
     - 餐馆名称
     - 距离（米）
     - 详细地址
     - 评分（高德评分）
     - 人均消费（如有）
   - 支持下拉刷新

5. **交互功能**
   - 点击地图标记点显示信息气泡（餐馆名称）
   - 点击列表项，地图中心移动到该餐馆位置，标记高亮，信息气泡自动打开
   - "定位到我"按钮：快速回到用户当前位置，保持当前缩放级别
   - 标记点高亮显示当前选中的餐馆（选中标记变为蓝色，其他保持红色）

### 错误处理

| 场景 | 处理方式 | 错误码 |
|------|----------|--------|
| 定位权限被拒绝 | 显示 SnackBar 提示，提供"去设置"按钮 | 12 (PERMISSION_DENIED) |
| 定位超时 | 显示提示和"重试"按钮 | - |
| 无网络连接 | 显示网络错误提示 | 13 (NO_NETWORK) |
| 定位服务未开启 | 提示用户开启 GPS | 2 (SERVICE_NOT_AVAILABLE) |
| 搜索无结果 | 显示空状态提示 | - |
| 网络错误 | 显示错误提示，支持重试 | - |

**高德定位错误码参考：**
- `0` - 定位成功
- `12` - 缺少定位权限
- `13` - 网络异常或网络连接失败
- `2` - 定位服务未开启
- `4` - 定位失败，无法获取基站/WiFi 信息

## 技术方案

### 依赖库

项目已配置以下高德地图 Flutter 插件：

```yaml
dependencies:
  amap_flutter_map: ^3.0.0      # 地图显示
  amap_flutter_location: ^3.0.0  # 定位功能
  amap_flutter_search: ^0.0.4    # POI搜索
  permission_handler: ^11.3.1    # 权限管理
```

### API Key 配置

已配置的 Key：
- iOS Key: `f8012fb518ecc1cecea2561897cb8cab`
- Android Key: `2ae92fdbb3c6f8b615b6d0ff483c95a4`

**配置位置：**

1. **iOS - Info.plist**
```xml
<key>AMapApiKey</key>
<string>f8012fb518ecc1cecea2561897cb8cab</string>
```

2. **Android - AndroidManifest.xml**
```xml
<meta-data
    android:name="com.amap.api.v2.apikey"
    android:value="2ae92fdbb3c6f8b615b6d0ff483c95a4" />
```

3. **Dart 代码初始化（如需要）**
```dart
import 'package:amap_flutter_base/amap_flutter_base.dart';

// 在 main.dart 中初始化
AMapInitializer.init(key: Platform.isIOS ? iOSKey : androidKey);
```

### 页面结构

```
MapPage (StatefulWidget)
├── Scaffold
│   ├── AppBar (标题: 附近餐馆)
│   ├── Body
│   │   ├── Column
│   │   │   ├── Expanded (flex: 1) - 地图区域
│   │   │   │   ├── Stack
│   │   │   │   │   ├── AMapWidget (地图)
│   │   │   │   │   ├── Positioned (定位按钮)
│   │   │   │   │   └── LoadingIndicator (加载指示器)
│   │   │   ├── Expanded (flex: 1) - 列表区域
│   │   │   │   └── RestaurantListView
│   │   │   └── ErrorWidget (错误提示，条件显示)
```

### 状态管理

使用 StatefulWidget 管理状态：

```dart
class _MapPageState extends State<MapPage> {
  bool _isLoading = true;                    // 加载状态
  bool _isSearching = false;                 // 搜索中状态
  LatLng? _currentPosition;                  // 当前位置
  List<PoiItem> _restaurants = [];           // 餐馆列表
  PoiItem? _selectedRestaurant;              // 选中的餐馆
  String? _errorMessage;                     // 错误信息
  AMapController? _mapController;            // 地图控制器
}
```

### 核心流程

#### 1. 定位流程

```
进入页面
    ↓
检查定位权限
    ↓
已授权? → 是 → 开始定位
    ↓ 否
请求权限
    ↓
用户同意? → 是 → 开始定位
    ↓ 否
显示权限被拒绝提示，提供"去设置"按钮
```

#### 2. 搜索流程

```
获取定位成功
    ↓
移动地图到当前位置
    ↓
调用 POI 周边搜索
    ↓
搜索成功 → 在地图添加标记 + 更新列表
    ↓
搜索失败 → 显示错误提示
```

### 高德 API 使用参考

#### 定位（参考 AMap_Android_API_Location_Demo）

```java
// Android 原生实现参考
AMapLocationClientOption option = new AMapLocationClientOption();
option.setLocationMode(AMapLocationMode.Hight_Accuracy);  // 高精度模式
option.setOnceLocation(true);                              // 单次定位
option.setNeedAddress(true);                               // 需要地址信息
option.setHttpTimeOut(30000);                              // 超时30秒
```

Flutter 实现使用 `amap_flutter_location` 插件。

#### POI 周边搜索（参考 AMap_Android_API_3DMap_Demo）

```java
// Android 原生实现参考
PoiSearch.Query query = new PoiSearch.Query(keyWord, "", "");
query.setPageSize(20);
query.setPageNum(0);

PoiSearch poiSearch = new PoiSearch(this, query);
poiSearch.setBound(new SearchBound(lp, 2000, true));  // 2000米范围
poiSearch.searchPOIAsyn();
```

Flutter 实现使用 `amap_flutter_search` 插件。

## UI 设计

### 布局

- 地图区域：屏幕上半部分（50%）
- 列表区域：屏幕下半部分（50%）
- 定位按钮：地图右下角悬浮

### 颜色方案

- 主题色：应用主色调
- 当前位置标记：蓝色
- 餐馆标记：红色/橙色
- 选中标记：高亮显示

## 性能考虑

1. **定位超时处理**：设置 30 秒超时，超时后提示用户
2. **列表优化**：使用 `ListView.builder` 实现虚拟列表
3. **地图标记**：限制同时显示的标记数量（最大 20 个），避免性能问题
4. **防抖处理**：仅在用户点击"重新搜索"或下拉刷新时触发搜索，避免地图移动时频繁搜索

### 地图生命周期管理

参考 Android 原生 Demo 的生命周期处理，Flutter 实现需注意：

```dart
class _MapPageState extends State<MapPage> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _mapController?.dispose();  // 释放地图资源
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 处理应用前后台切换
    if (state == AppLifecycleState.paused) {
      // 暂停定位
    } else if (state == AppLifecycleState.resumed) {
      // 恢复定位
    }
  }
}
```

### 状态持久化

在以下场景需要保持状态：
- 屏幕旋转：保持当前位置、搜索结果、选中餐馆
- 应用切换后台：不释放定位客户端，保持搜索结果
- 页面返回后再进入：重新定位并搜索

## 测试要点

1. 定位成功场景
2. 定位权限被拒绝场景
3. 定位超时场景
4. 搜索到结果场景
5. 搜索无结果场景
6. 网络错误场景
7. 地图交互（点击标记、移动地图）
8. 列表交互（点击列表项）

## 参考文档

- 高德地图 Android 定位 SDK 文档：`/AMap_Android_Doc/AMap_Android_API_Location_Doc/`
- 高德地图 Android 3D 地图 SDK 文档：`/AMap_Android_Doc/AMap_Android_API_3DMap_Doc/`
- 高德地图 Android 搜索 SDK 文档：`/AMap_Android_Doc/AMap_Android_API_Search_Doc/`
- 定位 Demo：`/AMap_Android_Demo/AMap_Android_API_Location_Demo/`
- POI 周边搜索 Demo：`/AMap_Android_Demo/AMap_Android_API_3DMap_Demo/.../PoiAroundSearchActivity.java`
