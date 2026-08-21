import 'package:cloud_functions/cloud_functions.dart';
import '../services/spot_vote_service.dart';

/// Cloud Functions（`functions/index.js`の`voteSpot` Callable Function）を呼び出す実装。
/// 不正利用対策（自演投票禁止・二重投票禁止・レート制限）はすべてサーバー側で行う
/// （クライアントを信用しない設計、`functions/src/spotVoting.js`参照）。
class FirestoreSpotVoteService implements SpotVoteService {
  FirestoreSpotVoteService(this._functions);

  final FirebaseFunctions _functions;

  @override
  Future<void> vote({required SpotVoteKind kind, required String spotId, required SpotVoteType voteType}) async {
    final callable = _functions.httpsCallable('voteSpot');
    try {
      await callable.call({
        'spotKind': kind == SpotVoteKind.shade ? 'shade' : 'brightness',
        'spotId': spotId,
        'voteType': voteType == SpotVoteType.confirm ? 'confirm' : 'report',
      });
    } on FirebaseFunctionsException catch (e) {
      switch (e.code) {
        case 'failed-precondition':
          throw SpotVoteException('自分の投稿には投票できません');
        case 'already-exists':
          throw SpotVoteException('この投稿にはすでに投票済みです');
        case 'not-found':
          throw SpotVoteException('投稿が見つかりません（削除された可能性があります）');
        case 'resource-exhausted':
          throw SpotVoteException('短時間の投票が集中しています。しばらく待ってから再度お試しください');
        default:
          throw SpotVoteException('投票に失敗しました。もう一度お試しください');
      }
    }
  }
}
