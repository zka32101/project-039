import 'package:cloud_functions/cloud_functions.dart';
import '../services/spot_dispute_service.dart';
import '../services/spot_vote_service.dart' show SpotVoteKind;

/// Cloud Functions（`functions/index.js`の`disputeSpotReport` Callable Function）を
/// 呼び出す実装。異議申し立て可能な状態かどうかの判定はすべてサーバー側で行う
/// （`FirestoreSpotVoteService`と同じ設計）。
class FirestoreSpotDisputeService implements SpotDisputeService {
  FirestoreSpotDisputeService(this._functions);

  final FirebaseFunctions _functions;

  @override
  Future<void> dispute({required SpotVoteKind kind, required String spotId, required String message}) async {
    final callable = _functions.httpsCallable('disputeSpotReport');
    try {
      await callable.call({
        'spotKind': kind == SpotVoteKind.shade ? 'shade' : 'brightness',
        'spotId': spotId,
        'message': message,
      });
    } on FirebaseFunctionsException catch (e) {
      switch (e.code) {
        case 'permission-denied':
          throw SpotDisputeException('自分の投稿のみ異議申し立てできます');
        case 'failed-precondition':
          throw SpotDisputeException('この投稿は現在異議申し立ての対象ではありません');
        case 'not-found':
          throw SpotDisputeException('投稿が見つかりません（削除された可能性があります）');
        case 'invalid-argument':
          throw SpotDisputeException('メッセージを確認してください');
        case 'resource-exhausted':
          throw SpotDisputeException('短時間の操作が集中しています。しばらく待ってから再度お試しください');
        default:
          throw SpotDisputeException('異議申し立てに失敗しました。もう一度お試しください');
      }
    }
  }
}
