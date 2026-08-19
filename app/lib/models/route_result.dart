import 'road_segment.dart';

/// searchRoute() の結果。ホーム画面の「安心ルート即表示」に使う。
class RouteResult {
  const RouteResult({
    required this.nodes,
    required this.segments,
    required this.distanceM,
    required this.averageComfortScore,
  });

  final List<RoadNode> nodes;
  final List<RoadSegment> segments;
  final double distanceM;

  /// ルート全体の平均安心スコア（0〜1）。ホーム画面のカラーグラデーション表示に使用。
  final double averageComfortScore;
}
