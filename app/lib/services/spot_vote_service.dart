/// 投稿の相互チェック（確認投票／通報）の種別。
enum SpotVoteType { confirm, report }

/// 投票対象の投稿種別（Firestoreのコレクション名に対応）。
enum SpotVoteKind { shade, brightness }

/// `voteSpot`（Cloud Functions）呼び出し失敗時の例外。`HomeViewModel`等のエラー表示に
/// そのまま渡せるよう、日本語のユーザー向けメッセージを保持する
/// （`RouteSearchException`と同じ設計、`route_search_service.dart`参照）。
class SpotVoteException implements Exception {
  SpotVoteException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// 投稿の相互チェック（確認投票／通報）の抽象インターフェース。
///
/// 【現状】バックエンド（`functions/index.js`の`voteSpot`）とFirestoreルール・インデックスは
/// 実装済みだが、投票ボタンを表示するクライアント側UI（個々の投稿を一覧・詳細表示する画面）は
/// このセッションの範囲では未実装（`app/README.md`「このセッションで実装していない範囲」参照）。
/// 本サービスはそのUIから呼び出せるよう、呼び出し口だけを先行して用意したもの。
abstract class SpotVoteService {
  /// [spotId]（`shadeSpots`/`brightnessSpots`のドキュメントID）に対して投票する。
  /// 自分自身の投稿への投票・二重投票・レート制限超過時は[SpotVoteException]を投げる。
  Future<void> vote({required SpotVoteKind kind, required String spotId, required SpotVoteType voteType});
}

/// Firebase未接続環境向けのフォールバック実装。投票機能自体を無効化する
/// （サーバー側の不正利用対策ロジックが無い状態で投票を成立させると、対策の意味が無いため）。
class LocalSpotVoteService implements SpotVoteService {
  @override
  Future<void> vote({required SpotVoteKind kind, required String spotId, required SpotVoteType voteType}) async {
    throw SpotVoteException('この環境では投票機能を利用できません');
  }
}
