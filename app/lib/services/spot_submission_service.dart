import '../models/moderation_config.dart';
import '../models/spot_submission.dart';
import '../models/spot_type.dart';
import 'road_graph_engine/snap_to_road.dart';
import 'road_network_repository.dart';

class SpotSubmissionException implements Exception {
  SpotSubmissionException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// 投稿反映サービスの抽象インターフェース。設計書の `submitSpot()` に対応。
/// 本番ではCloud Functionsへの呼び出し（NGワードフィルタ→モデレーション判定）に置き換える。
abstract class SpotSubmissionService {
  Future<SpotSubmissionResult> submitSpot({
    required List<({double lat, double lon})> trace,
    required SpotType type,
    String? comment,
  });
}

/// オンデバイス版実装。軌跡を道路区間へスナップし、`ModerationConfig` に応じて
/// 即時反映/承認待ちを判定する。共有の`RoadNetworkRepository`のグラフを直接更新することで、
/// ホーム画面の安心スコアにも投稿結果がその場で反映される（デモ用の簡易集計。
/// 本番はサーバー側の重み付け合算バッチに置き換える）。
class LocalSpotSubmissionService implements SpotSubmissionService {
  LocalSpotSubmissionService(
    this._repository, {
    this.moderationConfig = ModerationConfig.defaultConfig,
  });

  final RoadNetworkRepository _repository;
  final ModerationConfig moderationConfig;

  @override
  Future<SpotSubmissionResult> submitSpot({
    required List<({double lat, double lon})> trace,
    required SpotType type,
    String? comment,
  }) async {
    final graph = await _repository.loadGraph();
    final snap = snapTraceToRoad(trace, graph);
    if (snap == null) {
      throw SpotSubmissionException('道路の近くをなぞってください（道路から離れすぎています）');
    }

    final reflectMode = moderationConfig.autoApproveAnonymous
        ? ReflectMode.immediate
        : ReflectMode.pendingApproval;

    if (reflectMode == ReflectMode.immediate) {
      final edge = graph.edgeById[snap.edgeId]!;
      // 投稿1件による簡易加重更新（明るさ投稿は「暗い」報告を想定しスコアを下げる方向、
      // それ以外＝日陰系の投稿はスコアを上げる方向）。本番はサーバー側の重み付け合算に置き換える。
      final delta = type == SpotType.brightness ? 0.0 : 1.0;
      edge.shadowScore = ((edge.shadowScore + delta) / 2).clamp(0, 1);
    }

    return SpotSubmissionResult(reflectMode: reflectMode, roadSegmentId: snap.edgeId);
  }
}
