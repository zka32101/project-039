import 'dart:math' as math;

/// prototype/src/geo.js のDart移植（技術検証プロトタイプで速度・妥当性を確認済みのロジック）。
const double _earthRadiusM = 6371000;

double toRad(double deg) => deg * math.pi / 180;

double toDeg(double rad) => rad * 180 / math.pi;

double haversineDistanceM(
  double lat1,
  double lon1,
  double lat2,
  double lon2,
) {
  final dLat = toRad(lat2 - lat1);
  final dLon = toRad(lon2 - lon1);
  final a = math.pow(math.sin(dLat / 2), 2) +
      math.cos(toRad(lat1)) * math.cos(toRad(lat2)) * math.pow(math.sin(dLon / 2), 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return _earthRadiusM * c;
}
