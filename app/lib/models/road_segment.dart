/// 道路区間（Firestoreの `RoadSegment` コレクションに対応）。
/// 設計書 Step3 データモデル参照。安心スコアは影・明るさ投稿を集約した値。
class RoadSegment {
  const RoadSegment({
    required this.id,
    required this.from,
    required this.to,
    required this.distanceM,
    this.baseShadowScore = 0,
    this.aggregatedShadeScore = 0,
    this.aggregatedBrightnessScore = 0,
  });

  final String id;
  final RoadNode from;
  final RoadNode to;
  final double distanceM;

  /// 建物影から自動計算されたベーススコア（0〜1）
  final double baseShadowScore;

  /// ユーザー投稿を重み付け合算した日陰スコア（0〜1）
  final double aggregatedShadeScore;

  /// ユーザー投稿を重み付け合算した明るさスコア（0〜1）
  final double aggregatedBrightnessScore;

  /// 経路探索・地図着色に使う「安心スコア」（暫定: 影と明るさの単純平均）
  double get comfortScore {
    final shade = aggregatedShadeScore > 0 ? aggregatedShadeScore : baseShadowScore;
    return ((shade + aggregatedBrightnessScore) / 2).clamp(0, 1);
  }

  /// オフラインキャッシュ（`RouteResultCache`）用のシリアライズ。
  Map<String, dynamic> toJson() => {
        'id': id,
        'from': from.toJson(),
        'to': to.toJson(),
        'distanceM': distanceM,
        'baseShadowScore': baseShadowScore,
        'aggregatedShadeScore': aggregatedShadeScore,
        'aggregatedBrightnessScore': aggregatedBrightnessScore,
      };

  factory RoadSegment.fromJson(Map<String, dynamic> json) => RoadSegment(
        id: json['id'] as String,
        from: RoadNode.fromJson(json['from'] as Map<String, dynamic>),
        to: RoadNode.fromJson(json['to'] as Map<String, dynamic>),
        distanceM: (json['distanceM'] as num).toDouble(),
        baseShadowScore: (json['baseShadowScore'] as num).toDouble(),
        aggregatedShadeScore: (json['aggregatedShadeScore'] as num).toDouble(),
        aggregatedBrightnessScore: (json['aggregatedBrightnessScore'] as num).toDouble(),
      );
}

class RoadNode {
  const RoadNode({required this.id, required this.lat, required this.lon});

  final String id;
  final double lat;
  final double lon;

  Map<String, dynamic> toJson() => {'id': id, 'lat': lat, 'lon': lon};

  factory RoadNode.fromJson(Map<String, dynamic> json) => RoadNode(
        id: json['id'] as String,
        lat: (json['lat'] as num).toDouble(),
        lon: (json['lon'] as num).toDouble(),
      );
}
