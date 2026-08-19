import 'package:flutter/material.dart';
import '../../../models/spot_type.dart';
import '../../../services/road_graph_engine/graph.dart';
import '../../../services/map_projection.dart';

/// 投稿UIの中心となるキャンバス。道路網を背景に描画し、指でなぞった軌跡を
/// リアルタイムに追従表示する（設計書Step5.5「塗っている間はブラシ色が軌跡に追従」）。
class PaintCanvas extends StatefulWidget {
  const PaintCanvas({
    super.key,
    required this.graph,
    required this.spotType,
    required this.highlightEdgeId,
    required this.onTraceEnd,
  });

  final RoadGraph graph;
  final SpotType spotType;

  /// スナップ確定済みの区間があればハイライト表示する
  final String? highlightEdgeId;

  /// 指を離した時点の軌跡（画面座標）を、緯度経度へ変換したうえで通知する
  final void Function(List<({double lat, double lon})> latLonTrace) onTraceEnd;

  @override
  State<PaintCanvas> createState() => _PaintCanvasState();
}

class _PaintCanvasState extends State<PaintCanvas> {
  final List<Offset> _points = [];
  MapProjection? _projection;

  void _handlePanUpdate(DragUpdateDetails details) {
    final box = context.findRenderObject() as RenderBox;
    final local = box.globalToLocal(details.globalPosition);
    setState(() => _points.add(local));
  }

  void _handlePanEnd() {
    final projection = _projection;
    if (projection == null || _points.isEmpty) return;
    final latLonTrace = _points.map((p) => projection.toLatLon(p)).toList();
    widget.onTraceEnd(latLonTrace);
    // スナップ失敗時にすぐ描き直せるよう、判定結果を問わず軌跡をクリアする
    // （成功時はステップ遷移で本Widget自体が破棄されるため実害はない）
    _clear();
  }

  void _clear() => setState(_points.clear);

  @override
  void didUpdateWidget(covariant PaintCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.highlightEdgeId != widget.highlightEdgeId && widget.highlightEdgeId == null) {
      _clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          _projection = MapProjection.fromNodes(widget.graph.nodeById.values, size);

          return DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: GestureDetector(
                onPanUpdate: _handlePanUpdate,
                onPanEnd: (_) => _handlePanEnd(),
                child: CustomPaint(
                  painter: _PaintCanvasPainter(
                    graph: widget.graph,
                    projection: _projection!,
                    trace: _points,
                    traceColor: widget.spotType.color,
                    highlightEdgeId: widget.highlightEdgeId,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PaintCanvasPainter extends CustomPainter {
  _PaintCanvasPainter({
    required this.graph,
    required this.projection,
    required this.trace,
    required this.traceColor,
    required this.highlightEdgeId,
  });

  final RoadGraph graph;
  final MapProjection projection;
  final List<Offset> trace;
  final Color traceColor;
  final String? highlightEdgeId;

  @override
  void paint(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = Colors.grey.withOpacity(0.35)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    for (final edge in graph.edgeById.values) {
      final from = graph.nodeById[edge.from];
      final to = graph.nodeById[edge.to];
      if (from == null || to == null) continue;
      canvas.drawLine(
        projection.toScreen(from.lat, from.lon),
        projection.toScreen(to.lat, to.lon),
        edge.id == highlightEdgeId
            ? (Paint()
              ..color = traceColor
              ..strokeWidth = 9
              ..strokeCap = StrokeCap.round)
            : roadPaint,
      );
    }

    if (trace.length > 1) {
      final tracePaint = Paint()
        ..color = traceColor.withOpacity(0.85)
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      final path = Path()..moveTo(trace.first.dx, trace.first.dy);
      for (final p in trace.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, tracePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _PaintCanvasPainter oldDelegate) {
    return oldDelegate.trace != trace || oldDelegate.highlightEdgeId != highlightEdgeId;
  }
}
