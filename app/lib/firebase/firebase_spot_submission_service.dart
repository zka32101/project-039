import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/moderation_config.dart';
import '../models/spot_submission.dart';
import '../models/spot_type.dart';
import '../services/auth_service.dart';
import '../services/road_graph_engine/snap_to_road.dart';
import '../services/road_network_repository.dart';
import '../services/spot_submission_service.dart';

/// Firestoreへ実際に投稿を永続化する実装。
/// コレクション構成は設計書Step3のデータモデルに準拠:
///   shadeSpots      { roadSegmentId, type, timeDependent, submitterId, status, createdAt, votes }
///   brightnessSpots { roadSegmentId, brightnessLevel, reasonType, submitterId, status, createdAt }
///   spotComments    { spotId, submitterId, text, moderationStatus, createdAt }
///
/// `brightnessSpots`の`reasonType`（'dark'=夜の明るさ投稿 / 'low_foot_traffic'=人通りが少ない投稿）は、
/// 「人通りが少ない」が主観的・偏見の影響を受けやすい投稿種別であることを`handleSpotCreated`
/// （Cloud Functions）が区別し、常に人力承認へ回すために使う（荒らし対策、
/// `SpotType.requiresManualReview`参照）。
///
/// 【重要】status/moderationStatusは常に'pending'で作成する。実際の承認可否（即時反映/承認待ち）は
/// クライアントを信用せずCloud Functions側（functions/index.js の onShadeSpotCreated等）が判定し、
/// 'approved'へ更新する。firestore.rulesもクライアントによる'approved'での作成を拒否する設計。
/// ここで`ModerationConfig`から求める`reflectMode`は、Cloud Functionsも同じ設定を参照して
/// 判定するため「実際にどうなるかの見込み」をUIへ即座に伝えるためのものであり、権限の根拠ではない。
///
/// スナップ処理・即時反映時のローカルグラフ更新は`LocalSpotSubmissionService`と同じロジックを使う
/// （投稿直後のホーム画面表示を待たせないための楽観的更新。恒久的な集計はCloud Functions側で行う）。
class FirestoreSpotSubmissionService implements SpotSubmissionService {
  FirestoreSpotSubmissionService(
    this._firestore,
    this._repository,
    this._authService, {
    ModerationConfig Function()? moderationConfigProvider,
  }) : _moderationConfigProvider = moderationConfigProvider ?? (() => ModerationConfig.defaultConfig);

  final FirebaseFirestore _firestore;
  final RoadNetworkRepository _repository;
  final AuthService _authService;
  final ModerationConfig Function() _moderationConfigProvider;

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

    final submitterId = await _authService.ensureSignedIn();
    final moderationConfig = _moderationConfigProvider();
    final reflectMode = !type.requiresManualReview && moderationConfig.autoApproveAnonymous
        ? ReflectMode.immediate
        : ReflectMode.pendingApproval;

    DocumentReference<Map<String, dynamic>> spotRef;
    if (type == SpotType.brightness || type == SpotType.lowFootTraffic) {
      // UIはまだ明るさレベル(dark/normal/bright)の選択に対応していないため、
      // 「暗いので投稿する」という最も典型的な利用動機を想定し暫定的に'dark'固定とする（次スプリントで選択UI追加）。
      spotRef = await _firestore.collection('brightnessSpots').add({
        'roadSegmentId': snap.edgeId,
        'brightnessLevel': 'dark',
        'reasonType': type == SpotType.lowFootTraffic ? 'low_foot_traffic' : 'dark',
        'submitterId': submitterId,
        'status': 'pending', // Cloud Functions側で承認可否を判定し更新する
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      spotRef = await _firestore.collection('shadeSpots').add({
        'roadSegmentId': snap.edgeId,
        'type': _shadeSpotTypeName(type),
        'timeDependent': type.isTimeDependent,
        'submitterId': submitterId,
        'status': 'pending', // Cloud Functions側で承認可否を判定し更新する
        'createdAt': FieldValue.serverTimestamp(),
        'votes': 0,
      });
    }

    if (comment != null && comment.isNotEmpty) {
      await _firestore.collection('spotComments').add({
        'spotId': spotRef.id,
        'submitterId': submitterId,
        'text': comment,
        'moderationStatus': 'pending', // NGワードフィルタ判定はCloud Functions側（onSpotCommentCreated）
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    if (reflectMode == ReflectMode.immediate) {
      final edge = graph.edgeById[snap.edgeId]!;
      // 照度・低交通量スポットはshadowScoreではなく、
      // バックエンド側でaggregatedBrightnessScoreとして集計されるため、
      // クライアント側では更新しない
      if (type != SpotType.brightness && type != SpotType.lowFootTraffic) {
        edge.shadowScore = ((edge.shadowScore + 1.0) / 2).clamp(0, 1);
      }
    }

    return SpotSubmissionResult(reflectMode: reflectMode, roadSegmentId: snap.edgeId);
  }

  String _shadeSpotTypeName(SpotType type) {
    switch (type) {
      case SpotType.tree:
        return 'tree';
      case SpotType.arcade:
        return 'arcade';
      case SpotType.rainShelter:
        return 'rain_shelter';
      case SpotType.brightness:
      case SpotType.lowFootTraffic:
        throw ArgumentError('${type.name}はbrightnessSpotsコレクションで扱う');
    }
  }
}
