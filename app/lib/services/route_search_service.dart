import '../models/route_result.dart';
import 'road_graph_engine/graph.dart';
import 'road_graph_engine/route_search.dart' as engine;
import 'road_network_repository.dart';

/// 経路探索サービスの抽象インターフェース。
/// 設計書では経路探索・影計算はサーバー側（Cloud Functions）で実行する方針だが、
/// 本セッションではAhaモーメント動線の検証を優先し、まずオンデバイス実装で
/// 同一インターフェースを満たす形にした。Cloud Functions実装後は
/// `RemoteRouteSearchService`（HTTP/Callable Functions呼び出し）に差し替える。
abstract class RouteSearchService {
  /// [shadeWeight] は距離(0)と安心スコア(1)のどちらを優先するかの重み。
  /// 「詳細ルート最適化」（プレミアム機能・設計書Step2のペイウォールトリガー対象）を
  /// 有効にした場合、通常より高い値を渡して日陰・明るさをより強く優先させる。
  Future<RouteResult?> searchNearbyComfortRoute({
    required double currentLat,
    required double currentLon,
    double shadeWeight = 0.6,
  });
}

/// オンデバイス版実装。共有の`RoadNetworkRepository`から道路網グラフを取得し、
/// 現在地に最も近いノードから、データセット内で最も「安心」な行き先ノードへの
/// ルートを即座に計算する。ホーム画面初回表示のAha Momentに使う。
class LocalRouteSearchService implements RouteSearchService {
  LocalRouteSearchService(this._repository);

  final RoadNetworkRepository _repository;

  @override
  Future<RouteResult?> searchNearbyComfortRoute({
    required double currentLat,
    required double currentLon,
    double shadeWeight = 0.6,
  }) async {
    final graph = await _repository.loadGraph();
    if (graph.nodeById.isEmpty) return null;

    final originId = _nearestNodeId(graph, currentLat, currentLon);

    // デモ用の目的地選定: 起点から最も離れたノード（=一番「歩きがいのある」区間を提示する）。
    // 本番実装では「目的地入力」画面からの入力に置き換える。
    final destId = _farthestNodeId(graph, originId);

    return engine.searchRoute(
      graph: graph,
      originNodeId: originId,
      destNodeId: destId,
      shadeWeight: shadeWeight,
    );
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
