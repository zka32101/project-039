import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/route_result.dart';
import 'road_graph_engine/geo.dart';

/// 直近成功した経路探索結果をローカルへ保存し、オフライン時（サーバー呼び出し失敗時）に
/// 「前回の安心ルート」として提示するためのキャッシュ（バックログ「オフライン地図の実キャッシュ」対応）。
///
/// 【スコープ】道路網データ全体（実データ規模では数万エッジ）をまるごとローカルキャッシュするのは
/// ストレージ・整合性の両面でコストが大きいため、代わりに「直近の検索結果を複数エリア分」
/// 保持する方式にした（最大[SharedPreferencesRouteResultCache.maxEntries]件）。
/// 自宅・職場など、よく使う数か所を行き来する利用パターンであれば、単一エントリよりも
/// 実用性が高い。何も表示されないより、「実際の状況と異なる可能性がある」旨を明示した上で
/// 前回結果を出す方が有用という判断（`isCacheUsable`が位置・鮮度の両方をチェックする）。
abstract class RouteResultCache {
  Future<void> save({required double lat, required double lon, required RouteResult route});

  /// [lat]/[lon]から一定距離以内・有効期限内のエントリがあれば、その中で最も新しいものを返す。
  /// 該当するエントリが無ければ`null`。
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

/// 複数の保存済みエントリの中から、現在地・時刻から見て最も適した1件のインデックスを選ぶ。
/// 使用可能な（[isCacheUsable]を満たす）エントリのうち最も新しいものを優先し、
/// 保存時刻が同じ場合は現在地に近い方を優先する。使用可能なものが無ければ`null`。
/// `RouteResult`のJSON往復から分離した純関数として切り出し、unit testしやすくしている。
int? selectBestCacheEntryIndex(
  List<({double lat, double lon, int savedAtEpochMs})> entries,
  double currentLat,
  double currentLon,
  int nowEpochMs,
) {
  int? bestIndex;
  int bestSavedAtEpochMs = -1;
  double bestDistanceM = double.infinity;

  for (var i = 0; i < entries.length; i++) {
    final entry = entries[i];
    final usable = isCacheUsable(
      savedLat: entry.lat,
      savedLon: entry.lon,
      savedAtEpochMs: entry.savedAtEpochMs,
      currentLat: currentLat,
      currentLon: currentLon,
      nowEpochMs: nowEpochMs,
    );
    if (!usable) continue;

    final distanceM = haversineDistanceM(entry.lat, entry.lon, currentLat, currentLon);
    final isBetter = bestIndex == null ||
        entry.savedAtEpochMs > bestSavedAtEpochMs ||
        (entry.savedAtEpochMs == bestSavedAtEpochMs && distanceM < bestDistanceM);
    if (isBetter) {
      bestIndex = i;
      bestSavedAtEpochMs = entry.savedAtEpochMs;
      bestDistanceM = distanceM;
    }
  }
  return bestIndex;
}

class SharedPreferencesRouteResultCache implements RouteResultCache {
  static const _key = 'cached_route_results_v2'; // v1（単一エントリ）→v2（複数エリア保持）でキーも変更

  /// 保持する最大エントリ数（＝行き来する「よく使うエリア」の想定数）。
  static const maxEntries = 5;

  /// この距離以内の既存エントリは「同じエリア」とみなし、別エントリとして追加せず
  /// 新しい結果で置き換える（同じ場所への再検索で重複が積み上がるのを防ぐ）。
  static const _dedupeRadiusM = 300.0;

  @override
  Future<void> save({required double lat, required double lon, required RouteResult route}) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = _loadRawEntries(prefs);

    entries.removeWhere(
      (e) => haversineDistanceM(e['lat'] as double, e['lon'] as double, lat, lon) <= _dedupeRadiusM,
    );
    entries.insert(0, {
      'lat': lat,
      'lon': lon,
      'savedAtEpochMs': DateTime.now().millisecondsSinceEpoch,
      'route': route.toJson(),
    });
    if (entries.length > maxEntries) {
      entries.removeRange(maxEntries, entries.length);
    }

    await prefs.setString(_key, jsonEncode(entries));
  }

  @override
  Future<RouteResult?> load({required double lat, required double lon}) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = _loadRawEntries(prefs);
    if (entries.isEmpty) return null;

    final nowEpochMs = DateTime.now().millisecondsSinceEpoch;
    final bestIndex = selectBestCacheEntryIndex(
      entries
          .map((e) => (lat: e['lat'] as double, lon: e['lon'] as double, savedAtEpochMs: e['savedAtEpochMs'] as int))
          .toList(),
      lat,
      lon,
      nowEpochMs,
    );
    if (bestIndex == null) return null;

    return RouteResult.fromJson(entries[bestIndex]['route'] as Map<String, dynamic>).copyWith(isFromCache: true);
  }

  /// 保存済みエントリ一覧を読み込む。壊れたデータ（フォーマット不正等）はベストエフォートで
  /// 無視し、空リストとして扱う（オフラインキャッシュは「無くても動く」機能のため）。
  List<Map<String, dynamic>> _loadRawEntries(SharedPreferences prefs) {
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw) as List;
      return decoded.map((e) {
        final m = e as Map<String, dynamic>;
        return {
          'lat': (m['lat'] as num).toDouble(),
          'lon': (m['lon'] as num).toDouble(),
          'savedAtEpochMs': m['savedAtEpochMs'] as int,
          'route': m['route'],
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }
}
