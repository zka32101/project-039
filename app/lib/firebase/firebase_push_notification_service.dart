import 'package:firebase_messaging/firebase_messaging.dart';
import '../services/push_notification_service.dart';

const announcementsTopic = 'announcements';

/// Firebase Cloud Messaging（トピック購読方式）ラッパー。
/// `functions/index.js` の `onAnnouncementCreated` が `announcements` トピック宛に
/// 送信したお知らせを受信する。バックグラウンド/終了時の通知表示はFCMの標準動作
/// （`notification`ペイロード）に任せ、アプリ側での追加実装は不要。
///
/// 【スコープ外】フォアグラウンド受信時のアプリ内バナー表示（flutter_local_notifications等）
/// は未実装。現状はログ出力のみで、ユーザーはアプリを開いたタイミングで
/// `AnnouncementsListView`（お知らせ一覧）を確認する運用を想定。
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
}
