/// 設計書 `User { uid, isVerified, verificationMethod, subscriptionStatus, createdAt }` に対応。
class UserProfile {
  const UserProfile({
    required this.uid,
    required this.isVerified,
    this.verificationMethod,
  });

  final String uid;
  final bool isVerified;
  final String? verificationMethod; // 例: 'phone'

  static const unverified = UserProfile(uid: '', isVerified: false);
}
