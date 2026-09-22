import 'spot_vote_service.dart' show SpotVoteKind;

/// 投稿の取り消し申請呼び出し失敗時の例外。他のサービス例外と同じ設計。
class SpotRetractionException implements Exception {
  SpotRetractionException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// 「投稿の取り消し申請」機能の抽象インターフェース。自分の誤投稿・古くなった投稿を
/// 取り消すための操作（`functions/index.js`の`requestRetraction`参照）。
abstract class SpotRetractionService {
  /// [spotId]（`shadeSpots`/`brightnessSpots`のドキュメントID）を取り消す。
  /// 自分以外の投稿・すでに取り消し済みの場合は[SpotRetractionException]を投げる。
  Future<void> retract({required SpotVoteKind kind, required String spotId});
}

/// Firebase未接続環境向けのフォールバック実装。機能自体を無効化する
/// （`LocalSpotVoteService`と同じ設計）。
class LocalSpotRetractionService implements SpotRetractionService {
  @override
  Future<void> retract({required SpotVoteKind kind, required String spotId}) async {
    throw SpotRetractionException('この環境では取り消し機能を利用できません');
  }
}
