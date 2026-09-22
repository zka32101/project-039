import 'road_segment.dart';

/// 経路探索の時間帯モード。日中は日陰、夜間は明るさを評価軸として優先する
/// （`functions/index.js`の`searchRoute`の`mode`パラメータに対応）。
enum RouteMode {
  day,
  night;

  String get wireValue => name;

  static RouteMode fromWireValue(String? value) =>
      value == 'night' ? RouteMode.night : RouteMode.day;
}

/// searchRoute() の結果。ホーム画面の「安心ルート即表示」に使う。
class RouteResult {
  const RouteResult({
    required this.nodes,
    required this.segments,
    required this.distanceM,
    required this.averageComfortScore,
    this.isFromCache = false,
    this.mode = RouteMode.day,
    this.alternativeRoute,
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

  /// このルートを計算した際のモード（日中/夜間）。
  final RouteMode mode;

  /// 「複数ルート提案」機能: このルートと異なる場合のみ、最短優先の代替ルートが入る
  /// （サーバー側`sameAsRecommended`がtrueの場合や、まだ対応していない実装ではnull）。
  /// ネストはこの1段のみ（代替ルート自身がさらに代替ルートを持つことはない）。
  final RouteResult? alternativeRoute;

  RouteResult copyWith({bool? isFromCache, RouteMode? mode}) => RouteResult(
        nodes: nodes,
        segments: segments,
        distanceM: distanceM,
        averageComfortScore: averageComfortScore,
        isFromCache: isFromCache ?? this.isFromCache,
        mode: mode ?? this.mode,
        alternativeRoute: alternativeRoute,
      );

  /// オフラインキャッシュ用のシリアライズ。`isFromCache`自体は保存しない
  /// （読み出し側が常に`true`を付与するため、意味を持たない）。
  Map<String, dynamic> toJson() => {
        'nodes': nodes.map((n) => n.toJson()).toList(),
        'segments': segments.map((s) => s.toJson()).toList(),
        'distanceM': distanceM,
        'averageComfortScore': averageComfortScore,
        'mode': mode.wireValue,
        'alternativeRoute': alternativeRoute?.toJson(),
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
        mode: RouteMode.fromWireValue(json['mode'] as String?),
        alternativeRoute: json['alternativeRoute'] != null
            ? RouteResult.fromJson(Map<String, dynamic>.from(json['alternativeRoute'] as Map))
            : null,
      );
}
