import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/spot_summary.dart';
import '../services/spot_list_service.dart';
import '../services/spot_vote_service.dart' show SpotVoteKind;

const _shadeTypeLabels = {
  'tree': '木陰',
  'arcade': 'アーケード',
  'rain_shelter': '雨よけ',
};

const _brightnessReasonLabels = {
  'dark': '夜の明るさ',
  'low_foot_traffic': '人通りが少ない',
};

/// Firestoreの`shadeSpots`/`brightnessSpots`から、承認済み（`status == 'approved'`）の投稿を
/// 取得する実装。2つのコレクションを個別に問い合わせてからマージし、`createdAt`降順で
/// 上位[limit]件を返す（単一クエリで横断できないFirestoreの制約に対応。
/// `rateLimiting.js`の`countRecentSubmissions`が同じ2コレクション横断を行っているのと同じ考え方）。
/// `status`＋`createdAt`の複合クエリのため`firestore.indexes.json`に対応するインデックスが必要。
class FirestoreSpotListService implements SpotListService {
  FirestoreSpotListService(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Future<List<SpotSummary>> fetchRecentApproved({int limit = 20}) async {
    final results = await Future.wait([
      _fetchCollection('shadeSpots', SpotVoteKind.shade, limit),
      _fetchCollection('brightnessSpots', SpotVoteKind.brightness, limit),
    ]);

    final merged = [...results[0], ...results[1]]
      ..sort((a, b) {
        final aTime = a.createdAt;
        final bTime = b.createdAt;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      });

    return merged.take(limit).toList();
  }

  Future<List<SpotSummary>> _fetchCollection(String collection, SpotVoteKind kind, int limit) async {
    final snapshot = await _firestore
        .collection(collection)
        .where('status', isEqualTo: 'approved')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      final createdAt = data['createdAt'];
      final label = kind == SpotVoteKind.shade
          ? _shadeTypeLabels[data['type']] ?? '投稿'
          : _brightnessReasonLabels[data['reasonType']] ?? '投稿';
      return SpotSummary(
        id: doc.id,
        kind: kind,
        label: label,
        votes: (data['votes'] as num?)?.toInt() ?? 0,
        reportCount: (data['reportCount'] as num?)?.toInt() ?? 0,
        createdAt: createdAt is Timestamp ? createdAt.toDate() : null,
      );
    }).toList();
  }
}
