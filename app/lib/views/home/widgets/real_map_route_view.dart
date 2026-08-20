import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../models/road_segment.dart';
import '../../../models/route_result.dart';
import '../../../theme/app_theme.dart';

/// 実地図タイル版のルート表示（バックログ「実地図タイル（Google Maps等）」対応）。
/// `SchematicMapView`と同じ`route`/`currentLat`/`currentLon`を受け取り、区間ごとの
/// 安心スコア色分け・現在地/目的地マーカーという同じデータフローをGoogle Maps上に描画する
/// （`SchematicMapView`冒頭のコメントで想定されていた置き換え先）。
///
/// 【使用条件】`config/map_config.dart`の`useGoogleMapTiles`が`true`の場合のみ`HomeView`から
/// 使われる。ネイティブ側のAPIキー設定が無い環境でこのWidgetを使うと、Google Maps側が
/// タイル取得に失敗しグレー画面になる（クラッシュはしない）。既定では`SchematicMapView`に
/// フォールバックしているため、通常の起動では到達しない。
class RealMapRouteView extends StatefulWidget {
  const RealMapRouteView({super.key, required this.route, required this.currentLat, required this.currentLon});

  final RouteResult route;
  final double currentLat;
  final double currentLon;

  @override
  State<RealMapRouteView> createState() => _RealMapRouteViewState();
}

class _RealMapRouteViewState extends State<RealMapRouteView> {
  GoogleMapController? _controller;

  @override
  void didUpdateWidget(covariant RealMapRouteView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // ルートが変わった（目的地変更・再検索）場合、新しい範囲に合わせてカメラを再フィットする。
    if (oldWidget.route != widget.route) {
      _fitToRoute();
    }
  }

  void _fitToRoute() {
    final controller = _controller;
    if (controller == null) return;
    final bounds = _boundsFor(widget.route, widget.currentLat, widget.currentLon);
    if (bounds == null) return;
    controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 40));
  }

  static LatLngBounds? _boundsFor(RouteResult route, double currentLat, double currentLon) {
    final lats = route.nodes.map((n) => n.lat).toList()..add(currentLat);
    final lons = route.nodes.map((n) => n.lon).toList()..add(currentLon);
    if (lats.isEmpty) return null;
    return LatLngBounds(
      southwest: LatLng(lats.reduce((a, b) => a < b ? a : b), lons.reduce((a, b) => a < b ? a : b)),
      northeast: LatLng(lats.reduce((a, b) => a > b ? a : b), lons.reduce((a, b) => a > b ? a : b)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final route = widget.route;

    final polylines = <Polyline>{
      for (final RoadSegment segment in route.segments)
        Polyline(
          polylineId: PolylineId(segment.id),
          points: [
            LatLng(segment.from.lat, segment.from.lon),
            LatLng(segment.to.lat, segment.to.lon),
          ],
          color: AppTheme.comfortScoreColor(segment.comfortScore),
          width: 6,
        ),
    };

    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('current'),
        position: LatLng(widget.currentLat, widget.currentLon),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: '現在地'),
      ),
      if (route.nodes.isNotEmpty)
        Marker(
          markerId: const MarkerId('destination'),
          position: LatLng(route.nodes.last.lat, route.nodes.last.lon),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: '目的地'),
        ),
    };

    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(widget.currentLat, widget.currentLon),
            zoom: 16,
          ),
          polylines: polylines,
          markers: markers,
          zoomControlsEnabled: false,
          myLocationButtonEnabled: false,
          mapToolbarEnabled: false,
          onMapCreated: (controller) {
            _controller = controller;
            _fitToRoute();
          },
        ),
      ),
    );
  }
}
