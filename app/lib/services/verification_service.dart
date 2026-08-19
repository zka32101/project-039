import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';

class VerificationException implements Exception {
  VerificationException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// 本人確認（設計書「本人確認済みユーザーのみコメント投稿可」のゲート）の抽象インターフェース。
/// SMS認証コードの送信→確認という2段階のフローを想定する。
abstract class VerificationService {
  Future<UserProfile> getProfile();

  /// SMS確認コードを送信する。成功時は`verificationId`を返す（`confirmCode`で使用）。
  Future<String> sendVerificationCode(String phoneNumber);

  /// 確認コードを検証し、本人確認を完了する。
  Future<UserProfile> confirmVerificationCode({required String verificationId, required String smsCode});
}

/// Firebase未接続環境向けのフォールバック実装。
/// 実際のSMS送信は行わず、固定のデモコード（123456）で確認完了とする。
class LocalVerificationService implements VerificationService {
  static const _key = 'local_demo_verified';
  static const demoCode = '123456';

  @override
  Future<UserProfile> getProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final isVerified = prefs.getBool(_key) ?? false;
    return UserProfile(uid: 'local', isVerified: isVerified, verificationMethod: isVerified ? 'phone(demo)' : null);
  }

  @override
  Future<String> sendVerificationCode(String phoneNumber) async {
    // 実際のSMS送信は行わない（RevenueCat/Firebase未接続時のデモ実装）
    return 'demo-verification-id';
  }

  @override
  Future<UserProfile> confirmVerificationCode({required String verificationId, required String smsCode}) async {
    if (smsCode != demoCode) {
      throw VerificationException('確認コードが正しくありません（デモ環境ではコード $demoCode を入力してください）');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
    return const UserProfile(uid: 'local', isVerified: true, verificationMethod: 'phone(demo)');
  }
}
