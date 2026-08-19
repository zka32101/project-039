import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/spot_submission.dart';
import '../../models/spot_type.dart';
import '../../services/road_graph_engine/graph.dart';
import '../../services/road_graph_engine/snap_to_road.dart';
import '../../services/spot_submission_service.dart';
import '../../viewmodels/providers.dart';
import '../../widgets/primary_button.dart';
import 'widgets/paint_canvas.dart';
import 'widgets/spot_type_selector.dart';

enum _PaintStep { loading, typeSelection, drawing, confirming, submitting, success }

/// 投稿フロー全体（設計書Step2「投稿フロー（ペイント式）」に対応）:
/// 種別選択 → 指で地図をなぞる → 歩道エッジへ自動スナップ → 確定演出 →
/// [本人確認済みユーザーのみ] コメント追加可 → 投稿完了（反映モードにより即時反映/承認待ち表示）
class PaintSubmissionView extends ConsumerStatefulWidget {
  const PaintSubmissionView({super.key});

  @override
  ConsumerState<PaintSubmissionView> createState() => _PaintSubmissionViewState();
}

class _PaintSubmissionViewState extends ConsumerState<PaintSubmissionView> {
  _PaintStep _step = _PaintStep.loading;
  RoadGraph? _graph;
  SpotType? _selectedType;
  String? _snappedEdgeId;
  List<({double lat, double lon})>? _lastTrace;
  ReflectMode? _resultReflectMode;
  String? _errorMessage;

  // 本人確認基盤は未実装（次スプリント）。デモとして手動トグルで
  // 「本人確認済みユーザーのみコメント投稿可」の分岐だけ再現する。
  bool _isVerifiedDemo = false;
  final _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadGraph();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadGraph() async {
    final graph = await ref.read(roadNetworkRepositoryProvider).loadGraph();
    if (!mounted) return;
    setState(() {
      _graph = graph;
      _step = _PaintStep.typeSelection;
    });
  }

  void _selectType(SpotType type) {
    setState(() {
      _selectedType = type;
      _step = _PaintStep.drawing;
    });
  }

  void _handleTraceEnd(List<({double lat, double lon})> trace) {
    final graph = _graph;
    if (graph == null) return;
    final snap = snapTraceToRoad(trace, graph);
    if (snap == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('道路から離れすぎています。もう一度なぞってください')),
      );
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _snappedEdgeId = snap.edgeId;
      _lastTrace = trace;
      _step = _PaintStep.confirming;
    });
  }

  void _backToDrawing() {
    setState(() {
      _snappedEdgeId = null;
      _lastTrace = null;
      _step = _PaintStep.drawing;
    });
  }

  Future<void> _confirmSubmit() async {
    final trace = _lastTrace;
    final type = _selectedType;
    if (trace == null || type == null) return;

    setState(() {
      _step = _PaintStep.submitting;
      _errorMessage = null;
    });

    try {
      final comment = _isVerifiedDemo && _commentController.text.trim().isNotEmpty
          ? _commentController.text.trim()
          : null;
      final result = await ref.read(spotSubmissionServiceProvider).submitSpot(
            trace: trace,
            type: type,
            comment: comment,
          );

      final analytics = ref.read(analyticsServiceProvider);
      analytics.logSpotSubmitted(type.name);
      if (comment != null) analytics.logCommentAdded();

      HapticFeedback.mediumImpact();
      if (!mounted) return;
      setState(() {
        _resultReflectMode = result.reflectMode;
        _step = _PaintStep.success;
      });
    } on SpotSubmissionException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _step = _PaintStep.drawing;
        _snappedEdgeId = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '投稿に失敗しました。もう一度お試しください';
        _step = _PaintStep.drawing;
        _snappedEdgeId = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('塗って投稿')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: switch (_step) {
            _PaintStep.loading => const Center(child: CircularProgressIndicator()),
            _PaintStep.typeSelection => _TypeSelectionStep(onSelected: _selectType),
            _PaintStep.drawing => _DrawingStep(
                graph: _graph!,
                type: _selectedType!,
                errorMessage: _errorMessage,
                onTraceEnd: _handleTraceEnd,
                onChangeType: () => setState(() => _step = _PaintStep.typeSelection),
              ),
            _PaintStep.confirming => _ConfirmingStep(
                graph: _graph!,
                type: _selectedType!,
                snappedEdgeId: _snappedEdgeId!,
                isVerifiedDemo: _isVerifiedDemo,
                commentController: _commentController,
                onToggleVerified: (v) => setState(() => _isVerifiedDemo = v),
                onRetry: _backToDrawing,
                onConfirm: _confirmSubmit,
              ),
            _PaintStep.submitting => const Center(child: CircularProgressIndicator()),
            _PaintStep.success => _SuccessStep(
                type: _selectedType!,
                reflectMode: _resultReflectMode!,
                onDone: () => Navigator.of(context).pop(),
              ),
          },
        ),
      ),
    );
  }
}

