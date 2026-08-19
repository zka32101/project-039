import 'package:collection/collection.dart';
import '../../models/road_segment.dart';
import '../../models/route_result.dart';
import 'graph.dart';

/// prototype/src/routeSearch.js のDart移植（Dijkstra）。
/// コスト = 距離 × (1 - shadeWeight × shadowScore)。技術検証プロトタイプで
/// 200回反復・平均0.1msの実用速度を確認済み（RESULTS.md参照、小規模データでの目安）。
RouteResult? searchRoute({
  required RoadGraph graph,
  required String originNodeId,
  required String destNodeId,
  double shadeWeight = 0.6,
}) {
  if (!graph.nodeById.containsKey(originNodeId) || !graph.nodeById.containsKey(destNodeId)) {
    return null;
  }

  final dist = <String, double>{originNodeId: 0};
  final prevEdge = <String, String>{};
  final prevNode = <String, String>{};
  final visited = <String>{};

  final queue = HeapPriorityQueue<_Entry>((a, b) => a.priority.compareTo(b.priority));
  queue.add(_Entry(originNodeId, 0));

  while (queue.isNotEmpty) {
    final current = queue.removeFirst();
    if (visited.contains(current.nodeId)) continue;
    visited.add(current.nodeId);
    if (current.nodeId == destNodeId) break;

    for (final edge in graph.adjacency[current.nodeId] ?? const <GraphEdge>[]) {
      final neighbor = edge.otherEnd(current.nodeId);
      if (visited.contains(neighbor)) continue;
      final edgeCost = edge.distanceM * (1 - shadeWeight * edge.shadowScore);
      final newCost = current.priority + edgeCost;
      if (newCost < (dist[neighbor] ?? double.infinity)) {
        dist[neighbor] = newCost;
        prevEdge[neighbor] = edge.id;
        prevNode[neighbor] = current.nodeId;
        queue.add(_Entry(neighbor, newCost));
      }
    }
  }

  if (!dist.containsKey(destNodeId)) return null;

  final pathNodeIds = <String>[destNodeId];
  final segments = <RoadSegment>[];
  var cur = destNodeId;
  var totalDistanceM = 0.0;
  var totalComfortWeighted = 0.0;

  while (cur != originNodeId) {
    final edgeId = prevEdge[cur];
    final prev = prevNode[cur];
    if (edgeId == null || prev == null) break;
    final edge = graph.edgeById[edgeId]!;
    final fromNode = graph.nodeById[edge.from]!;
    final toNode = graph.nodeById[edge.to]!;
    final segment = RoadSegment(
      id: edge.id,
      from: fromNode,
      to: toNode,
      distanceM: edge.distanceM,
      baseShadowScore: edge.shadowScore,
      aggregatedShadeScore: edge.shadowScore,
    );
    segments.add(segment);
    totalDistanceM += edge.distanceM;
    totalComfortWeighted += segment.comfortScore * edge.distanceM;
    pathNodeIds.add(prev);
    cur = prev;
  }

  final orderedNodeIds = pathNodeIds.reversed.toList();
  final nodes = orderedNodeIds.map((id) => graph.nodeById[id]!).toList();
  final averageComfort = totalDistanceM > 0 ? totalComfortWeighted / totalDistanceM : 0.0;

  return RouteResult(
    nodes: nodes,
    segments: segments.reversed.toList(),
    distanceM: totalDistanceM,
    averageComfortScore: averageComfort,
  );
}

class _Entry {
  _Entry(this.nodeId, this.priority);
  final String nodeId;
  final double priority;
}
