import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/analytics_service.dart';
import '../services/location_service.dart';
import '../services/onboarding_storage.dart';
import '../services/road_network_repository.dart';
import '../services/route_search_service.dart';
import '../services/spot_submission_service.dart';

final locationServiceProvider = Provider<LocationService>((ref) => LocationService());

final roadNetworkRepositoryProvider = Provider<RoadNetworkRepository>((ref) => RoadNetworkRepository());

final routeSearchServiceProvider = Provider<RouteSearchService>(
  (ref) => LocalRouteSearchService(ref.watch(roadNetworkRepositoryProvider)),
);

final spotSubmissionServiceProvider = Provider<SpotSubmissionService>(
  (ref) => LocalSpotSubmissionService(ref.watch(roadNetworkRepositoryProvider)),
);

final analyticsServiceProvider = Provider<AnalyticsService>((ref) => DebugAnalyticsService());

final onboardingStorageProvider = Provider<OnboardingStorage>((ref) => OnboardingStorage());
