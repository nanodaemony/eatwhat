# Flutter ProGuard Rules
# Keep all Flutter classes
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# 忽略 Google Play Core 类（用于 deferred components，但本应用不需要）
-dontwarn com.google.android.play.core.**

# 高德地图 SDK - 必须保留
-keep class com.amap.api.** { *; }
-keep class com.autonavi.** { *; }
-keep class com.loc.** { *; }

# 高德搜索 SDK
-keep class com.amap.api.search.** { *; }
-keep class com.amap.api.services.** { *; }

# 高德定位 SDK
-keep class com.amap.api.location.** { *; }
-keep class com.amap.api.fence.** { *; }
-keep class com.autonavi.aps.amapapi.model.** { *; }

# 高德地图 Flutter 插件
-keep class com.amap.flutter.map.** { *; }
-keep class com.amap.flutter.map.core.** { *; }
-keep class com.amap.flutter.map.utils.** { *; }
-keep class com.amap.flutter.map.overlays.** { *; }
-keep class com.amap.flutter.map.overlays.marker.** { *; }
-keep class com.amap.flutter.map.overlays.polygon.** { *; }
-keep class com.amap.flutter.map.overlays.polyline.** { *; }
-keep class com.amap.flutter.map.overlays.circle.** { *; }

# 高德搜索 Flutter 插件
-keep class com.example.amap_flutter_search.** { *; }

# 高德定位 Flutter 插件
-keep class com.amap.flutter.location.** { *; }

# 保留 JNI 调用的类
-keepclasseswithmembernames class * {
    native <methods>;
}

# 保留枚举类
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# 保留 Parcelable 序列化类
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# 保留 Serializable 序列化类
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# 移除日志代码
-assumenosideeffects class android.util.Log {
    public static int v(...);
    public static int d(...);
    public static int i(...);
}
