import 'spot_type.dart';

enum ReflectMode { immediate, pendingApproval }

/// ユーザーが投稿を確定した際にサーバー（本番ではCloud Functions）へ送る内容。
/// **プライバシー設計の核**: 生の緯度経度は含めず、スナップ後の`roadSegmentId`のみを送信する。
class SpotSubmissionRequest {
  const SpotSubmissionRequest({required this.roadSegmentId, required this.type, this.comment});

  final String roadSegmentId;
  final SpotType type;

  /// 本人確認済みユーザーのみ入力可能（設計書「本人確認済みユーザーのみコメント投稿可」）。
  final String? comment;
}

class SpotSubmissionResult {
  const SpotSubmissionResult({required this.reflectMode, required this.roadSegmentId});

  final ReflectMode reflectMode;
  final String roadSegmentId;
}
