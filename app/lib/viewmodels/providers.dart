import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../firebase/firebase_analytics_service.dart';
import '../firebase/firebase_announcement_service.dart';
import '../firebase/firebase_auth_service.dart';
import '../firebase/firebase_push_notification_service.dart';
import '../firebase/firebase_remote_config_service.dart';
import '../firebase/firebase_route_search_service.dart';
import '../firebase/firebase_spot_comment_service.dart';
import '../firebase/firebase_spot_dispute_service.dart';
import '../firebase/firebase_spot_list_service.dart';
import '../firebase/firebase_spot_reaction_service.dart';
import '../firebase/firebase_spot_retraction_service.dart';
import '../firebase/firebase_spot_submission_service.dart';
import '../firebase/firebase_spot_vote_service.dart';
import '../firebase/firebase_verification_service.dart';
import '../purchases/revenuecat_subscription_service.dart';
import '../services/analytics_service.dart';
import '../services/announcement_service.dart';
import '../services/auth_service.dart';
import '../services/favorite_route_service.dart';
import '../services/location_service.dart';
import '../services/notification_preference_storage.dart';
import '../services/onboarding_storage.dart';
import '../services/push_notification_service.dart';
import '../services/queueing_spot_submission_service.dart';
import '../services/remote_config_service.dart';
import '../services/road_network_repository.dart';
import '../services/route_search_service.dart';
import '../services/spot_comment_service.dart';
import '../services/spot_dispute_service.dart';
import '../services/spot_list_service.dart';
import '../services/spot_photo_upload_service.dart';
import '../services/spot_reaction_service.dart';
import '../services/spot_retraction_service.dart';
import '../services/spot_submission_queue.dart';
import '../services/spot_submission_service.dart';
import '../services/spot_vote_service.dart';
import '../services/subscription_service.dart';
import '../services/verification_service.dart';

/// Firebase初期化の成否。`main.dart`で`ProviderScope`の`overrides`に実際の値を渡す
/// （デフォルトのfalseはテスト実行時等、上書きされない場合のフォールバック）。
final firebaseAvailableProvider = Provider<bool>((ref) => false);

/// RevenueCat初期化の成否。Firebaseとは独立した課金基盤のため別フラグで管理する。
final purchasesAvailableProvider = Provider<bool>((ref) => false);

final locationServiceProvider = Provider<LocationService>((ref) => LocationService());

final roadNetworkRepositoryProvider = Provider<RoadNetworkRepository>((ref) => RoadNetworkRepository());

final authServiceProvider = Provider<AuthService>((ref) {
  return ref.watch(firebaseAvailableProvider)
      ? FirebaseAuthAdapter(FirebaseAuth.instance)
      : LocalAuthService();
});

final routeSearchServiceProvider = Provider<RouteSearchService>((ref) {
  return ref.watch(firebaseAvailableProvider)
      ? RemoteRouteSearchService(FirebaseFunctions.instance, ref.watch(authServiceProvider))
      : LocalRouteSearchService(ref.watch(roadNetworkRepositoryProvider));
});

final remoteConfigServiceProvider = Provider<RemoteConfigService>((ref) {
  return ref.watch(firebaseAvailableProvider)
      ? FirebaseRemoteConfigAdapter(FirebaseRemoteConfig.instance)
      : LocalRemoteConfigService();
});

final spotSubmissionQueueProvider = Provider<SpotSubmissionQueue>((ref) {
  return SharedPreferencesSpotSubmissionQueue();
});

