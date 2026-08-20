import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/announcement.dart';
import '../services/announcement_service.dart';

/// Firestoreの`announcements`コレクションからお知らせ一覧を取得する実装。
/// ドキュメントは運営が管理コンソール等から作成する想定（`firestore.rules`で
/// クライアントからの書き込みは禁止）。作成をトリガーに`functions/index.js`の
/// `onAnnouncementCreated`がプッシュ通知（`announcements`トピック）を送信する。
class FirestoreAnnouncementService implements AnnouncementService {
  FirestoreAnnouncementService(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Future<List<Announcement>> fetchRecent({int limit = 20}) async {
    final snapshot = await _firestore
        .collection('announcements')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      final createdAt = data['createdAt'];
      return Announcement(
        id: doc.id,
        title: data['title'] as String? ?? '',
        body: data['body'] as String? ?? '',
        createdAt: createdAt is Timestamp ? createdAt.toDate() : null,
      );
    }).toList();
  }
}
