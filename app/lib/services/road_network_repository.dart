import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../models/road_segment.dart';
import 'road_graph_engine/graph.dart';
import 'road_graph_engine/shadow_score.dart';

/// バンドル済み道路網データ（技術検証プロトタイプと同一構造）を読み込み、
/// グラフ構築＋影スコア適用まで済ませた `RoadGraph` をキャッシュして提供する。
/// `RouteSearchService` と `SpotSubmissionService` の双方が同じグラフを参照するための共通窓口。
/// Cloud Functions実装後は、この読み込み元をFirestore/APIレスポンスに差し替える想定。
class RoadNetworkRepository {
  RoadNetworkRepository({this.assetPath = 'assets/sample_road_network.json'});

  final String assetPath;
  RoadGraph? _cachedGraph;

  Future<RoadGraph> loadGraph() async {
    if (_cachedGraph != null) return _cachedGraph!;

    final raw = json.decode(await rootBundle.loadString(assetPath)) as Map<String, dynamic>;

    final nodes = (raw['nodes'] as List)
        .map((n) => RoadNode(
              id: n['id'] as String,
              lat: (n['lat'] as num).toDouble(),
              lon: (n['lon'] as num).toDouble(),
            ))
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
}
