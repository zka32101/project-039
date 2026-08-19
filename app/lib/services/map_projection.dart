import 'dart:ui';
import 'road_graph_engine/graph.dart';

/// 緯度経度⇔画面座標(Offset)の相互変換。ホームの経路表示・投稿キャンバスの双方で
/// 「道路網の全ノードを収める矩形」を基準にした同一の投影ロジックを使う。
class MapProjection {
  MapProjection({
    required this.minLat,
    required this.maxLat,
    required this.minLon,
    required this.maxLon,
    required this.canvasSize,
    this.padding = 24,
  });

  factory MapProjection.fromNodes(Iterable<RoadNode> nodes, Size canvasSize, {double padding = 24}) {
    final lats = nodes.map((n) => n.lat).toList();
    final lons = nodes.map((n) => n.lon).toList();
    return MapProjection(
      minLat: lats.reduce((a, b) => a < b ? a : b),
      maxLat: lats.reduce((a, b) => a > b ? a : b),
      minLon: lons.reduce((a, b) => a < b ? a : b),
      maxLon: lons.reduce((a, b) => a > b ? a : b),
      canvasSize: canvasSize,
      padding: padding,
    );
  }

  final double minLat;
  final double maxLat;
  final double minLon;
  final double maxLon;
  final Size canvasSize;
  final double padding;

  double get _latSpan => (maxLat - minLat).abs() < 1e-9 ? 1e-9 : (maxLat - minLat);
  double get _lonSpan => (maxLon - minLon).abs() < 1e-9 ? 1e-9 : (maxLon - minLon);

  Offset toScreen(double lat, double lon) {
    final x = padding + (lon - minLon) / _lonSpan * (canvasSize.width - padding * 2);
    // 緯度は北が上になるよう反転
    final y = padding + (1 - (lat - minLat) / _latSpan) * (canvasSize.height - padding * 2);
    return Offset(x, y);
  }

  ({double lat, double lon}) toLatLon(Offset point) {
    final lon = minLon + (point.dx - padding) / (canvasSize.width - padding * 2) * _lonSpan;
    final lat = minLat + (1 - (point.dy - padding) / (canvasSize.height - padding * 2)) * _latSpan;
    return (lat: lat, lon: lon);
  }
}
