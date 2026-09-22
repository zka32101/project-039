import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/spot_summary.dart';
import '../services/spot_list_service.dart';
import '../services/spot_vote_service.dart' show SpotVoteKind;

const _shadeTypeLabels = {
  'tree': '木陰',
  'arcade': 'アーケード',
  'rain_shelter': '雨よけ',
  'uneven_ground': '段差・でこぼこ',
  'dark_stairs': '暗い階段',
  'narrow_sidewalk': '狭い歩道',
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
      _fetchCollection('shadeSpots', SpotVoteKind.shade, limit, statusFilter: 'approved'),
      _fetchCollection('brightnessSpots', SpotVoteKind.brightness, limit, statusFilter: 'approved'),
    ]);

    return _mergeNewestFirst(results, limit);
  }

  @override
  Future<List<SpotSummary>> fetchOwnSubmissions(String submitterId, {int limit = 50}) async {
    final results = await Future.wait([
      _fetchCollection('shadeSpots', SpotVoteKind.shade, limit, submitterId: submitterId),
      _fetchCollection('brightnessSpots', SpotVoteKind.brightness, limit, submitterId: submitterId),
    ]);

    return _mergeNewestFirst(results, limit);
  }

  List<SpotSummary> _mergeNewestFirst(List<List<SpotSummary>> results, int limit) {
    final merged = results.expand((r) => r).toList()
      ..sort((a, b) {
        final aTime = a.createdAt;
        final bTime = b.createdAt;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      });

    return merged.take(limit).toList();
  }

  /// [statusFilter]指定時（一般公開の「投稿を確認」画面）は`status`＋`createdAt`降順の
  /// 複合インデックスを使う。[submitterId]指定時（マイページ）は既存の
  /// `submitterId`＋`createdAt`昇順インデックス（レート制限判定用に既存）をそのまま流用し、
  /// 新しいインデックス定義を追加せずに済ませる（Dart側で降順に並べ替える）。
  Future<List<SpotSummary>> _fetchCollection(
    String collection,
    SpotVoteKind kind,
    int limit, {
    String? statusFilter,
    String? submitterId,
  }) async {
    Query<Map<String, dynamic>> query = _firestore.collection(collection);
    if (statusFilter != null) {
      query = query.where('status', isEqualTo: statusFilter).orderBy('createdAt', descending: true);
    } else if (submitterId != null) {
      query = query.where('submitterId', isEqualTo: submitterId).orderBy('createdAt');
    }
    final snapshot = await query.limit(limit).get();

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
        status: data['status'] as String? ?? 'approved',
      );
    }).toList();
  }
}
