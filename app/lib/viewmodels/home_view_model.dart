import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/route_result.dart';
import 'providers.dart';

sealed class HomeState {
  const HomeState();
}

class HomeLoading extends HomeState {
  const HomeLoading();
}

class HomeLocationUnavailable extends HomeState {
  const HomeLocationUnavailable();
}

class HomeReady extends HomeState {
  const HomeReady({
    required this.route,
    required this.currentLat,
    required this.currentLon,
    required this.isOptimizedRouteEnabled,
  });
  final RouteResult route;
  final double currentLat;
  final double currentLon;

  /// 「詳細ルート最適化」（プレミアム機能）が有効かどうか。
  final bool isOptimizedRouteEnabled;
}

class HomeError extends HomeState {
  const HomeError(this.message);
  final String message;
}

const _defaultShadeWeight = 0.6;
const _optimizedShadeWeight = 0.85;

/// ホーム画面のViewModel。Aha Momentの核である
/// 「現在地周辺の安心ルート即表示」を担当する。
class HomeViewModel extends StateNotifier<HomeState> {
  HomeViewModel(this._ref) : super(const HomeLoading()) {
    _load();
  }

  final Ref _ref;
  bool _optimizedRouteEnabled = false;
  ({double lat, double lon})? _lastPosition;

  Future<void> _load() async {
    state = const HomeLoading();

    final locationService = _ref.read(locationServiceProvider);
    final routeService = _ref.read(routeSearchServiceProvider);
    final analytics = _ref.read(analyticsServiceProvider);

    final permission = await locationService.requestPermission();
    if (permission != LocationPermissionState.granted) {
      state = const HomeLocationUnavailable();
      return;
    }

    final position = await locationService.getCurrentLocation();
    if (position == null) {
      state = const HomeLocationUnavailable();
      return;
    }
    _lastPosition = position;

    try {
      final route = await routeService.searchNearbyComfortRoute(
        currentLat: position.lat,
        currentLon: position.lon,
        shadeWeight: _optimizedRouteEnabled ? _optimizedShadeWeight : _defaultShadeWeight,
      );
      if (route == null) {
        state = const HomeError('付近に安心ルートを見つけられませんでした');
        return;
      }
      analytics.logRouteSearched();
      state = HomeReady(
        route: route,
        currentLat: position.lat,
        currentLon: position.lon,
        isOptimizedRouteEnabled: _optimizedRouteEnabled,
      );
    } catch (e) {
      state = HomeError('ルート検索に失敗しました: $e');
    }
  }

  Future<void> retry() => _load();

  /// 「詳細ルート最適化」トグル。プレミアム未契約の場合は何もせず`false`を返す
  /// （呼び出し元＝HomeViewでペイウォールへ誘導する）。
  Future<bool> setOptimizedRouteEnabled(bool enabled) async {
    if (enabled) {
      final status = await _ref.read(subscriptionServiceProvider).getStatus();
      if (!status.isPremium) return false;
    }
    _optimizedRouteEnabled = enabled;
    if (_lastPosition != null) {
      await _load();
    }
    return true;
  }
}

final homeViewModelProvider = StateNotifierProvider.autoDispose<HomeViewModel, HomeState>(
  (ref) => HomeViewModel(ref),
);
