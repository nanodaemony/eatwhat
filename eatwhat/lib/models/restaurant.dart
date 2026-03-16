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
