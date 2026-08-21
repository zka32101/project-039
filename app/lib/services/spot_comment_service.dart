import '../models/spot_comment.dart';

/// コメント（`spotComments`）一覧取得の抽象インターフェース。`AnnouncementService`と
/// 同じ「取得専用・運営が承認したものだけを返す」構成を踏襲している。
abstract class SpotCommentService {
  /// NGワードフィルタで承認済み（`moderationStatus == 'approved'`）のコメントを新着順に返す。
  Future<List<SpotComment>> fetchRecent({int limit = 20});

  /// 指定した投稿（`shadeSpots`/`brightnessSpots`のドキュメントID）に付けられた、承認済みの
  /// コメントのみを新着順に返す（「投稿を確認」画面からの個別投稿のコメント表示用）。
  Future<List<SpotComment>> fetchForSpot(String spotId, {int limit = 20});
}

/// Firebase未接続環境向けのフォールバック実装。常に空リストを返す。
class LocalSpotCommentService implements SpotCommentService {
  @override
  Future<List<SpotComment>> fetchRecent({int limit = 20}) async => const [];

  @override
  Future<List<SpotComment>> fetchForSpot(String spotId, {int limit = 20}) async => const [];
}
