import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../viewmodels/providers.dart';
import '../../widgets/primary_button.dart';

class _OnboardingPage {
  const _OnboardingPage({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;
}

const _pages = [
  _OnboardingPage(
    icon: Icons.park_outlined,
    title: '影・雨よけ・明るさを、みんなで塗って共有',
    body: '木陰やアーケード、夜道の明るさを地図に「塗る」だけで、街のみんなと共有できます。',
  ),
  _OnboardingPage(
    icon: Icons.route_outlined,
    title: '安心して歩ける道を最短で見つける',
    body: '建物の影の自動計算＋みんなの投稿を統合して、快適なルートをすぐに提案します。',
  ),
  _OnboardingPage(
    icon: Icons.favorite_outline,
    title: 'あなたの一歩が、次の誰かの安心になる',
    body: 'あなたが塗った道は、次にそこを歩く誰かの安心につながります。',
  ),
];

/// 設計書Step2の「オンボーディング(3枚)」画面。
class OnboardingView extends ConsumerStatefulWidget {
  const OnboardingView({super.key});

  @override
  ConsumerState<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends ConsumerState<OnboardingView> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onNext() async {
    if (_index < _pages.length - 1) {
      await _controller.nextPage(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
      return;
    }
    await ref.read(onboardingStorageProvider).markCompleted();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/home');
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _index == _pages.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: () async {
                  await ref.read(onboardingStorageProvider).markCompleted();
                  if (!mounted) return;
                  Navigator.of(context).pushReplacementNamed('/home');
                },
                child: const Text('スキップ'),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final page = _pages[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(page.icon, size: 96, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(height: 32),
                        Text(
                          page.title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          page.body,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == _index ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _index
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.primary.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: PrimaryButton(
                label: isLast ? 'はじめる' : '次へ',
                onPressed: _onNext,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
