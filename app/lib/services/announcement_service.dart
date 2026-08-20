import '../models/announcement.dart';

/// お知らせ一覧（設計書Step7）の抽象インターフェース。
abstract class AnnouncementService {
  Future<List<Announcement>> fetchRecent({int limit = 20});
}

/// Firebase未接続環境向けのフォールバック実装。常に空リストを返す。
class LocalAnnouncementService implements AnnouncementService {
  @override
  Future<List<Announcement>> fetchRecent({int limit = 20}) async => const [];
}
