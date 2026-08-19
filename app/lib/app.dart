import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/app_version.dart';
import 'services/onboarding_storage.dart';
import 'theme/app_theme.dart';
import 'viewmodels/providers.dart';
import 'views/home/home_view.dart';
import 'views/onboarding/onboarding_view.dart';
import 'views/update_required/update_required_view.dart';

class AnshinmichiApp extends ConsumerWidget {
  const AnshinmichiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
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
