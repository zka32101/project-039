import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/favorite_route.dart';

/// 「お気に入りルート保存」機能。`RouteResultCache`/`SpotSubmissionQueue`と同じ、
/// SharedPreferencesベースのJSONリスト永続化パターンを踏襲している。
abstract class FavoriteRouteService {
  Future<List<FavoriteRoute>> loadAll();
  Future<void> add({required String label, required double lat, required double lon});
  Future<void> remove(String id);
}

class SharedPreferencesFavoriteRouteService implements FavoriteRouteService {
  static const _key = 'favorite_routes_v1';

  /// 上限を設けないと際限なく増え続けうるため、既存の`RouteResultCache.maxEntries`と
  /// 同程度の上限を設ける（自宅・職場・実家など、行き来する場所の想定数として妥当な範囲）。
  static const maxEntries = 10;

  @override
  Future<List<FavoriteRoute>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    return _loadRaw(prefs).map(FavoriteRoute.fromJson).toList();
  }

  @override
  Future<void> add({required String label, required double lat, required double lon}) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = _loadRaw(prefs);
    final favorite = FavoriteRoute(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      label: label,
      lat: lat,
      lon: lon,
    );
    entries.add(favorite.toJson());
    if (entries.length > maxEntries) {
      entries.removeAt(0); // 最も古いものから削除（上限超過時）
    }
    await prefs.setString(_key, jsonEncode(entries));
  }

  @override
  Future<void> remove(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = _loadRaw(prefs)..removeWhere((e) => e['id'] == id);
    await prefs.setString(_key, jsonEncode(entries));
  }

  /// 壊れたデータはベストエフォートで無視し、空リストとして扱う
  /// （`RouteResultCache._loadRawEntries`と同じ考え方）。
  List<Map<String, dynamic>> _loadRaw(SharedPreferences prefs) {
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }
}
