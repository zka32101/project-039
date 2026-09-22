import 'spot_type.dart';

enum ReflectMode {
  immediate,
  pendingApproval,

  /// 「オフライン投稿キュー」機能: 送信時にオフライン等でサーバーへ届かなかったため、
  /// 端末内のキューに保存し、後で自動再送する状態（`SpotSubmissionQueue`参照）。
  queuedOffline,
}

/// ユーザーが投稿を確定した際にサーバー（本番ではCloud Functions）へ送る内容。
/// **プライバシー設計の核**: 生の緯度経度は含めず、スナップ後の`roadSegmentId`のみを送信する。
class SpotSubmissionRequest {
  const SpotSubmissionRequest({required this.roadSegmentId, required this.type, this.comment, this.photoUrl});

  final String roadSegmentId;
  final SpotType type;

  /// 本人確認済みユーザーのみ入力可能（設計書「本人確認済みユーザーのみコメント投稿可」）。
  final String? comment;

  /// 「投稿への写真添付」機能（任意）。Cloud Storageへのアップロード完了後のダウンロードURL。
  /// アップロード自体（`SpotPhotoUploadService`）はこのモデルより先に完了している前提で、
  /// ここには文字列のURLのみを保持する（生の画像バイナリは扱わない）。
  final String? photoUrl;

  /// 「オフライン投稿キュー」機能（`SpotSubmissionQueue`）用のシリアライズ。
  Map<String, dynamic> toJson() => {
        'roadSegmentId': roadSegmentId,
        'type': type.name,
        'comment': comment,
        'photoUrl': photoUrl,
      };

  factory SpotSubmissionRequest.fromJson(Map<String, dynamic> json) => SpotSubmissionRequest(
        roadSegmentId: json['roadSegmentId'] as String,
        type: SpotType.values.byName(json['type'] as String),
        comment: json['comment'] as String?,
        photoUrl: json['photoUrl'] as String?,
      );
}

class SpotSubmissionResult {
  const SpotSubmissionResult({required this.reflectMode, required this.roadSegmentId});

  final ReflectMode reflectMode;
  final String roadSegmentId;
}
