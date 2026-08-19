import 'package:flutter_test/flutter_test.dart';
import 'package:anshinmichi/models/road_segment.dart';
import 'package:anshinmichi/services/road_graph_engine/geo.dart';
import 'package:anshinmichi/services/road_graph_engine/graph.dart';
import 'package:anshinmichi/services/road_graph_engine/route_search.dart';
import 'package:anshinmichi/services/road_graph_engine/snap_to_road.dart';
import 'package:anshinmichi/services/road_graph_engine/sun_position.dart';

void main() {
  group('geo', () {
    test('haversineDistanceM: 同一点は距離0', () {
      expect(haversineDistanceM(35.68, 139.76, 35.68, 139.76), 0);
    });

    test('haversineDistanceM: 東京駅→有楽町駅相当は600〜1000m', () {
      final d = haversineDistanceM(35.681236, 139.767125, 35.675069, 139.763328);
      expect(d, greaterThan(600));
      expect(d, lessThan(1000));
    });
  });

  group('sunPosition', () {
    test('夏の東京・正午は高度角が高い', () {
      final sun = getSunPosition(DateTime.utc(2026, 8, 19, 3), 35.681236, 139.767125);
      expect(sun.altitudeDeg, greaterThan(40));
    });

    test('深夜は高度角が負', () {
      final sun = getSunPosition(DateTime.utc(2026, 8, 19, 16), 35.681236, 139.767125);
      expect(sun.altitudeDeg, lessThan(0));
    });
  });

  group('routeSearch', () {
    RoadGraph makeLinearGraph() {
      return RoadGraph.build(
        nodes: const [
          RoadNode(id: 'A', lat: 35.0, lon: 139.0),
          RoadNode(id: 'B', lat: 35.001, lon: 139.0),
          RoadNode(id: 'C', lat: 35.002, lon: 139.0),
        ],
        roads: [(id: 'r1', name: null, nodeIds: ['A', 'B', 'C'])],
      );
    }

    test('単純な一直線経路を発見できる', () {
      final graph = makeLinearGraph();
      final result = searchRoute(graph: graph, originNodeId: 'A', destNodeId: 'C');
      expect(result, isNotNull);
      expect(result!.nodes.map((n) => n.id).toList(), ['A', 'B', 'C']);
    });

    test('存在しないノードはnullを返す', () {
      final graph = makeLinearGraph();
      final result = searchRoute(graph: graph, originNodeId: 'A', destNodeId: 'Z');
      expect(result, isNull);
    });
  });

  group('snapToRoad', () {
    RoadGraph makeGraph() {
      return RoadGraph.build(
        nodes: const [
          RoadNode(id: 'A', lat: 35.0000, lon: 139.0000),
          RoadNode(id: 'B', lat: 35.0010, lon: 139.0000), // Aから約111m北
        ],
        roads: [(id: 'r1', name: null, nodeIds: ['A', 'B'])],
      );
    }

    test('道路にほぼ沿った軌跡は正しい区間にスナップされる', () {
      final graph = makeGraph();
      final trace = [
        (lat: 35.0002, lon: 139.00002),
        (lat: 35.0005, lon: 139.00003),
        (lat: 35.0008, lon: 139.00001),
      ];
      final result = snapTraceToRoad(trace, graph);
      expect(result, isNotNull);
      expect(result!.edgeId, graph.edgeById.keys.first);
    });

    test('道路から極端に離れた軌跡はnullを返す', () {
      final graph = makeGraph();
      final trace = [(lat: 35.5, lon: 139.5), (lat: 35.5, lon: 139.5001)];
      final result = snapTraceToRoad(trace, graph, maxSnapDistanceM: 30);
      expect(result, isNull);
    });

    test('空の軌跡はnullを返す', () {
      final graph = makeGraph();
      expect(snapTraceToRoad([], graph), isNull);
    });
  });
}