final spotSubmissionServiceProvider = Provider<SpotSubmissionService>((ref) {
  final repository = ref.watch(roadNetworkRepositoryProvider);
  final remoteConfig = ref.watch(remoteConfigServiceProvider);

  if (ref.watch(firebaseAvailableProvider)) {
    final firestoreService = FirestoreSpotSubmissionService(
      FirebaseFirestore.instance,
      repository,
      ref.watch(authServiceProvider),
      moderationConfigProvider: () => remoteConfig.moderationConfig,
    );
    // 「オフライン投稿キュー」機能: Firestore接続時のみ、送信失敗を端末内キューへ
    // 保存して自動再送するデコレータを被せる（Local実装は元々完全オフライン動作のため不要）。
    return QueueingSpotSubmissionService(firestoreService, repository, ref.watch(spotSubmissionQueueProvider));
  }
  return LocalSpotSubmissionService(
    repository,
    moderationConfigProvider: () => remoteConfig.moderationConfig,
  );
});

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return ref.watch(firebaseAvailableProvider)
      ? FirebaseAnalyticsAdapter(FirebaseAnalytics.instance)
      : DebugAnalyticsService();
});

final onboardingStorageProvider = Provider<OnboardingStorage>((ref) => OnboardingStorage());

final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  return ref.watch(purchasesAvailableProvider)
      ? RevenueCatSubscriptionService()
      : LocalSubscriptionService();
});

final notificationPreferenceStorageProvider =
    Provider<NotificationPreferenceStorage>((ref) => NotificationPreferenceStorage());

final verificationServiceProvider = Provider<VerificationService>((ref) {
  return ref.watch(firebaseAvailableProvider)
      ? FirebaseVerificationService(FirebaseAuth.instance, FirebaseFirestore.instance, FirebaseFunctions.instance)
      : LocalVerificationService();
});

final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  return ref.watch(firebaseAvailableProvider)
      ? FirebasePushNotificationService(FirebaseMessaging.instance)
      : LocalPushNotificationService();
});

final announcementServiceProvider = Provider<AnnouncementService>((ref) {
  return ref.watch(firebaseAvailableProvider)
      ? FirestoreAnnouncementService(FirebaseFirestore.instance)
      : LocalAnnouncementService();
});

final spotCommentServiceProvider = Provider<SpotCommentService>((ref) {
  return ref.watch(firebaseAvailableProvider)
      ? FirestoreSpotCommentService(FirebaseFirestore.instance)
      : LocalSpotCommentService();
});

final spotVoteServiceProvider = Provider<SpotVoteService>((ref) {
  return ref.watch(firebaseAvailableProvider)
      ? FirestoreSpotVoteService(FirebaseFunctions.instance)
      : LocalSpotVoteService();
});

final spotRetractionServiceProvider = Provider<SpotRetractionService>((ref) {
  return ref.watch(firebaseAvailableProvider)
      ? FirestoreSpotRetractionService(FirebaseFunctions.instance)
      : LocalSpotRetractionService();
});

final spotDisputeServiceProvider = Provider<SpotDisputeService>((ref) {
  return ref.watch(firebaseAvailableProvider)
      ? FirestoreSpotDisputeService(FirebaseFunctions.instance)
      : LocalSpotDisputeService();
});

// 「投稿への写真添付」機能: 実際のアップロード実装（`image_picker`/`firebase_storage`が必要）は
// ローカル環境での追加待ち（`spot_photo_upload_service.dart`のコメント参照）。
// DIの配線自体は用意しておき、実装ができ次第この行だけ差し替えればよいようにしている。
final spotPhotoUploadServiceProvider = Provider<SpotPhotoUploadService>((ref) {
  return UnavailableSpotPhotoUploadService();
});

final spotReactionServiceProvider = Provider<SpotReactionService>((ref) {
  return ref.watch(firebaseAvailableProvider)
      ? FirestoreSpotReactionService(FirebaseFunctions.instance)
      : LocalSpotReactionService();
});

final spotListServiceProvider = Provider<SpotListService>((ref) {
  return ref.watch(firebaseAvailableProvider)
      ? FirestoreSpotListService(FirebaseFirestore.instance)
      : LocalSpotListService();
});

// 「お気に入りルート保存」機能: Firebase接続有無に関わらず端末内(SharedPreferences)に
// 保存するため、`firebaseAvailableProvider`による出し分けは不要。
final favoriteRouteServiceProvider = Provider<FavoriteRouteService>((ref) {
  return SharedPreferencesFavoriteRouteService();
});
