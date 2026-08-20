import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';
import '../services/verification_service.dart';

/// Firebase Auth の電話番号認証（SMS）を使った本人確認実装。
/// 匿名認証済みユーザーへ電話番号クレデンシャルをリンクし（同一uidを維持したまま昇格）、
/// Cloud Functions（`syncVerificationStatus`）経由でFirestoreの`users/{uid}`へ
/// 確認結果を反映する。**クライアントはisVerifiedを直接書き込めない**
/// （`firestore.rules`参照。ID Tokenのphone_numberクレームをサーバー側で検証してから書き込む）。
/// `isVerified`はFirestoreに加えAuth Custom Claimとしても設定され、`firestore.rules`の
/// `isVerifiedUser()`はCustom Claimのみで判定する（Firestore `get()`を都度発生させない）。
/// Custom Claimはトークン発行時点のスナップショットのため、確認直後は
/// `getIdToken(true)`で強制リフレッシュしてから利用する必要がある（[_linkAndSync]参照）。
class FirebaseVerificationService implements VerificationService {
  FirebaseVerificationService(this._auth, this._firestore, this._functions);

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  @override
  Future<UserProfile> getProfile() async {
    final user = _auth.currentUser;
    if (user == null) return UserProfile.unverified;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) return UserProfile(uid: user.uid, isVerified: false);

    final data = doc.data()!;
    return UserProfile(
      uid: user.uid,
      isVerified: data['isVerified'] as bool? ?? false,
      verificationMethod: data['verificationMethod'] as String?,
    );
  }

  @override
  Future<String> sendVerificationCode(String phoneNumber) async {
    final completer = Completer<String>();

    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Android等での自動検証（SMS自動読み取り）。手動フローと重複しないよう
        // ここでリンクまで完了させ、以降のconfirmVerificationCode呼び出しは早期returnで無害化する。
        await _linkAndSync(credential);
      },
      verificationFailed: (FirebaseAuthException e) {
        if (!completer.isCompleted) {
          completer.completeError(VerificationException(_mapAuthError(e)));
        }
      },
      codeSent: (String verificationId, int? resendToken) {
        if (!completer.isCompleted) completer.complete(verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        if (!completer.isCompleted) completer.complete(verificationId);
      },
    );

    return completer.future;
  }

  @override
  Future<UserProfile> confirmVerificationCode({required String verificationId, required String smsCode}) async {
    final credential = PhoneAuthProvider.credential(verificationId: verificationId, smsCode: smsCode);
    return _linkAndSync(credential);
  }

  Future<UserProfile> _linkAndSync(PhoneAuthCredential credential) async {
    final user = _auth.currentUser;
    if (user == null) throw VerificationException('サインインしていません');

    try {
      if (!user.providerData.any((p) => p.providerId == PhoneAuthProvider.PROVIDER_ID)) {
        await user.linkWithCredential(credential);
      }
    } on FirebaseAuthException catch (e) {
      throw VerificationException(_mapAuthError(e));
    }

    // ID Tokenを強制リフレッシュし、phone_numberクレームを反映させたうえでCloud Functionsへ送る
    await user.getIdToken(true);

    final callable = _functions.httpsCallable('syncVerificationStatus');
    await callable.call();

    // syncVerificationStatusが設定したisVerified Custom Claimは、トークン発行時点の
    // スナップショットにしか反映されない。ここで強制リフレッシュしないと、確認直後に
    // isVerifiedUser()判定を要するspotComments作成がfirestore.rulesで拒否されてしまう。
    await user.getIdToken(true);

    return getProfile();
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-verification-code':
        return '確認コードが正しくありません';
      case 'credential-already-in-use':
        return 'この電話番号は既に別のアカウントで使用されています';
      case 'too-many-requests':
        return 'リクエストが多すぎます。しばらくしてから再度お試しください';
      default:
        return '本人確認に失敗しました（${e.code}）';
    }
  }
}
