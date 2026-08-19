import 'package:flutter_test/flutter_test.dart';
import 'package:anshinmichi/firebase/firebase_route_search_service.dart';

void main() {
  test('parseSearchRouteResponse: Cloud Functionsのレスポンス形式をRouteResultへ変換できる', () {
    final data = {
      'distanceM': 200.0,
      'nodes': [
        {'id': 'A', 'lat': 35.0, 'lon': 139.0},
        {'id': 'B', 'lat': 35.001, 'lon': 139.0},
      ],
      'segments': [
        {
          'edgeId': 'r1_0',
          'fromLat': 35.0,
          'fromLon': 139.0,
          'toLat': 35.001,
          'toLon': 139.0,
          'distanceM': 200.0,
          'comfortScore': 0.8,
        },
      ],
    };

    final result = parseSearchRouteResponse(data);

    expect(result.nodes.length, 2);
    expect(result.segments.length, 1);
    expect(result.distanceM, 200.0);
    expect(result.averageComfortScore, closeTo(0.8, 0.0001));
  });

  test('parseSearchRouteResponse: 区間が無い場合は平均安心スコア0', () {
    final data = {'distanceM': 0.0, 'nodes': <Map<String, dynamic>>[], 'segments': <Map<String, dynamic>>[]};
    final result = parseSearchRouteResponse(data);
    expect(result.averageComfortScore, 0.0);
  });
}
