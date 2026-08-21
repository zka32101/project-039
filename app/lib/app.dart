import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'models/app_notification.dart';
import 'services/app_version.dart';
import 'services/onboarding_storage.dart';
import 'theme/app_theme.dart';
import 'viewmodels/providers.dart';
import 'views/announcements/announcements_list_view.dart';
import 'views/home/home_view.dart';
import 'views/onboarding/onboarding_view.dart';
import 'views/update_required/update_required_view.dart';
import 'widgets/foreground_notification_banner.dart';

class AnshinmichiApp extends ConsumerStatefulWidget {
  const AnshinmichiApp({super.key});

  @override
  ConsumerState<AnshinmichiApp> createState() => _AnshinmichiAppState();
}

class _AnshinmichiAppState extends ConsumerState<AnshinmichiApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<AppNotification>? _foregroundMessageSubscription;
  // 複数の通知がほぼ同時に届いても重ねて表示せず、1件ずつ直列に表示するキュー
  // （`widgets/foreground_notification_banner.dart`参照）。Appの生存期間中は1つのインスタンスを使い回す。
  final _bannerQueue = ForegroundBannerQueue();

  @override
  void initState() {
    super.initState();
    // フォアグラウンド受信時のみアプリ内バナーで通知する
    // （バックグラウンド/終了時はFCM標準の通知表示に任せる）。
    _foregroundMessageSubscription =
        ref.read(pushNotificationServiceProvider).foregroundMessages.listen(_showForegroundBanner);
  }

  @override
  void dispose() {
    _foregroundMessageSubscription?.cancel();
    super.dispose();
  }

  void _showForegroundBanner(AppNotification notification) {
    // 専用オーバーレイでの表示に置き換え済み（旧SnackBar版からの変更点は
    // widgets/foreground_notification_banner.dart 冒頭のコメント参照）。
    final overlay = _navigatorKey.currentState?.overlay;
    if (overlay == null) return;
    _bannerQueue.enqueue(
      overlay,
      notification,
      onTap: () => _navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => const AnnouncementsListView()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'あんしんみち',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      initialRoute: '/',
      routes: {
        '/': (_) => const _StartupGate(),
        '/update-required': (_) => const UpdateRequiredView(),
        '/onboarding': (_) => const OnboardingView(),
        '/home': (_) => const HomeView(),
      },
    );
  }
}

/// 起動直後にオンボーディング完走済みかを判定し、
/// 「起動→(オンボ)→位置情報許可→ホーム」の動線に振り分けるゲート画面。
class _StartupGate extends ConsumerStatefulWidget {
  const _StartupGate();

  @override
  ConsumerState<_StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends ConsumerState<_StartupGate> {
  @override
  void initState() {
    super.initState();
    ref.read(analyticsServiceProvider).logAppOpen();
    _decideRoute();
  }

  Future<void> _decideRoute() async {
    final remoteConfig = ref.read(remoteConfigServiceProvider);
    if (isUpdateRequired(current: currentAppVersion, minSupported: remoteConfig.minSupportedVersion)) {
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/update-required');
      return;
    }

    final OnboardingStorage storage = ref.read(onboardingStorageProvider);
    final completed = await storage.isCompleted();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(completed ? '/home' : '/onboarding');
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
