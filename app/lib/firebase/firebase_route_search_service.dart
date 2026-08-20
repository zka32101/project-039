import 'package:cloud_functions/cloud_functions.dart';
import '../models/road_segment.dart';
import '../models/route_result.dart';
import '../services/auth_service.dart';
import '../services/route_result_cache.dart';
import '../services/route_search_service.dart' show RouteSearchException, RouteSearchService;

/// Cloud Functions（`functions/index.js` の `searchRoute` Callable Function）を呼び出す実装。
/// 設計書「経路探索・影計算はサーバー側（Cloud Functions）で行う。クライアントは結果表示に専念」
/// を実現する本番経路。オンデバイス版（`LocalRouteSearchService`）は開発時・Firebase未接続時の
/// フォールバックとして残す。
///
/// オフライン時（Callable Functionの呼び出し自体が失敗した場合）は、[RouteResultCache]に
/// 保存された直近の成功結果があればそれを返す（`RouteResult.isFromCache=true`で明示）。
/// バックログ「オフライン地図の実キャッシュ」対応。
///
/// `searchRoute`はサーバー側で認証を必須にしている（不正利用対策、`functions/README.md`参照）。
/// `main.dart`起動時の匿名サインインが何らかの理由で失敗していた場合に備え、呼び出し前に
/// [AuthService.ensureSignedIn]で再試行する（`FirestoreSpotSubmissionService`と同じ考え方）。
class RemoteRouteSearchService implements RouteSearchService {
  RemoteRouteSearchService(this._functions, this._authService, {RouteResultCache? cache})
      : _cache = cache ?? SharedPreferencesRouteResultCache();

  final FirebaseFunctions _functions;
  final AuthService _authService;
  final RouteResultCache _cache;

  @override
  Future<RouteResult?> searchNearbyComfortRoute({
    required double currentLat,
    required double currentLon,
    double shadeWeight = 0.6,
    double? destLat,
    double? destLon,
  }) async {
    try {
      await _authService.ensureSignedIn();
    } catch (_) {
      // ここで失敗しても後続のcallable.call()が'unauthenticated'で失敗するだけなので、
      // 即座に例外にはしない（オフライン時のキャッシュフォールバックへ進める）。
    }
    final callable = _functions.httpsCallable('searchRoute');

    // 目的地未指定時（Aha Moment初回表示）はデモ用に近傍のオフセット先を渡す。
    // サーバー側（Cloud Functions）は「起点から最も離れたノード」のような自動選定ロジックを
    // 持たないため、実際の目的地は`DestinationPickerView`からの座標を必須とする設計。
    final effectiveDestLat = destLat ?? currentLat + 0.01;
    final effectiveDestLon = destLon ?? currentLon + 0.01;

    final HttpsCallableResult result;
    try {
      result = await callable.call({
        'originLat': currentLat,
        'originLon': currentLon,
        'destLat': effectiveDestLat,
        'destLon': effectiveDestLon,
        'shadeWeight': shadeWeight,
      });
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'not-found') return null;
      // 'unavailable'（オフライン等のネットワーク層エラー）・'unauthenticated'
      // （起動時の匿名サインインが未完了/失敗していた場合。上記のensureSignedIn()再試行後もなお
      // 失敗した場合はオフライン相当として扱う）はキャッシュへフォールバック。
      // それ以外（invalid-argument等、リクエスト自体の不備）はキャッシュを試さずそのまま投げる。
      if (e.code == 'unavailable' || e.code == 'unauthenticated') {
        final cached = await _cache.load(lat: currentLat, lon: currentLon);
        if (cached != null) return cached;
      }
      // レート制限超過（`functions/src/rateLimiting.js`参照）。サーバー側のエラーコード付き
      // メッセージをそのまま出すとノイズが多いため、利用者に分かりやすい文言へ差し替える。
      if (e.code == 'resource-exhausted') {
        throw RouteSearchException('短時間に検索が集中しています。しばらく待ってから再度お試しください');
      }
      rethrow;
    } catch (_) {
      // FirebaseFunctionsException以外（純粋なネットワーク断等）もオフライン扱いでキャッシュを試す。
      final cached = await _cache.load(lat: currentLat, lon: currentLon);
      if (cached != null) return cached;
      rethrow;
    }

    final route = parseSearchRouteResponse(Map<String, dynamic>.from(result.data as Map));
    await _cache.save(lat: currentLat, lon: currentLon, route: route);
    return route;
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
