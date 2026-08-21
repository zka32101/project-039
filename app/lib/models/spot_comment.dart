/// 投稿（`shadeSpots`/`brightnessSpots`）に付随するコメント（設計書のコメント機能）。
/// `spotComments`コレクションはこれまで書き込み専用（投稿時に付随データとして保存するのみ）で、
/// 閲覧できるUIが無かった。本モデルはNGワードフィルタで承認済み（`moderationStatus == 'approved'`）
/// のコメントを一覧表示する「みんなの声」画面（`SpotCommentsListView`）向け。
class SpotComment {
  const SpotComment({required this.id, required this.text, this.createdAt});

  final String id;
  final String text;
  final DateTime? createdAt;
}
