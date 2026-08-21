import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/map_projection.dart';
import '../../services/road_graph_engine/graph.dart';
import '../../viewmodels/providers.dart';
import '../../widgets/primary_button.dart';

/// 目的地入力画面。設計書「[目的地入力] → ルート検索結果」に対応。
///
/// 【実装上の注記】住所検索・地名検索（Geocoding API等）は本セッションのスコープ外
/// （外部APIキー・課金設定が必要）のため、道路網の模式図をタップして目的地を選ぶ方式にした。
/// 実地図タイルへの差し替え時（`SchematicMapView`と同様）は、この画面もGoogleMap等の
/// タップ操作に置き換えられる想定。
class DestinationPickerView extends ConsumerStatefulWidget {
  const DestinationPickerView({super.key});

  @override
  ConsumerState<DestinationPickerView> createState() => _DestinationPickerViewState();
}

class _DestinationPickerViewState extends ConsumerState<DestinationPickerView> {
  RoadGraph? _graph;
  Offset? _selectedPoint;
  MapProjection? _projection;

  @override
  void initState() {
    super.initState();
    _loadGraph();
  }

  Future<void> _loadGraph() async {
    final graph = await ref.read(roadNetworkRepositoryProvider).loadGraph();
    if (!mounted) return;
    setState(() => _graph = graph);
  }

  void _confirm() {
    final projection = _projection;
    final point = _selectedPoint;
    if (projection == null || point == null) return;
    final latLon = projection.toLatLon(point);
    Navigator.of(context).pop((lat: latLon.lat, lon: latLon.lon));
  }

  @override
  Widget build(BuildContext context) {
    final graph = _graph;
    return Scaffold(
      appBar: AppBar(title: const Text('目的地を選ぶ')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: graph == null
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  // 画面が縦に狭い場合（例: 横向き表示）でもAspectRatio(1)の地図がはみ出さないよう、
                  // Columnをスクロール可能にしている（横幅に対して正方形になるよう描画するため、
                  // 縦に余裕が無いとオーバーフローしてしまう）。
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('地図をタップして目的地を選んでください', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      const Text('選んだ地点に最も近い道へ自動的に接続されます'),
                      const SizedBox(height: 16),
                      AspectRatio(
                        aspectRatio: 1,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final size = Size(constraints.maxWidth, constraints.maxHeight);
                            _projection = MapProjection.fromNodes(graph.nodeById.values, size);
                            return DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: GestureDetector(
                                  onTapUp: (details) => setState(() => _selectedPoint = details.localPosition),
                                  child: CustomPaint(
                                    painter: _DestinationPickerPainter(
                                      graph: graph,
                                      projection: _projection!,
                                      selectedPoint: _selectedPoint,
                                    ),
                                    child: const SizedBox.expand(),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      PrimaryButton(
                        label: 'この場所を目的地にする',
                        onPressed: () async => _confirm(),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _DestinationPickerPainter extends CustomPainter {
  _DestinationPickerPainter({required this.graph, required this.projection, required this.selectedPoint});

  final RoadGraph graph;
  final MapProjection projection;
  final Offset? selectedPoint;

  @override
  void paint(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.5)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    for (final edge in graph.edgeById.values) {
      final from = graph.nodeById[edge.from];
      final to = graph.nodeById[edge.to];
      if (from == null || to == null) continue;
      canvas.drawLine(projection.toScreen(from.lat, from.lon), projection.toScreen(to.lat, to.lon), roadPaint);
    }

    final point = selectedPoint;
    if (point != null) {
      canvas.drawCircle(point, 10, Paint()..color = Colors.redAccent);
      canvas.drawCircle(
        point,
        10,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DestinationPickerPainter oldDelegate) {
    return oldDelegate.selectedPoint != selectedPoint;
  }
}
