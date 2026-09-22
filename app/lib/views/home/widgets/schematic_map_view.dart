import 'package:flutter/material.dart';
import '../../../models/road_segment.dart';
import '../../../models/route_result.dart';
import '../../../theme/app_theme.dart';

/// 実地図タイル未使用時（既定）のフォールバック表示。道路網データをそのまま模式図として描画する。
/// Google Maps版（`RealMapRouteView`）はネイティブ側のAPIキー設定
/// （`android/`/`ios/`ディレクトリ・`app/README.md`参照）が必要なため、
/// `config/map_config.dart`の`useGoogleMapTiles`で明示的に有効化されない限りこちらを使う。
/// ルート・色付けのデータフローは`RealMapRouteView`と共通（`RouteResult`/`RoadSegment`）。
class SchematicMapView extends StatelessWidget {
  const SchematicMapView({super.key, required this.route, required this.currentLat, required this.currentLon});

  final RouteResult route;
  final double currentLat;
  final double currentLon;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: CustomPaint(
            painter: _RoutePainter(route: route, currentLat: currentLat, currentLon: currentLon),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _RoutePainter extends CustomPainter {
  _RoutePainter({required this.route, required this.currentLat, required this.currentLon});

  final RouteResult route;
  final double currentLat;
  final double currentLon;

  @override
  void paint(Canvas canvas, Size size) {
    if (route.nodes.isEmpty) return;

    final lats = route.nodes.map((n) => n.lat).toList()..add(currentLat);
    final lons = route.nodes.map((n) => n.lon).toList()..add(currentLon);
    final minLat = lats.reduce((a, b) => a < b ? a : b);
    final maxLat = lats.reduce((a, b) => a > b ? a : b);
    final minLon = lons.reduce((a, b) => a < b ? a : b);
    final maxLon = lons.reduce((a, b) => a > b ? a : b);

    const padding = 24.0;
    final latSpan = (maxLat - minLat).abs() < 1e-9 ? 1e-9 : (maxLat - minLat);
    final lonSpan = (maxLon - minLon).abs() < 1e-9 ? 1e-9 : (maxLon - minLon);

    Offset project(double lat, double lon) {
      final x = padding + (lon - minLon) / lonSpan * (size.width - padding * 2);
      // 緯度は北が上になるよう反転
      final y = padding + (1 - (lat - minLat) / latSpan) * (size.height - padding * 2);
      return Offset(x, y);
    }

    // 「複数ルート提案」機能: 代替ルート（最短優先）があれば、安心優先ルートより先に
    // 控えめなグレーの点線で描画する（安心優先ルートを常に前面・強調表示にするため）。
    final alternative = route.alternativeRoute;
    if (alternative != null) {
      for (final RoadSegment segment in alternative.segments) {
        final p1 = project(segment.from.lat, segment.from.lon);
        final p2 = project(segment.to.lat, segment.to.lon);
        _drawDashedLine(canvas, p1, p2, Paint()
          ..color = Colors.grey.withOpacity(0.6)
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round);
      }
    }

    // 経路（区間ごとに安心スコアで色分け）
    for (final RoadSegment segment in route.segments) {
      final p1 = project(segment.from.lat, segment.from.lon);
      final p2 = project(segment.to.lat, segment.to.lon);
      final paint = Paint()
        ..color = AppTheme.comfortScoreColor(segment.comfortScore)
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(p1, p2, paint);
    }

    // 現在地マーカー
    final currentPoint = project(currentLat, currentLon);
    canvas.drawCircle(currentPoint, 9, Paint()..color = Colors.blueAccent);
    canvas.drawCircle(
      currentPoint,
      9,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // 目的地マーカー
    if (route.nodes.isNotEmpty) {
      final dest = route.nodes.last;
      final destPoint = project(dest.lat, dest.lon);
      final destPaint = Paint()..color = Colors.redAccent;
      final path = Path()
        ..moveTo(destPoint.dx, destPoint.dy - 12)
        ..lineTo(destPoint.dx - 8, destPoint.dy + 6)
        ..lineTo(destPoint.dx + 8, destPoint.dy + 6)
        ..close();
      canvas.drawPath(path, destPaint);
    }
  }

  /// CustomPainterのCanvasには点線描画APIが無いため、一定間隔で線分を分割して描く。
  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashLength = 6.0;
    const gapLength = 5.0;
    final totalLength = (end - start).distance;
    if (totalLength == 0) return;
    final direction = (end - start) / totalLength;

    var drawn = 0.0;
    var isDash = true;
    while (drawn < totalLength) {
      final segmentLength = (isDash ? dashLength : gapLength).clamp(0.0, totalLength - drawn) as double;
      final segmentStart = start + direction * drawn;
      final segmentEnd = start + direction * (drawn + segmentLength);
      if (isDash) canvas.drawLine(segmentStart, segmentEnd, paint);
      drawn += segmentLength;
      isDash = !isDash;
    }
  }

  @override
  bool shouldRepaint(covariant _RoutePainter oldDelegate) {
    return oldDelegate.route != route ||
        oldDelegate.currentLat != currentLat ||
        oldDelegate.currentLon != currentLon;
  }
}
