import 'package:shared_preferences/shared_preferences.dart';
import '../models/subscription_state.dart';

class PurchaseException implements Exception {
  PurchaseException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// サブスクリプション（設定画面「サブスク管理」・ペイウォール）の抽象インターフェース。
/// 設計書の課金基盤（RevenueCat）に対応。
abstract class SubscriptionService {
  Future<SubscriptionState> getStatus();
  Future<SubscriptionState> purchasePremium();
  Future<SubscriptionState> restorePurchases();
}

/// RevenueCat未接続環境向けのフォールバック実装。
/// 実際の課金は行わず、端末内のフラグで「購入済み」を模擬する（デモ用）。
class LocalSubscriptionService implements SubscriptionService {
  static const _key = 'local_demo_premium';

  @override
  Future<SubscriptionState> getStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final isPremium = prefs.getBool(_key) ?? false;
    return isPremium ? const SubscriptionState(tier: SubscriptionTier.premium) : SubscriptionState.free;
  }

  @override
  Future<SubscriptionState> purchasePremium() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
    return const SubscriptionState(tier: SubscriptionTier.premium);
  }

  @override
  Future<SubscriptionState> restorePurchases() => getStatus();
}
