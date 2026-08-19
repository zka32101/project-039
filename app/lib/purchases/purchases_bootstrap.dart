import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// RevenueCat SDKの初期化。
///
/// 【重要な注記】このセッションの実行環境にはRevenueCatダッシュボード・実プロジェクトへの
/// ネットワークアクセスが無いため、実接続確認は行えていない。ローカル環境で以下を実施すること:
///   1. RevenueCatダッシュボードでプロジェクトを作成し、App Store Connect/Google Play Consoleと連携
///   2. 「premium」エンタイトルメントと、それに紐づくProductを設定
///      （`revenuecat_subscription_service.dart` の `_entitlementId` 参照）
///   3. iOS/AndroidそれぞれのPublic API Keyを取得し、下記の`_iosApiKey`/`_androidApiKey`を
///      環境変数や`--dart-define`経由の値に置き換える（**プレースホルダーのままコミットしないこと**）
///
/// 未設定・初期化失敗時は`available = false`を返し、`LocalSubscriptionService`
/// （デモ用フラグでの疑似購入）へフォールバックする。
class PurchasesBootstrapResult {
  const PurchasesBootstrapResult({required this.available, this.error});
  final bool available;
  final Object? error;
}

// TODO: 本番投入前に `--dart-define=REVENUECAT_IOS_API_KEY=...` 等で注入する値に置き換える
const _iosApiKey = String.fromEnvironment('REVENUECAT_IOS_API_KEY');
const _androidApiKey = String.fromEnvironment('REVENUECAT_ANDROID_API_KEY');

Future<PurchasesBootstrapResult> bootstrapPurchases() async {
  final apiKey = defaultTargetPlatform == TargetPlatform.iOS ? _iosApiKey : _androidApiKey;
  if (apiKey.isEmpty) {
    debugPrint('[PurchasesBootstrap] RevenueCat APIキー未設定のためローカル実装にフォールバックします');
    return const PurchasesBootstrapResult(available: false);
  }

  try {
    await Purchases.setLogLevel(LogLevel.warn);
    await Purchases.configure(PurchasesConfiguration(apiKey));
    return const PurchasesBootstrapResult(available: true);
  } catch (error) {
    debugPrint('[PurchasesBootstrap] RevenueCat初期化に失敗したためローカル実装にフォールバックします: $error');
    return PurchasesBootstrapResult(available: false, error: error);
  }
}
