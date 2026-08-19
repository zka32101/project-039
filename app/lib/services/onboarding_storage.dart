import 'package:shared_preferences/shared_preferences.dart';

/// オンボーディング完走フラグの永続化。次回起動時にオンボーディングをスキップし、
/// 「起動→位置情報許可→ホーム」の最短動線を保つ。
class OnboardingStorage {
  static const _key = 'onboarding_completed';

  Future<bool> isCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  Future<void> markCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }
}
