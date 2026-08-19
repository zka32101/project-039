import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/analytics_service.dart';
import '../services/location_service.dart';
import '../services/onboarding_storage.dart';
import '../services/route_search_service.dart';

final locationServiceProvider = Provider<LocationService>((ref) => LocationService());

final routeSearchServiceProvider =
    Provider<RouteSearchService>((ref) => LocalRouteSearchService());

final analyticsServiceProvider = Provider<AnalyticsService>((ref) => DebugAnalyticsService());

final onboardingStorageProvider = Provider<OnboardingStorage>((ref) => OnboardingStorage());
