/// 設計書Step7「お知らせ機能」で配信される告知（新機能・地域拡大等）。
class Announcement {
  const Announcement({required this.id, required this.title, required this.body, this.createdAt});

  final String id;
  final String title;
  final String body;
  final DateTime? createdAt;
}
