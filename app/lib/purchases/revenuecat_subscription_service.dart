import 'package:purchases_flutter/purchases_flutter.dart';
import '../models/subscription_state.dart';
import '../services/subscription_service.dart';

const _entitlementId = 'premium';

/// RevenueCatラッパー。「詳細ルート最適化」「オフライン地図利用」のペイウォールを解放する
/// premiumエンタイトルメントの購入・復元・状態確認を行う。
class RevenueCatSubscriptionService implements SubscriptionService {
  @override
  Future<SubscriptionState> getStatus() async {
    final info = await Purchases.getCustomerInfo();
    return _fromCustomerInfo(info);
  }

  @override
  Future<SubscriptionState> purchasePremium() async {
    final offerings = await Purchases.getOfferings();
    final package = offerings.current?.availablePackages.firstOrNull;
    if (package == null) {
      throw PurchaseException('現在購入可能なプランがありません。しばらくしてから再度お試しください');
    }
    try {
      // 【要ローカル検証】purchases_flutterの`purchasePackage`戻り値の型はSDKバージョンによって
      // 異なる（v6以降は`CustomerInfo`を直接返すが、`{storeTransaction, customerInfo}`を返す
      // バージョンもある）。pubspec.yamlで固定したバージョンのAPIと一致するか、
      // `flutter pub get`後に必ず確認すること。
      final customerInfo = await Purchases.purchasePackage(package);
      return _fromCustomerInfo(customerInfo);
    } catch (e) {
      // PurchasesFlutterはユーザーによるキャンセル等をPlatformExceptionで通知する。
      // 詳細なエラーコード分岐（キャンセル/ネットワーク/決済拒否）は実接続確認後に詰める。
      throw PurchaseException('購入に失敗しました: $e');
    }
  }

  @override
  Future<SubscriptionState> restorePurchases() async {
    final info = await Purchases.restorePurchases();
    return _fromCustomerInfo(info);
  }

  SubscriptionState _fromCustomerInfo(CustomerInfo info) {
    final entitlement = info.entitlements.active[_entitlementId];
    if (entitlement == null) return SubscriptionState.free;
    final expiresAtStr = entitlement.expirationDate;
    return SubscriptionState(
      tier: SubscriptionTier.premium,
      expiresAt: expiresAtStr != null ? DateTime.tryParse(expiresAtStr) : null,
    );
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
