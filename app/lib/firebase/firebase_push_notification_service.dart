import 'package:firebase_messaging/firebase_messaging.dart';
import '../models/app_notification.dart';
import '../services/push_notification_service.dart';

const announcementsTopic = 'announcements';

/// Firebase Cloud Messaging（トピック購読方式）ラッパー。
/// `functions/index.js` の `onAnnouncementCreated` が `announcements` トピック宛に
/// 送信したお知らせを受信する。バックグラウンド/終了時の通知表示はFCMの標準動作
/// （`notification`ペイロード）に任せ、アプリ側での追加実装は不要。
/// フォアグラウンド受信時は[foregroundMessages]経由でUI層（`app.dart`）がバナー表示する。
class FirebasePushNotificationService implements PushNotificationService {
  FirebasePushNotificationService(this._messaging);

  final FirebaseMessaging _messaging;

  @override
  Future<void> initialize({required bool enabled}) async {
    // iOS/Web等、許可プロンプトが必要なプラットフォーム向け。
    // 拒否された場合でもアプリはクラッシュせず、単に配信されないだけとする。
    await _messaging.requestPermission(alert: true, badge: true, sound: true);
    await setEnabled(enabled);
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    if (enabled) {
      await _messaging.subscribeToTopic(announcementsTopic);
    } else {
      await _messaging.unsubscribeFromTopic(announcementsTopic);
    }
  }

  @override
  Stream<AppNotification> get foregroundMessages {
    return FirebaseMessaging.onMessage.map(mapRemoteMessageToAppNotification);
  }
}

/// `RemoteMessage`→`AppNotification`の変換。純粋関数として切り出しunit testしやすくしている。
AppNotification mapRemoteMessageToAppNotification(RemoteMessage message) {
  return AppNotification(
    title: message.notification?.title ?? 'あんしんみちからのお知らせ',
    body: message.notification?.body ?? '',
  );
}
