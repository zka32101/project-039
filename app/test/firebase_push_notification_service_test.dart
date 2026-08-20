import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:anshinmichi/firebase/firebase_push_notification_service.dart';

void main() {
  test('mapRemoteMessageToAppNotification: notificationのtitle/bodyをそのまま使う', () {
    final message = RemoteMessage(
      notification: const RemoteNotification(title: '新機能のお知らせ', body: '目的地入力ができるようになりました'),
    );
    final result = mapRemoteMessageToAppNotification(message);
    expect(result.title, '新機能のお知らせ');
    expect(result.body, '目的地入力ができるようになりました');
  });

  test('mapRemoteMessageToAppNotification: notificationが無い場合はデフォルト値を使う', () {
    final message = RemoteMessage();
    final result = mapRemoteMessageToAppNotification(message);
    expect(result.title, 'あんしんみちからのお知らせ');
    expect(result.body, '');
  });
}
