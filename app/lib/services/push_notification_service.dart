import '../models/app_notification.dart';

/// プッシュ通知（設計書Step7「お知らせ機能」の配信経路）の抽象インターフェース。
/// 実際の配信はトピック購読方式（'announcements'）で行う。個々のユーザーの
/// デバイストークンをサーバー側で管理する必要が無く、設定画面のON/OFFが
/// そのまま購読/解除に対応する単純な構成にしている。
abstract class PushNotificationService {
  /// アプリ起動時の初期化。[enabled]は`NotificationPreferenceStorage`に保存された
  /// 現在の設定値（既定はON）。
  Future<void> initialize({required bool enabled});

  /// 設定画面の「お知らせを受け取る」トグルに連動する。
  Future<void> setEnabled(bool enabled);

  /// アプリがフォアグラウンド表示中に受信した通知。
  /// バックグラウンド/終了時の通知表示はOS標準のFCM動作に任せているため、
  /// このストリームはフォアグラウンド時のアプリ内バナー表示にのみ使う。
  Stream<AppNotification> get foregroundMessages;
}

/// Firebase未接続環境向けのフォールバック実装。実際の購読処理は行わない。
class LocalPushNotificationService implements PushNotificationService {
  @override
  Future<void> initialize({required bool enabled}) async {}

  @override
  Future<void> setEnabled(bool enabled) async {}

  @override
  Stream<AppNotification> get foregroundMessages => const Stream.empty();
}
