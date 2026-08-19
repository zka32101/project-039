import 'package:geolocator/geolocator.dart';

enum LocationPermissionState { notRequested, granted, denied, deniedForever, serviceDisabled }

/// 位置情報許可・現在地取得のラッパー。設計書のAha動線
/// 「起動→位置情報許可→ホーム」の2ステップ目を担う。
class LocationService {
  Future<LocationPermissionState> requestPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return LocationPermissionState.serviceDisabled;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    switch (permission) {
      case LocationPermission.denied:
        return LocationPermissionState.denied;
      case LocationPermission.deniedForever:
        return LocationPermissionState.deniedForever;
      case LocationPermission.whileInUse:
      case LocationPermission.always:
        return LocationPermissionState.granted;
      case LocationPermission.unableToDetermine:
        return LocationPermissionState.denied;
    }
  }

  /// 現在地取得（タイムアウト10秒・失敗時はnullを返しホーム側でフォールバック表示に切替）。
  Future<({double lat, double lon})?> getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      ).timeout(const Duration(seconds: 10));
      return (lat: position.latitude, lon: position.longitude);
    } catch (_) {
      return null;
    }
  }
}
