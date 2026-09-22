import 'package:cloud_functions/cloud_functions.dart';
import '../services/spot_retraction_service.dart';
import '../services/spot_vote_service.dart' show SpotVoteKind;

/// Cloud Functions（`functions/index.js`の`requestRetraction` Callable Function）を
/// 呼び出す実装。所有者チェック・状態遷移はすべてサーバー側で行う
/// （`FirestoreSpotVoteService`と同じ設計）。
class FirestoreSpotRetractionService implements SpotRetractionService {
  FirestoreSpotRetractionService(this._functions);

  final FirebaseFunctions _functions;

  @override
  Future<void> retract({required SpotVoteKind kind, required String spotId}) async {
    final callable = _functions.httpsCallable('requestRetraction');
    try {
      await callable.call({
        'spotKind': kind == SpotVoteKind.shade ? 'shade' : 'brightness',
        'spotId': spotId,
      });
    } on FirebaseFunctionsException catch (e) {
      switch (e.code) {
        case 'permission-denied':
          throw SpotRetractionException('自分の投稿のみ取り消せます');
        case 'already-exists':
          throw SpotRetractionException('この投稿はすでに取り消し済みです');
        case 'not-found':
          throw SpotRetractionException('投稿が見つかりません（削除された可能性があります）');
        case 'resource-exhausted':
          throw SpotRetractionException('短時間の操作が集中しています。しばらく待ってから再度お試しください');
        default:
          throw SpotRetractionException('取り消しに失敗しました。もう一度お試しください');
      }
    }
  }
}
