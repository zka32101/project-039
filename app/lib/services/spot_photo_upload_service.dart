/// 「投稿への写真添付」機能の呼び出し失敗時の例外。他のサービス例外と同じ設計。
class SpotPhotoUploadException implements Exception {
  SpotPhotoUploadException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// 写真アップロードサービスの抽象インターフェース。
/// アップロード先はCloud Storage（`storage.rules`の`spotPhotos/{submitterId}/...`）を想定し、
/// 成功時はダウンロードURLを返す（`SpotSubmissionService.submitSpot`の`photoUrl`にそのまま渡す）。
///
/// 【現状】バックエンド（`storage.rules`）とデータモデル（`SpotSubmissionRequest.photoUrl`）は
/// 実装済みだが、実際のカメラ撮影・画像選択・アップロードを行うクライアント側実装
/// （`image_picker`・`firebase_storage`パッケージの追加が必要、このセッションでは
/// `flutter pub get`によるロックファイル更新を検証できないため見送り）は未実装。
/// ローカル環境で以下を実施すること:
///   1. `pubspec.yaml`に`image_picker`・`firebase_storage`を追加し`flutter pub get`
///   2. 本インターフェースを実装する`FirebaseSpotPhotoUploadService`を追加
///      （`filePath`から`Uint8List`/`File`を読み、`spotPhotos/{uid}/{uuid}.jpg`へアップロード）
///   3. `paint_submission_view.dart`に撮影・選択UIを追加し、アップロード成功後の
///      URLを`submitSpot(..., photoUrl: url)`に渡す
abstract class SpotPhotoUploadService {
  /// [filePath]（端末内の画像ファイルパス）をアップロードし、ダウンロードURLを返す。
  Future<String> upload(String filePath);
}

/// Firebase未接続環境向け、およびクライアント側実装が未完了の間のフォールバック実装。
/// 機能自体を無効化する（`LocalSpotVoteService`と同じ設計）。
class UnavailableSpotPhotoUploadService implements SpotPhotoUploadService {
  @override
  Future<String> upload(String filePath) async {
    throw SpotPhotoUploadException('この環境では写真添付機能を利用できません');
  }
}
