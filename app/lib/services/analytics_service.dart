/// 計測設計（Step4.5）のKPIイベント5個を送信する薄いラッパー。
/// Firebase未接続の環境でも動作するよう、実送信部分は差し替え可能なインターフェースにする。
/// 本セッションではFirebase SDK未接続のため、デバッグログ出力にフォールバックする実装のみ用意。
abstract class AnalyticsService {
  void logAppOpen();
  void logRouteSearched();
  void logSpotSubmitted(String spotType);
  void logCommentAdded();
  void logPaywallConverted();
}

class DebugAnalyticsService implements AnalyticsService {
  final List<String> _log = [];
  List<String> get log => List.unmodifiable(_log);

  void _record(String event, [Map<String, Object?>? params]) {
    _log.add(params == null ? event : '$event $params');
  }

  @override
  void logAppOpen() => _record('app_open');

  @override
  void logRouteSearched() => _record('route_searched'); // aha_moment_reached相当

  @override
  void logSpotSubmitted(String spotType) => _record('spot_submitted', {'type': spotType});

  @override
  void logCommentAdded() => _record('comment_added'); // 本人確認済みのみ発生させる

  @override
  void logPaywallConverted() => _record('paywall_converted');
}
