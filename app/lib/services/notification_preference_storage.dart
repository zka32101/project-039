import 'package:shared_preferences/shared_preferences.dart';

/// 設定画面「通知」トグルの永続化。
/// 【スコープ外】実際のプッシュ通知配信（FCM等）は未実装。ここでは端末内の
/// ユーザー意思表示のみを保存し、将来の通知基盤実装時にこの値を参照する想定。
class NotificationPreferenceStorage {
  static const _key = 'notification_enabled';

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? true; // 既定はON（設計書の通知プレプロンプトを想定）
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, enabled);
  }
}
