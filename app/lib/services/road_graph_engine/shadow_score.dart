import 'dart:math' as math;
import 'geo.dart';
import 'graph.dart';
import 'sun_position.dart';

class ShadowBuilding {
  const ShadowBuilding({required this.heightM, required this.centerLat, required this.centerLon});

  final double heightM;
  final double centerLat;
  final double centerLon;
}

/// prototype/src/shadowScore.js のDart移植（技術検証プロトタイプでアルゴリズム・速度を確認済み）。
/// 各エッジの `shadowScore` を直接更新する（Cloud Functions実装後は事前計算済みの値を
/// Firestoreから読み込む想定。この関数はオフライン/オンデバイス・フォールバック用途）。
void applyShadowScores({
  required RoadGraph graph,
  required List<ShadowBuilding> buildings,
  required DateTime utcDateTime,
}) {
  if (buildings.isEmpty || graph.edgeById.isEmpty) return;

  final repNode = graph.nodeById[graph.edgeById.values.first.from];
  final sun = getSunPosition(utcDateTime, repNode?.lat ?? 35.68, repNode?.lon ?? 139.76);

  if (sun.altitudeDeg <= 0) return; // 日没後は建物影の概念が無意味

  final shadowDirDeg = (sun.azimuthDeg + 180) % 360;

  for (final edge in graph.edgeById.values) {
    final from = graph.nodeById[edge.from];
    final to = graph.nodeById[edge.to];
    if (from == null || to == null) continue;
    final midLat = (from.lat + to.lat) / 2;
    final midLon = (from.lon + to.lon) / 2;

    var maxScore = 0.0;
    for (final b in buildings) {
      final shadowLengthM = b.heightM / math.tan(toRad(sun.altitudeDeg));
      final distToCenterM = haversineDistanceM(midLat, midLon, b.centerLat, b.centerLon);
      const buildingRadiusM = 20;
      if (distToCenterM > shadowLengthM + buildingRadiusM) continue;

      final bearingToPointDeg = _bearingDeg(b.centerLat, b.centerLon, midLat, midLon);
      final angleDiff = _angularDifferenceDeg(bearingToPointDeg, shadowDirDeg);
      final toleranceDeg = math.max(15, 45 - sun.altitudeDeg * 0.3);
      if (angleDiff <= toleranceDeg) maxScore = math.max(maxScore, 1.0);
    }
    edge.shadowScore = maxScore;
  }
}

double _bearingDeg(double lat1, double lon1, double lat2, double lon2) {
  final y = math.sin(toRad(lon2 - lon1)) * math.cos(toRad(lat2));
  final x = math.cos(toRad(lat1)) * math.sin(toRad(lat2)) -
      math.sin(toRad(lat1)) * math.cos(toRad(lat2)) * math.cos(toRad(lon2 - lon1));
  return (toDeg(math.atan2(y, x)) + 360) % 360;
}

double _angularDifferenceDeg(double a, double b) {
  final diff = (a - b).abs() % 360;
  return diff > 180 ? 360 - diff : diff;
}
