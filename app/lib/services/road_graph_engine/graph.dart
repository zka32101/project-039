import '../../models/road_segment.dart';
import 'geo.dart';

class GraphEdge {
  GraphEdge({
    required this.id,
    required this.roadId,
    required this.from,
    required this.to,
    required this.distanceM,
    this.shadowScore = 0,
  });

  final String id;
  final String roadId;
  final String from;
  final String to;
  final double distanceM;
  double shadowScore;

  /// 双方向通行（歩道）のため、現在地ノードから見た反対側のノードIDを返す。
  String otherEnd(String nodeId) => nodeId == from ? to : from;
}

/// prototype/src/buildGraph.js のDart移植。道路網→隣接グラフ。
class RoadGraph {
  RoadGraph({required this.nodeById, required this.adjacency, required this.edgeById});

  final Map<String, RoadNode> nodeById;
  final Map<String, List<GraphEdge>> adjacency;
  final Map<String, GraphEdge> edgeById;

  static RoadGraph build({
    required List<RoadNode> nodes,
    required List<({String id, String? name, List<String> nodeIds})> roads,
  }) {
    final nodeById = {for (final n in nodes) n.id: n};
    final adjacency = <String, List<GraphEdge>>{for (final n in nodes) n.id: []};
    final edgeById = <String, GraphEdge>{};

    for (final road in roads) {
      for (var i = 0; i < road.nodeIds.length - 1; i++) {
        final fromId = road.nodeIds[i];
        final toId = road.nodeIds[i + 1];
        final from = nodeById[fromId];
        final to = nodeById[toId];
        if (from == null || to == null) continue;

        final distanceM = haversineDistanceM(from.lat, from.lon, to.lat, to.lon);
        final edgeId = '${road.id}_$i';
        final edge = GraphEdge(
          id: edgeId,
          roadId: road.id,
          from: fromId,
          to: toId,
          distanceM: distanceM,
        );
        edgeById[edgeId] = edge;
        adjacency[fromId]!.add(edge);
        adjacency[toId]!.add(edge);
      }
    }

    return RoadGraph(nodeById: nodeById, adjacency: adjacency, edgeById: edgeById);
  }
}
