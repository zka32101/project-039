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

/// prototype/src/geo.js の pointToSegmentDistanceM のDart移植。
/// 点(plat,plon)から線分(alat,alon)-(blat,blon)への最短距離（メートル、簡易平面近似）。
/// 投稿UIの軌跡→道路区間スナップ（snapTraceToRoad）で使用。
double pointToSegmentDistanceM(
  double plat,
  double plon,
  double alat,
  double alon,
  double blat,
  double blon,
) {
  final latRef = toRad(alat);
  const mPerDegLat = 111320.0;
  final mPerDegLon = 111320.0 * math.cos(latRef);

  final px = (plon - alon) * mPerDegLon;
  final py = (plat - alat) * mPerDegLat;
  final bx = (blon - alon) * mPerDegLon;
  final by = (blat - alat) * mPerDegLat;

  final segLenSq = bx * bx + by * by;
  var t = segLenSq == 0 ? 0.0 : (px * bx + py * by) / segLenSq;
  t = t.clamp(0.0, 1.0);
  final projX = bx * t;
  final projY = by * t;
  return math.sqrt(math.pow(px - projX, 2) + math.pow(py - projY, 2));
}
