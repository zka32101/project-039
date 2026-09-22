import '../models/spot_submission.dart';
import '../models/spot_type.dart';
import 'road_graph_engine/snap_to_road.dart';
import 'road_network_repository.dart';
import 'spot_submission_queue.dart';
import 'spot_submission_service.dart';

/// 「オフライン投稿キュー」機能: 内側の[SpotSubmissionService]（本番では
/// `FirestoreSpotSubmissionService`）の送信に失敗した場合、[SpotSubmissionQueue]へ保存し、
/// [ReflectMode.queuedOffline]として利用者には成功として見せる（電波の悪い場所での
/// ペイント投稿を諦めさせない、というバックログ「オフライン投稿キュー」の意図）。
///
/// 【失敗の種別による分岐】道路スナップ失敗（[SpotSubmissionException]、「道路から離れすぎ」等の
/// 入力自体の不備）は、再送しても解消しないためキューに入れず、そのまま利用者に見せる。
/// それ以外の例外（Firestore書き込み失敗等、多くの場合ネットワーク起因）のみをキュー対象とする。
///
/// キューへ入れる際は、内側のサービスと同じ`snapTraceToRoad`をこの層でも実行し直し、
/// プライバシー設計（生の緯度経度を保持しない。`roadSegmentId`のみ保存）を保ったまま
/// 再送に必要な情報を確保する（ローカルの道路網グラフに対する処理のみで、通信は発生しない）。
class QueueingSpotSubmissionService implements SpotSubmissionService {
  QueueingSpotSubmissionService(this._inner, this._repository, this._queue);

  final SpotSubmissionService _inner;
  final RoadNetworkRepository _repository;
  final SpotSubmissionQueue _queue;

  @override
  Future<SpotSubmissionResult> submitSpot({
    required List<({double lat, double lon})> trace,
    required SpotType type,
    String? comment,
    String? photoUrl,
  }) async {
    try {
      return await _inner.submitSpot(trace: trace, type: type, comment: comment, photoUrl: photoUrl);
    } on SpotSubmissionException {
      rethrow; // 入力自体の不備。再送しても解消しないためキューに入れない
    } catch (_) {
      final graph = await _repository.loadGraph();
      final snap = snapTraceToRoad(trace, graph);
      if (snap == null) {
        throw SpotSubmissionException('道路の近くをなぞってください（道路から離れすぎています）');
      }
      await _queue.enqueue(
        SpotSubmissionRequest(roadSegmentId: snap.edgeId, type: type, comment: comment, photoUrl: photoUrl),
      );
      return SpotSubmissionResult(reflectMode: ReflectMode.queuedOffline, roadSegmentId: snap.edgeId);
    }
  }

  @override
  Future<SpotSubmissionResult> resubmit(SpotSubmissionRequest request) => _inner.resubmit(request);

  /// キューに溜まった投稿を、届く分だけ再送する。1件ずつ順に処理し、失敗したものは
  /// キューに残す（それ以降のエントリも今回はスキップし、次回の呼び出しに委ねる。
  /// ネットワークがまだ不安定な状態で残り全件を試行してエラーを重ねるのを避けるため）。
  /// 戻り値は再送に成功した件数。
  Future<int> flushQueue() async {
    final pending = await _queue.loadAll();
    var sentCount = 0;
    for (final request in pending) {
      try {
        await _inner.resubmit(request);
        sentCount++;
      } catch (_) {
        break; // 以降のエントリは次回の呼び出しに委ねる（ネットワークがまだ不安定な可能性）
      }
    }
    // 成功した先頭sentCount件をキューから削除する（保存順=古い順のため、常に先頭から消せばよい）
    for (var i = 0; i < sentCount; i++) {
      await _queue.removeAt(0);
    }
    return sentCount;
  }
}
