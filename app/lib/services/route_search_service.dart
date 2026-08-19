import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../models/road_segment.dart';
import '../models/route_result.dart';
import 'road_graph_engine/graph.dart';
import 'road_graph_engine/route_search.dart' as engine;
import 'road_graph_engine/shadow_score.dart';

/// 経路探索サービスの抽象インターフェース。
/// 設計書では経路探索・影計算はサーバー側（Cloud Functions）で実行する方針だが、
/// 本セッションではAhaモーメント動線の検証を優先し、まずオンデバイス実装で
/// 同一インターフェースを満たす形にした。Cloud Functions実装後は
/// `RemoteRouteSearchService`（HTTP/Callable Functions呼び出し）に差し替える。
abstract class RouteSearchService {
  Future<RouteResult?> searchNearbyComfortRoute({
    required double currentLat,
    required double currentLon,
  });
}

/// オンデバイス版実装。バンドル済みの道路網データ（技術検証プロトタイプと同一構造）を
/// 読み込み、現在地に最も近いノードから、データセット内で最も「安心」な行き先ノードへの
/// ルートを即座に計算する。ホーム画面初回表示のAha Momentに使う。
class LocalRouteSearchService implements RouteSearchService {
  LocalRouteSearchService({this.assetPath = 'assets/sample_road_network.json'});

  final String assetPath;
  RoadGraph? _cachedGraph;

  Future<RoadGraph> _loadGraph() async {
    if (_cachedGraph != null) return _cachedGraph!;

    final raw = json.decode(await rootBundle.loadString(assetPath)) as Map<String, dynamic>;

    final nodes = (raw['nodes'] as List)
        .map((n) => RoadNode(id: n['id'] as String, lat: (n['lat'] as num).toDouble(), lon: (n['lon'] as num).toDouble()))
        .toList();

    final roads = (raw['roads'] as List)
        .map((r) => (
              id: r['id'] as String,
              name: r['name'] as String?,
              nodeIds: (r['nodeIds'] as List).cast<String>(),
            ))
        .toList();

    final graph = RoadGraph.build(nodes: nodes, roads: roads);

    final buildings = (raw['buildings'] as List)
        .map((b) => ShadowBuilding(
              heightM: (b['heightM'] as num).toDouble(),
              centerLat: (b['center'] as List)[0] as double,
              centerLon: (b['center'] as List)[1] as double,
            ))
        .toList();

    applyShadowScores(graph: graph, buildings: buildings, utcDateTime: DateTime.now().toUtc());

    _cachedGraph = graph;
    return graph;
  }

  @override
  Future<RouteResult?> searchNearbyComfortRoute({
    required double currentLat,
    required double currentLon,
  }) async {
    final graph = await _loadGraph();
    if (graph.nodeById.isEmpty) return null;

    final originId = _nearestNodeId(graph, currentLat, currentLon);

    // デモ用の目的地選定: 起点から最も離れたノード（=一番「歩きがいのある」区間を提示する）。
    // 本番実装では「目的地入力」画面からの入力に置き換える。
    final destId = _farthestNodeId(graph, originId);

    return engine.searchRoute(graph: graph, originNodeId: originId, destNodeId: destId, shadeWeight: 0.6);
  }

  String _nearestNodeId(RoadGraph graph, double lat, double lon) {
    String? bestId;
    var bestDistSq = double.infinity;
    for (final node in graph.nodeById.values) {
      final dLat = node.lat - lat;
      final dLon = node.lon - lon;
      final distSq = dLat * dLat + dLon * dLon;
      if (distSq < bestDistSq) {
        bestDistSq = distSq;
        bestId = node.id;
      }
    }
    return bestId!;
  }

  String _farthestNodeId(RoadGraph graph, String fromId) {
    final from = graph.nodeById[fromId]!;
    String bestId = fromId;
    var bestDistSq = -1.0;
    for (final node in graph.nodeById.values) {
      final dLat = node.lat - from.lat;
      final dLon = node.lon - from.lon;
      final distSq = dLat * dLat + dLon * dLon;
      if (distSq > bestDistSq) {
        bestDistSq = distSq;
        bestId = node.id;
      }
    }
    return bestId;
  }
}
