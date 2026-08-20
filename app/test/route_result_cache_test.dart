import 'package:flutter_test/flutter_test.dart';
import 'package:anshinmichi/models/road_segment.dart';
import 'package:anshinmichi/models/route_result.dart';
import 'package:anshinmichi/services/route_result_cache.dart';

RouteResult _sampleRoute() {
  const from = RoadNode(id: 'A', lat: 35.681, lon: 139.767);
  const to = RoadNode(id: 'B', lat: 35.682, lon: 139.768);
  final segment = RoadSegment(
    id: 'seg1',
    from: from,
    to: to,
    distanceM: 120,
    baseShadowScore: 0.3,
    aggregatedShadeScore: 0.6,
    aggregatedBrightnessScore: 0.4,
  );
  return RouteResult(
    nodes: [from, to],
    segments: [segment],
    distanceM: 120,
    averageComfortScore: 0.5,
  );
}

void main() {
  group('RouteResult/RoadSegment JSON round-trip', () {
    test('toJson→fromJsonで元の値を復元できる', () {
      final route = _sampleRoute();
      final restored = RouteResult.fromJson(route.toJson());

      expect(restored.distanceM, route.distanceM);
      expect(restored.averageComfortScore, route.averageComfortScore);
      expect(restored.nodes.length, route.nodes.length);
      expect(restored.nodes.first.id, route.nodes.first.id);
      expect(restored.segments.first.id, route.segments.first.id);
      expect(restored.segments.first.aggregatedShadeScore, route.segments.first.aggregatedShadeScore);
      // fromJsonで復元した直後はisFromCache=false（load()側がcopyWithで付与する）
      expect(restored.isFromCache, false);
    });

    test('copyWith(isFromCache: true)で他フィールドを保ったままフラグのみ変更できる', () {
      final route = _sampleRoute();
      final marked = route.copyWith(isFromCache: true);
      expect(marked.isFromCache, true);
      expect(marked.distanceM, route.distanceM);
      expect(marked.segments, route.segments);
    });
  });

  group('isCacheUsable', () {
    final now = DateTime(2026, 8, 20, 12, 0).millisecondsSinceEpoch;

    test('同じ地点・直後なら使用可能', () {
      expect(
        isCacheUsable(
          savedLat: 35.681,
          savedLon: 139.767,
          savedAtEpochMs: now,
          currentLat: 35.681,
          currentLon: 139.767,
          nowEpochMs: now,
        ),
        true,
      );
    });

    test('遠く離れている場合（最大距離を超える）は使用不可', () {
      expect(
        isCacheUsable(
          savedLat: 35.681,
          savedLon: 139.767,
          savedAtEpochMs: now,
          currentLat: 35.9, // 約24km離れている
          currentLon: 139.767,
          nowEpochMs: now,
        ),
        false,
      );
    });

    test('最大距離ちょうど未満は使用可能、僅かに超えると不可', () {
      // 緯度1度 ≒ 111km。1400m ≒ 0.0126度、1600m ≒ 0.0144度
      final near = isCacheUsable(
        savedLat: 35.681,
        savedLon: 139.767,
        savedAtEpochMs: now,
        currentLat: 35.681 + 0.0126,
        currentLon: 139.767,
        nowEpochMs: now,
      );
      final far = isCacheUsable(
        savedLat: 35.681,
        savedLon: 139.767,
        savedAtEpochMs: now,
        currentLat: 35.681 + 0.0144,
        currentLon: 139.767,
        nowEpochMs: now,
      );
      expect(near, true);
      expect(far, false);
    });

    test('有効期限（24時間）を超えている場合は使用不可', () {
      final savedAt = DateTime(2026, 8, 19, 11, 59).millisecondsSinceEpoch; // ちょうど24時間1分前
      expect(
        isCacheUsable(
          savedLat: 35.681,
          savedLon: 139.767,
          savedAtEpochMs: savedAt,
          currentLat: 35.681,
          currentLon: 139.767,
          nowEpochMs: now,
        ),
        false,
      );
    });

    test('保存時刻が未来（時計ずれ等の異常値）の場合は使用不可', () {
      expect(
        isCacheUsable(
          savedLat: 35.681,
          savedLon: 139.767,
          savedAtEpochMs: now + 60000,
          currentLat: 35.681,
          currentLon: 139.767,
          nowEpochMs: now,
        ),
        false,
      );
    });
  });
}
