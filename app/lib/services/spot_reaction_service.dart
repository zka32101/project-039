/// コメントへの軽量リアクション（共感ボタン）呼び出し失敗時の例外。
/// [SpotVoteException]と同じ設計、日本語のユーザー向けメッセージを保持する。
class SpotReactionException implements Exception {
  SpotReactionException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// コメントへの軽量リアクション（共感ボタン）の抽象インターフェース。
/// 投稿の確認投票／通報（`SpotVoteService`）ほど重い意味を持たない、気軽な共感表現の手段。
abstract class SpotReactionService {
  /// [commentId]（`spotComments`のドキュメントID）に共感リアクションを付ける。
  /// 二重リアクション・レート制限超過時は[SpotReactionException]を投げる。
  /// 成功時は更新後の共感数を返す。
  Future<int> react(String commentId);
}

/// Firebase未接続環境向けのフォールバック実装。リアクション機能自体を無効化する。
class LocalSpotReactionService implements SpotReactionService {
  @override
  Future<int> react(String commentId) async {
    throw SpotReactionException('この環境では共感機能を利用できません');
  }
}
