import 'package:cloud_functions/cloud_functions.dart';
import '../services/spot_reaction_service.dart';

/// Cloud Functions（`functions/index.js`の`reactToComment` Callable Function）を呼び出す実装。
/// 二重リアクション禁止・レート制限はすべてサーバー側で行う（`FirestoreSpotVoteService`と同じ設計）。
class FirestoreSpotReactionService implements SpotReactionService {
  FirestoreSpotReactionService(this._functions);

  final FirebaseFunctions _functions;

  @override
  Future<int> react(String commentId) async {
    final callable = _functions.httpsCallable('reactToComment');
    try {
      final result = await callable.call({'commentId': commentId});
      final data = Map<String, dynamic>.from(result.data as Map);
      return (data['likeCount'] as num).toInt();
    } on FirebaseFunctionsException catch (e) {
      switch (e.code) {
        case 'already-exists':
          throw SpotReactionException('このコメントにはすでに共感済みです');
        case 'not-found':
          throw SpotReactionException('コメントが見つかりません（削除された可能性があります）');
        case 'resource-exhausted':
          throw SpotReactionException('短時間の操作が集中しています。しばらく待ってから再度お試しください');
        default:
          throw SpotReactionException('共感に失敗しました。もう一度お試しください');
      }
    }
  }
}
