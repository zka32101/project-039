import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/spot_comment.dart';
import '../services/spot_comment_service.dart';

/// Firestoreの`spotComments`コレクションから、NGワードフィルタで承認済み
/// （`moderationStatus == 'approved'`）のコメントを取得する実装。判定は
/// `functions/index.js`の`onSpotCommentCreated`がサーバー側で行う（クライアントは
/// 常に'pending'で作成、`firestore.rules`参照）ため、ここでは判定結果を読むだけでよい。
/// `moderationStatus`＋`createdAt`の複合クエリのため`firestore.indexes.json`に
/// 対応するインデックスが必要（デプロイ手順は`../../README.md`参照）。
class FirestoreSpotCommentService implements SpotCommentService {
  FirestoreSpotCommentService(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Future<List<SpotComment>> fetchRecent({int limit = 20}) async {
    final snapshot = await _firestore
        .collection('spotComments')
        .where('moderationStatus', isEqualTo: 'approved')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return _mapDocs(snapshot);
  }

  @override
  Future<List<SpotComment>> fetchForSpot(String spotId, {int limit = 20}) async {
    final snapshot = await _firestore
        .collection('spotComments')
        .where('spotId', isEqualTo: spotId)
        .where('moderationStatus', isEqualTo: 'approved')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return _mapDocs(snapshot);
  }

  List<SpotComment> _mapDocs(QuerySnapshot<Map<String, dynamic>> snapshot) {
    return snapshot.docs.map((doc) {
      final data = doc.data();
      final createdAt = data['createdAt'];
      return SpotComment(
        id: doc.id,
        text: data['text'] as String? ?? '',
        createdAt: createdAt is Timestamp ? createdAt.toDate() : null,
      );
    }).toList();
  }
}
