import 'package:shared_preferences/shared_preferences.dart';

/// 認証サービスの抽象インターフェース。
/// 設計書の「本人確認済みユーザーのみコメント投稿可」を実現する前提として、
/// まず匿名認証でユーザーを識別できるようにする（実際の本人確認フローは次スプリント）。
abstract class AuthService {
  /// 未サインインなら匿名サインインし、ユーザーIDを返す。
  Future<String> ensureSignedIn();

  String? get currentUserId;
}

/// Firebase未接続環境向けのフォールバック実装。
/// 端末内にランダムな匿名IDを生成・永続化するだけで、サーバーとは同期しない。
class LocalAuthService implements AuthService {
  static const _key = 'local_anonymous_uid';
  String? _cachedUid;

  @override
  String? get currentUserId => _cachedUid;

  @override
  Future<String> ensureSignedIn() async {
    if (_cachedUid != null) return _cachedUid!;

    final prefs = await SharedPreferences.getInstance();
    var uid = prefs.getString(_key);
    if (uid == null) {
      uid = 'local_${DateTime.now().microsecondsSinceEpoch}_${_randomSuffix()}';
      await prefs.setString(_key, uid);
    }
    _cachedUid = uid;
    return uid;
  }

  String _randomSuffix() {
    // Firebase未接続時のダミーID生成のみに使う（セキュリティ用途ではないため簡易実装で十分）。
    final micros = DateTime.now().microsecondsSinceEpoch;
    return (micros % 1000000).toString().padLeft(6, '0');
  }
}
