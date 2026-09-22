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
  /// [photoUrl]は「投稿への写真添付」機能（任意）。事前に`SpotPhotoUploadService`で
  /// Cloud Storageへアップロード済みのダウンロードURLを渡す（このメソッド自体はアップロードしない）。
  Future<SpotSubmissionResult> submitSpot({
    required List<({double lat, double lon})> trace,
    required SpotType type,
    String? comment,
    String? photoUrl,
  });

  /// 「オフライン投稿キュー」機能（`QueueingSpotSubmissionService`）向け。
  /// 既にスナップ済みの[SpotSubmissionRequest]（`roadSegmentId`を持つ）を、
  /// 軌跡の再スナップ処理を行わずにそのまま送信する（キューからの再送専用）。
  Future<SpotSubmissionResult> resubmit(SpotSubmissionRequest request);
}

/// オンデバイス版実装。軌跡を道路区間へスナップし、`ModerationConfig` に応じて
/// 即時反映/承認待ちを判定する。共有の`RoadNetworkRepository`のグラフを直接更新することで、
/// ホーム画面の安心スコアにも投稿結果がその場で反映される（デモ用の簡易集計。
/// 本番はサーバー側の重み付け合算バッチに置き換える）。
class LocalSpotSubmissionService implements SpotSubmissionService {
  LocalSpotSubmissionService(
    this._repository, {
    ModerationConfig Function()? moderationConfigProvider,
  }) : _moderationConfigProvider = moderationConfigProvider ?? (() => ModerationConfig.defaultConfig);

  final RoadNetworkRepository _repository;
  final ModerationConfig Function() _moderationConfigProvider;

  @override
  Future<SpotSubmissionResult> submitSpot({
    required List<({double lat, double lon})> trace,
    required SpotType type,
    String? comment,
    String? photoUrl, // オンデバイス版はサーバー永続化を行わないため未使用
  }) async {
    final graph = await _repository.loadGraph();
    final snap = snapTraceToRoad(trace, graph);
    if (snap == null) {
      throw SpotSubmissionException('道路の近くをなぞってください（道路から離れすぎています）');
    }
    return _submitToRoadSegment(snap.edgeId, type);
  }

  @override
  Future<SpotSubmissionResult> resubmit(SpotSubmissionRequest request) async {
    return _submitToRoadSegment(request.roadSegmentId, request.type);
  }

  Future<SpotSubmissionResult> _submitToRoadSegment(String roadSegmentId, SpotType type) async {
    final graph = await _repository.loadGraph();
    final edge = graph.edgeById[roadSegmentId];
    if (edge == null) {
      throw SpotSubmissionException('道路区間が見つかりませんでした');
    }

    // 「人通りが少ない」等の主観的な投稿種別は、地域のモデレーション設定に関わらず
    // 常に承認待ちにする（荒らし対策、`SpotType.requiresManualReview`参照）。
    final reflectMode = !type.requiresManualReview && _moderationConfigProvider().autoApproveAnonymous
        ? ReflectMode.immediate
        : ReflectMode.pendingApproval;

    if (reflectMode == ReflectMode.immediate) {
      // 投稿1件による簡易加重更新（明るさ・人通り投稿は「暗い/少ない」報告を想定し
      // スコアを下げる方向、それ以外＝日陰系の投稿はスコアを上げる方向）。
      // 本番はサーバー側の重み付け合算に置き換える。
      final delta = (type == SpotType.brightness || type == SpotType.lowFootTraffic) ? 0.0 : 1.0;
      edge.shadowScore = ((edge.shadowScore + delta) / 2).clamp(0, 1);
    }

    return SpotSubmissionResult(reflectMode: reflectMode, roadSegmentId: roadSegmentId);
  }
}
