/// 「お気に入りルート保存」機能: 自宅・職場などよく使う目的地をラベル付きで保存する。
class FavoriteRoute {
  const FavoriteRoute({required this.id, required this.label, required this.lat, required this.lon});

  /// 保存時刻ベースの一意なID（削除時の特定に使う）。
  final String id;
  final String label;
  final double lat;
  final double lon;

  Map<String, dynamic> toJson() => {'id': id, 'label': label, 'lat': lat, 'lon': lon};

  factory FavoriteRoute.fromJson(Map<String, dynamic> json) => FavoriteRoute(
        id: json['id'] as String,
        label: json['label'] as String,
        lat: (json['lat'] as num).toDouble(),
        lon: (json['lon'] as num).toDouble(),
      );
}
