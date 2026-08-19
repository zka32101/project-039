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
  ///
  /// [destLat]/[destLon] は「目的地入力」画面（`DestinationPickerView`）でユーザーが
  /// 選んだ座標。未指定の場合はAha Moment用のデモ目的地（実装依存）を使う。
  Future<RouteResult?> searchNearbyComfortRoute({
    required double currentLat,
    required double currentLon,
    double shadeWeight = 0.6,
    double? destLat,
    double? destLon,
  });
}

/// オンデバイス版実装。共有の`RoadNetworkRepository`から道路網グラフを取得し、
/// 現在地に最も近いノードから、指定された（または自動選定した）目的地ノードへの
/// ルートを計算する。
class LocalRouteSearchService implements RouteSearchService {
  LocalRouteSearchService(this._repository);

  final RoadNetworkRepository _repository;

  @override
  Future<RouteResult?> searchNearbyComfortRoute({
    required double currentLat,
    required double currentLon,
    double shadeWeight = 0.6,
    double? destLat,
    double? destLon,
  }) async {
    final graph = await _repository.loadGraph();
    if (graph.nodeById.isEmpty) return null;

    final originId = _nearestNodeId(graph, currentLat, currentLon);

    final destId = (destLat != null && destLon != null)
        ? _nearestNodeId(graph, destLat, destLon)
        // デモ用の目的地選定（目的地未指定時のAha Moment用）: 起点から最も離れたノード
        // （=一番「歩きがいのある」区間を提示する）。
        : _farthestNodeId(graph, originId);

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
