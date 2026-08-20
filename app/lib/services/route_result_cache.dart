import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/route_result.dart';
import 'road_graph_engine/geo.dart';

/// 直近成功した経路探索結果をローカルへ保存し、オフライン時（サーバー呼び出し失敗時）に
/// 「前回の安心ルート」として提示するためのキャッシュ（バックログ「オフライン地図の実キャッシュ」対応）。
///
/// 【スコープ】道路網データ全体（実データ規模では数万エッジ）をまるごとローカルキャッシュするのは
/// ストレージ・整合性の両面でコストが大きいため、まずは「直近の検索結果1件」を保存する
/// 最小実装とした。何も表示されないより、「実際の状況と異なる可能性がある」旨を明示した上で
/// 前回結果を出す方が有用という判断（`isCacheUsable`が位置・鮮度の両方をチェックする）。
abstract class RouteResultCache {
  Future<void> save({required double lat, required double lon, required RouteResult route});

  /// [lat]/[lon]から一定距離以内・有効期限内であればキャッシュを返す。それ以外は`null`。
  Future<RouteResult?> load({required double lat, required double lon});
}

/// キャッシュが有効とみなす最大距離（メートル）。これを超えて移動している場合、
/// 前回のルートを出しても現在地からかけ離れており誤解を招くため無効化する。
const routeCacheMaxDistanceM = 1500.0;

/// キャッシュが有効とみなす最大経過時間。日照・投稿状況は日単位で変わりうるため、
/// 古すぎるキャッシュは「オフラインでも情報を出す」利点よりも「古い情報」の害の方が大きいと判断。
const routeCacheMaxAge = Duration(hours: 24);

/// 保存された1件のキャッシュエントリが、現在の位置・時刻から見て使用可能かどうかを判定する。
/// unit testしやすいよう`SharedPreferences`アクセスから分離した純関数として切り出している。
bool isCacheUsable({
  required double savedLat,
  required double savedLon,
  required int savedAtEpochMs,
  required double currentLat,
  required double currentLon,
  required int nowEpochMs,
}) {
  final distanceM = haversineDistanceM(savedLat, savedLon, currentLat, currentLon);
  if (distanceM > routeCacheMaxDistanceM) return false;

  final ageMs = nowEpochMs - savedAtEpochMs;
  if (ageMs < 0 || ageMs > routeCacheMaxAge.inMilliseconds) return false;

  return true;
}

class SharedPreferencesRouteResultCache implements RouteResultCache {
  static const _key = 'cached_route_result_v1';

  @override
  Future<void> save({required double lat, required double lon, required RouteResult route}) async {
    final prefs = await SharedPreferences.getInstance();
    final entry = {
      'lat': lat,
      'lon': lon,
      'savedAtEpochMs': DateTime.now().millisecondsSinceEpoch,
      'route': route.toJson(),
    };
    await prefs.setString(_key, jsonEncode(entry));
  }

  @override
  Future<RouteResult?> load({required double lat, required double lon}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;

    final Map<String, dynamic> entry;
    try {
      entry = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null; // 破損データは無視する（オフラインキャッシュはベストエフォート）
    }

    final usable = isCacheUsable(
      savedLat: (entry['lat'] as num).toDouble(),
      savedLon: (entry['lon'] as num).toDouble(),
      savedAtEpochMs: entry['savedAtEpochMs'] as int,
      currentLat: lat,
      currentLon: lon,
      nowEpochMs: DateTime.now().millisecondsSinceEpoch,
    );
    if (!usable) return null;

    return RouteResult.fromJson(entry['route'] as Map<String, dynamic>).copyWith(isFromCache: true);
  }
}
