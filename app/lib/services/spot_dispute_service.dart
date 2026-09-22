import 'spot_vote_service.dart' show SpotVoteKind;

/// 通報への異議申し立て呼び出し失敗時の例外。他のサービス例外と同じ設計。
class SpotDisputeException implements Exception {
  SpotDisputeException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// 「通報された投稿者への異議申し立て」機能の抽象インターフェース。通報を受けて
/// 人力再審査待ちに差し戻された自分の投稿に、一言説明を添えられる
/// （`functions/index.js`の`disputeSpotReport`参照）。
abstract class SpotDisputeService {
  /// [spotId]（`shadeSpots`/`brightnessSpots`のドキュメントID）に異議申し立てメッセージを送る。
  /// 自分以外の投稿・異議申し立て対象外の状態の場合は[SpotDisputeException]を投げる。
  Future<void> dispute({required SpotVoteKind kind, required String spotId, required String message});
}

/// Firebase未接続環境向けのフォールバック実装。機能自体を無効化する。
class LocalSpotDisputeService implements SpotDisputeService {
  @override
  Future<void> dispute({required SpotVoteKind kind, required String spotId, required String message}) async {
    throw SpotDisputeException('この環境では異議申し立て機能を利用できません');
  }
}
