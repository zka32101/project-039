import 'package:cloud_functions/cloud_functions.dart';
import '../models/road_segment.dart';
import '../models/route_result.dart';
import '../services/route_search_service.dart';

/// Cloud Functions（`functions/index.js` の `searchRoute` Callable Function）を呼び出す実装。
/// 設計書「経路探索・影計算はサーバー側（Cloud Functions）で行う。クライアントは結果表示に専念」
/// を実現する本番経路。オンデバイス版（`LocalRouteSearchService`）は開発時・Firebase未接続時の
/// フォールバックとして残す。
class RemoteRouteSearchService implements RouteSearchService {
  RemoteRouteSearchService(this._functions);

  final FirebaseFunctions _functions;

  @override
  Future<RouteResult?> searchNearbyComfortRoute({
    required double currentLat,
    required double currentLon,
    double shadeWeight = 0.6,
  }) async {
    final callable = _functions.httpsCallable('searchRoute');

    final HttpsCallableResult result;
    try {
      result = await callable.call({
        'originLat': currentLat,
        'originLon': currentLon,
        // デモ用の目的地選定（実装順序上、目的地入力画面は次スプリント）:
        // サーバー側で「起点から最も離れたノード」を選ぶロジックはCloud Functions側には無いため、
        // 暫定的に起点からごく近い固定オフセット先を目的地として渡す。
        // 本番は「目的地入力」画面からの座標をそのまま渡す形になる。
        'destLat': currentLat + 0.01,
        'destLon': currentLon + 0.01,
        'shadeWeight': shadeWeight,
      });
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'not-found') return null;
      rethrow;
    }

    return parseSearchRouteResponse(Map<String, dynamic>.from(result.data as Map));
  }
}

/// searchRoute Callable Functionのレスポンス(JSON相当)を`RouteResult`へ変換する。
/// `RemoteRouteSearchService`から純粋なデータ変換部分のみを切り出し、unit testしやすくしている。
RouteResult parseSearchRouteResponse(Map<String, dynamic> data) {
  final nodes = (data['nodes'] as List)
      .map((n) => RoadNode(
            id: n['id'] as String,
            lat: (n['lat'] as num).toDouble(),
            lon: (n['lon'] as num).toDouble(),
          ))
      .toList();

  final segments = (data['segments'] as List).map((s) {
    final comfortScore = (s['comfortScore'] as num).toDouble();
    return RoadSegment(
      id: s['edgeId'] as String,
      from: RoadNode(
        id: '${s['edgeId']}_from',
        lat: (s['fromLat'] as num).toDouble(),
        lon: (s['fromLon'] as num).toDouble(),
      ),
      to: RoadNode(
        id: '${s['edgeId']}_to',
        lat: (s['toLat'] as num).toDouble(),
        lon: (s['toLon'] as num).toDouble(),
      ),
      distanceM: (s['distanceM'] as num).toDouble(),
      // サーバーは影・明るさを統合済みのcomfortScoreのみ返すため、
      // RoadSegment.comfortScoreのgetterがそのまま復元されるよう両フィールドに同値を入れる
      aggregatedShadeScore: comfortScore,
      aggregatedBrightnessScore: comfortScore,
    );
  }).toList();

  final distanceM = (data['distanceM'] as num).toDouble();
  final totalWeighted = segments.fold<double>(0, (sum, s) => sum + s.comfortScore * s.distanceM);
  final averageComfort = distanceM > 0 ? totalWeighted / distanceM : 0.0;

  return RouteResult(
    nodes: nodes,
    segments: segments,
    distanceM: distanceM,
    averageComfortScore: averageComfort,
  );
}
