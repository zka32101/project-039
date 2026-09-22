import '../services/spot_vote_service.dart' show SpotVoteKind;

/// 投稿一覧画面（`SpotsListView`）で表示する、承認済み投稿（`shadeSpots`/`brightnessSpots`）の
/// 要約。確認投票／通報（`voteSpot`）の対象を選ぶための最小限の情報のみを持つ
/// （生の緯度経度は含めない、プライバシー設計の方針は他の画面と同じ）。
class SpotSummary {
  const SpotSummary({
    required this.id,
    required this.kind,
    required this.label,
    required this.votes,
    required this.reportCount,
    this.createdAt,
    this.status = 'approved',
  });

  final String id;
  final SpotVoteKind kind;

  /// 投稿種別の表示名（例:「木陰」「夜の明るさ」）。`SpotType.label`と同じ文言だが、
  /// Firestoreの生データ（`type`/`reasonType`）からの変換は取得側（Firebase実装）で行う。
  final String label;

  final int votes;
  final int reportCount;
  final DateTime? createdAt;

  /// モデレーション状態（'pending'/'approved'）。「投稿を確認」画面（承認済みのみ）では
  /// 常に'approved'固定だが、「マイページ」（自分の投稿履歴）では審査待ちの投稿も
  /// 表示するため、状態をそのまま保持する。
  final String status;
}
