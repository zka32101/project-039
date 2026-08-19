import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

/// Firebase Auth（匿名認証）ラッパー。
/// 設計書「Auth（匿名認証→本人確認フロー）」の前段部分に対応。
/// 本人確認フロー自体（電話番号確認等）は次スプリント。
class FirebaseAuthAdapter implements AuthService {
  FirebaseAuthAdapter(this._auth);

  final FirebaseAuth _auth;

  @override
  String? get currentUserId => _auth.currentUser?.uid;

  @override
  Future<String> ensureSignedIn() async {
    final existing = _auth.currentUser;
    if (existing != null) return existing.uid;

    final credential = await _auth.signInAnonymously();
    final uid = credential.user?.uid;
    if (uid == null) {
      throw StateError('匿名サインインに失敗しました（uidを取得できません）');
    }
    return uid;
  }
}
