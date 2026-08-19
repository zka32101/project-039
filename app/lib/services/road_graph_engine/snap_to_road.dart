import 'geo.dart';
import 'graph.dart';

class SnapResult {
  const SnapResult({required this.edgeId, required this.roadId, required this.avgDistanceM});
  final String edgeId;
  final String roadId;
  final double avgDistanceM;
}

/// prototype/src/snapToRoad.js のDart移植（技術検証プロトタイプでロジックを確認済み）。
/// 投稿UIで指がなぞった軌跡を、最寄りの道路区間（グラフエッジ）にスナップする。
/// 設計書「投稿位置はスナップ後のroadSegmentIdのみ保存。生の緯度経度ログは保持しない」
/// というプライバシー設計の核となるロジック。
SnapResult? snapTraceToRoad(
  List<({double lat, double lon})> trace,
  RoadGraph graph, {
  double maxSnapDistanceM = 30,
}) {
  if (trace.isEmpty) return null;

  final edgeVotes = <String, ({double totalDistance, int count})>{};

  for (final point in trace) {
    String? bestEdgeId;
    var bestDistance = double.infinity;

    for (final edge in graph.edgeById.values) {
      final from = graph.nodeById[edge.from];
      final to = graph.nodeById[edge.to];
      if (from == null || to == null) continue;
      final d = pointToSegmentDistanceM(point.lat, point.lon, from.lat, from.lon, to.lat, to.lon);
      if (d > maxSnapDistanceM) continue;
      if (d < bestDistance) {
        bestDistance = d;
        bestEdgeId = edge.id;
      }
    }

    if (bestEdgeId != null) {
      final prev = edgeVotes[bestEdgeId] ?? (totalDistance: 0.0, count: 0);
      edgeVotes[bestEdgeId] = (
        totalDistance: prev.totalDistance + bestDistance,
        count: prev.count + 1,
      );
    }
  }

  if (edgeVotes.isEmpty) return null;

  String? winnerEdgeId;
  var winnerCount = -1;
  for (final entry in edgeVotes.entries) {
    if (entry.value.count > winnerCount) {
      winnerCount = entry.value.count;
      winnerEdgeId = entry.key;
    }
  }

  final votes = edgeVotes[winnerEdgeId]!;
  final edge = graph.edgeById[winnerEdgeId]!;
  return SnapResult(
    edgeId: winnerEdgeId!,
    roadId: edge.roadId,
    avgDistanceM: votes.totalDistance / votes.count,
  );
}
