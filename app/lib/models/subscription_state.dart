enum SubscriptionTier { free, premium }

/// サブスクリプション状態。設計書のペイウォール（詳細ルート最適化・オフライン地図利用時にトリガー）
/// のゲート判定に使う。
class SubscriptionState {
  const SubscriptionState({required this.tier, this.expiresAt});

  final SubscriptionTier tier;
  final DateTime? expiresAt;

  bool get isPremium => tier == SubscriptionTier.premium;

  static const free = SubscriptionState(tier: SubscriptionTier.free);
}
