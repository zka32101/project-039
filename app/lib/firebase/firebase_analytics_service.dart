import 'package:firebase_analytics/firebase_analytics.dart';
import '../services/analytics_service.dart';

/// 計測3点セットの一つ（Analytics）。Firebase初期化成功時にこちらへ差し替える。
/// 未接続環境では`DebugAnalyticsService`にフォールバックする（`viewmodels/providers.dart`参照）。
class FirebaseAnalyticsAdapter implements AnalyticsService {
  FirebaseAnalyticsAdapter(this._analytics);

  final FirebaseAnalytics _analytics;

  @override
  void logAppOpen() => _analytics.logAppOpen();

  @override
  void logRouteSearched() => _analytics.logEvent(name: 'route_searched'); // aha_moment_reached相当

  @override
  void logSpotSubmitted(String spotType) =>
      _analytics.logEvent(name: 'spot_submitted', parameters: {'type': spotType});

  @override
  void logCommentAdded() => _analytics.logEvent(name: 'comment_added'); // 本人確認済みのみ発生させる

  @override
  void logPaywallConverted() => _analytics.logEvent(name: 'paywall_converted');
}
