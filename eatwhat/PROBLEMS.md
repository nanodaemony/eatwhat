# EatWhat 项目问题记录

## 问题1：地图页退出崩溃 (SIGABRT in GLThread)

### 现象
进入地图页后，点击返回退出时应用崩溃，logcat显示：
```
F libc : Pointer tag for 0x7112223650 was truncated
F libc : Fatal signal 6 (SIGABRT) in tid 16852 (GLThread 64)
```

### 根因
这是高德地图SDK的Native库(libAMapSDK_MAP_v9_4_0.so)与Android新版本的**ARM内存标签扩展(MTE)**不兼容导致的。

Android 11+引入了ARM内存标签扩展(MTE)安全特性，用于检测内存错误。高德SDK在释放内存时，指针标签被截断，触发SIGABRT崩溃。

### 解决方案
在 `AndroidManifest.xml` 的 `<application>` 标签中添加：
```xml
<application
    ...
    android:allowNativeHeapPointerTagging="false">
```

这会禁用Native堆指针标签，解决与旧版Native库的兼容性问题。

### 文件位置
- `android/app/src/main/AndroidManifest.xml`

---

## 问题2：GPS冷启动定位超时

### 现象
首次点击【开始定位】后一直转圈不出结果，但快速点击第二次就能立即成功。

### 根因
高德定位SDK的监听器建立需要时间，首次定位请求发出时监听器可能还没准备好，导致收不到回调。

### 解决方案
实现**双层超时机制**：
1. **快速检测（1秒）**：如果1秒内没收到任何回调，说明监听器未建立好，立即重试
2. **正常定位超时（60秒）**：给GPS冷启动足够时间

### 关键代码
```dart
// location_service.dart
var hasReceivedCallback = false;

subscription = location.onLocationChanged().listen((result) {
  hasReceivedCallback = true;
  // 处理定位结果...
});

// 第一层：1秒快速检测
final quickCheckResult = await completer.future.timeout(
  const Duration(seconds: 1),
  onTimeout: () {
    if (!hasReceivedCallback) {
      return (null, '__QUICK_FAIL__'); // 监听器未就绪
    }
    return (null, '__CONTINUE__'); // 继续等待
  },
);

if (quickCheckResult.$2 == '__QUICK_FAIL__') {
  return await getCurrentLocation(retryCount: retryCount); // 立即重试
}
```

### 文件位置
- `lib/services/location_service.dart`

---

## 问题3：地图资源释放顺序

### 现象
退出地图页时各种尝试（AutomaticKeepAliveClientMixin、延迟dispose等）都无法解决崩溃。

### 经验教训
1. **不要手动dispose地图控制器** - 让AMapWidget自己处理
2. **清理标记引用** - 在dispose前清空_markers
3. **使用WillPopScope延迟退出** - 给地图SDK时间清理GL资源
4. **不要使用AutomaticKeepAliveClientMixin** - 可能干扰正常销毁流程

### 推荐做法
```dart
@override
void dispose() {
  WidgetsBinding.instance.removeObserver(this);
  _markers.clear();  // 清理标记
  _mapController = null;  // 只清除引用，不dispose
  super.dispose();
}

// 使用WillPopScope
WillPopScope(
  onWillPop: () async {
    _mapController = null;
    _markers.clear();
    await Future.delayed(const Duration(milliseconds: 300));
    return true;
  },
  child: Scaffold(...),
)
```

---

## 问题4：页面过渡动画导致渲染问题

### 现象
使用MaterialPageRoute时，页面切换动画过程中地图可能出现问题。

### 解决方案
使用无动画页面过渡：
```dart
Navigator.push(
  context,
  PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => const MapPage(),
    transitionsBuilder: (context, animation, secondaryAnimation, child) => child,
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
  ),
);
```

### 文件位置
- `lib/main.dart`

---

## 调试技巧

### 1. Native崩溃日志捕获
创建 `CrashHandler.kt` 捕获Java层异常，并监控logcat获取Native崩溃信息。

### 2. Flutter日志服务
使用 `Logger` 类同时输出到控制台和本地文件，方便排查问题。

### 3. 查看崩溃日志
- 应用内：地图页点击 🐛 图标查看崩溃日志
- adb命令：
  ```bash
  adb shell run-as com.nano.eatwhat cat files/native_crash_monitor.log
  ```

---

## 高德SDK集成注意事项

### 隐私合规（必须）
在使用任何高德SDK功能前，必须设置隐私声明：
```dart
// 定位SDK
AMapFlutterLocation.updatePrivacyShow(true, true);
AMapFlutterLocation.updatePrivacyAgree(true);

// 搜索SDK
AmapFlutterSearch.updatePrivacyShow(true, true);
AmapFlutterSearch.updatePrivacyAgree(true);

// 地图SDK（AMapWidget参数）
privacyStatement: AMapPrivacyStatement(
  hasContains: true,
  hasShow: true,
  hasAgree: true,
)
```

### API Key设置
```dart
// Android和iOS需要分别设置
AMapFlutterLocation.setApiKey(androidKey, iosKey);
AmapFlutterSearch.setApiKey(androidKey, iosKey);
```

### 版本兼容性
- amap_flutter_map: ^3.0.0
- amap_flutter_location: ^3.0.0
- amap_flutter_search: ^3.0.0

注意：3.0.0版本API与2.x有较大差异，升级时需要检查API变化。

---

## 相关文件清单

| 文件 | 说明 |
|------|------|
| `android/app/src/main/AndroidManifest.xml` | 权限、API Key、内存标签设置 |
| `android/app/src/main/kotlin/com/nano/eatwhat/CrashHandler.kt` | 崩溃日志捕获 |
| `android/app/src/main/kotlin/com/nano/eatwhat/MainActivity.kt` | MethodChannel用于读取崩溃日志 |
| `lib/map_page.dart` | 地图页面实现 |
| `lib/services/location_service.dart` | 定位服务（含快速重试机制） |
| `lib/services/poi_search_service.dart` | POI搜索服务 |
| `lib/services/logger_service.dart` | Flutter日志服务 |
| `lib/services/native_crash_log_service.dart` | Native崩溃日志读取 |

---

*记录时间：2026-03-16*
