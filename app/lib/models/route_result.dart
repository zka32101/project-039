import 'road_segment.dart';

/// searchRoute() の結果。ホーム画面の「安心ルート即表示」に使う。
class RouteResult {
  const RouteResult({
    required this.nodes,
    required this.segments,
    required this.distanceM,
    required this.averageComfortScore,
    this.isFromCache = false,
  });

  final List<RoadNode> nodes;
  final List<RoadSegment> segments;
  final double distanceM;

  /// ルート全体の平均安心スコア（0〜1）。ホーム画面のカラーグラデーション表示に使用。
  final double averageComfortScore;

  /// オフライン時（サーバー呼び出し失敗時）に、ローカルキャッシュから復元された結果かどうか。
  /// `true`の場合、ホーム画面は「実際の状況と異なる可能性がある」旨を表示する
  /// （バックログ「オフライン地図の実キャッシュ」対応、`RouteResultCache`参照）。
  final bool isFromCache;

  RouteResult copyWith({bool? isFromCache}) => RouteResult(
        nodes: nodes,
        segments: segments,
        distanceM: distanceM,
        averageComfortScore: averageComfortScore,
        isFromCache: isFromCache ?? this.isFromCache,
      );

  /// オフラインキャッシュ用のシリアライズ。`isFromCache`自体は保存しない
  /// （読み出し側が常に`true`を付与するため、意味を持たない）。
  Map<String, dynamic> toJson() => {
        'nodes': nodes.map((n) => n.toJson()).toList(),
        'segments': segments.map((s) => s.toJson()).toList(),
        'distanceM': distanceM,
        'averageComfortScore': averageComfortScore,
      };

  factory RouteResult.fromJson(Map<String, dynamic> json) => RouteResult(
        nodes: (json['nodes'] as List)
            .map((n) => RoadNode.fromJson(n as Map<String, dynamic>))
            .toList(),
        segments: (json['segments'] as List)
            .map((s) => RoadSegment.fromJson(s as Map<String, dynamic>))
            .toList(),
        distanceM: (json['distanceM'] as num).toDouble(),
        averageComfortScore: (json['averageComfortScore'] as num).toDouble(),
      );
}
