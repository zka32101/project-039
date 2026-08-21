import '../models/spot_summary.dart';

/// 承認済み投稿一覧取得の抽象インターフェース。`AnnouncementService`/`SpotCommentService`と
/// 同じ「取得専用・一覧表示」の構成を踏襲している。
abstract class SpotListService {
  /// 承認済み（`status == 'approved'`）の投稿を新着順に返す（`shadeSpots`/`brightnessSpots`横断）。
  Future<List<SpotSummary>> fetchRecentApproved({int limit = 20});
}

/// Firebase未接続環境向けのフォールバック実装。常に空リストを返す。
class LocalSpotListService implements SpotListService {
  @override
  Future<List<SpotSummary>> fetchRecentApproved({int limit = 20}) async => const [];
}