class _TypeSelectionStep extends StatelessWidget {
  const _TypeSelectionStep({required this.onSelected});
  final ValueChanged<SpotType> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('何を投稿しますか？', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        const Text('道の様子を選んでください'),
        const SizedBox(height: 20),
        SpotTypeSelector(selected: null, onSelected: onSelected),
      ],
    );
  }
}

class _DrawingStep extends StatelessWidget {
  const _DrawingStep({
    required this.graph,
    required this.type,
    required this.errorMessage,
    required this.onTraceEnd,
    required this.onChangeType,
  });

  final RoadGraph graph;
  final SpotType type;
  final String? errorMessage;
  final void Function(List<({double lat, double lon})>) onTraceEnd;
  final VoidCallback onChangeType;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(type.icon, color: type.color),
            const SizedBox(width: 8),
            Expanded(child: Text('${type.label}を、指で道になぞってください', style: Theme.of(context).textTheme.titleMedium)),
            TextButton(onPressed: onChangeType, child: const Text('種別を変更')),
          ],
        ),
        if (errorMessage != null) ...[
          const SizedBox(height: 8),
          Text(errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
        const SizedBox(height: 16),
        PaintCanvas(graph: graph, spotType: type, highlightEdgeId: null, onTraceEnd: onTraceEnd),
      ],
    );
  }
}

class _ConfirmingStep extends StatelessWidget {
  const _ConfirmingStep({
    required this.graph,
    required this.type,
    required this.snappedEdgeId,
    required this.isVerifiedDemo,
    required this.commentController,
    required this.onToggleVerified,
    required this.onRetry,
    required this.onConfirm,
  });

  final RoadGraph graph;
  final SpotType type;
  final String snappedEdgeId;
  final bool isVerifiedDemo;
  final TextEditingController commentController;
  final ValueChanged<bool> onToggleVerified;
  final VoidCallback onRetry;
  final Future<void> Function() onConfirm;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_outline, color: type.color),
              const SizedBox(width: 8),
              Expanded(child: Text('この道でよろしいですか？', style: Theme.of(context).textTheme.titleMedium)),
            ],
          ),
          const SizedBox(height: 16),
          PaintCanvas(graph: graph, spotType: type, highlightEdgeId: snappedEdgeId, onTraceEnd: (_) {}),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: isVerifiedDemo,
            onChanged: onToggleVerified,
            title: const Text('本人確認済みとして投稿（デモ用）'),
            subtitle: const Text('本人確認済みユーザーのみコメントを追加できます'),
          ),
          if (isVerifiedDemo) ...[
            const SizedBox(height: 8),
            TextField(
              controller: commentController,
              maxLength: 140,
              decoration: const InputDecoration(
                labelText: 'コメント（任意）',
                border: OutlineInputBorder(),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(onPressed: onRetry, child: const Text('やり直す')),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PrimaryButton(label: 'この道に投稿する', onPressed: onConfirm),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SuccessStep extends StatelessWidget {
  const _SuccessStep({required this.type, required this.reflectMode, required this.onDone});

  final SpotType type;
  final ReflectMode reflectMode;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final isImmediate = reflectMode == ReflectMode.immediate;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 320),
            curve: Curves.elasticOut,
            builder: (context, value, child) => Transform.scale(scale: value, child: child),
            child: Icon(Icons.check_circle, size: 96, color: type.color),
          ),
          const SizedBox(height: 20),
          Text(
            isImmediate ? '地図に反映されました！' : '投稿ありがとうございます',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            isImmediate
                ? 'あなたの投稿が、次にここを歩く誰かの安心につながります'
                : '内容を確認のうえ、順次地図へ反映します（承認待ち）',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          PrimaryButton(label: '地図に戻る', onPressed: () async => onDone()),
        ],
      ),
    );
  }
}
