/// フォアグラウンド受信したプッシュ通知（お知らせ）の最小表現。
/// `firebase_messaging`の`RemoteMessage`型をUI層・インターフェースに漏らさないための
/// アプリ固有モデル。
class AppNotification {
  const AppNotification({required this.title, required this.body});

  final String title;
  final String body;
}
