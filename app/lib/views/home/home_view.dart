import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/route_result.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/home_view_model.dart';
import '../../widgets/primary_button.dart';
import '../paint/paint_submission_view.dart';
import '../paywall/paywall_view.dart';
import '../settings/settings_view.dart';
import 'widgets/schematic_map_view.dart';

/// Aha Momentの中心画面。「現在地周辺の安心ルート即表示」。
class HomeView extends ConsumerWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(homeViewModelProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('あんしんみち'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: '設定',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsView()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PaintSubmissionView()),
          );
          // 投稿によって安心スコアが変わっている可能性があるため、ホームのルートを再計算する
          ref.read(homeViewModelProvider.notifier).retry();
        },
        icon: const Icon(Icons.brush_outlined),
        label: const Text('塗って投稿'),
      ),
      body: SafeArea(
        child: switch (state) {
          HomeLoading() => const _LoadingSkeleton(),
          HomeLocationUnavailable() => _PermissionDeniedView(
              onRetry: () => ref.read(homeViewModelProvider.notifier).retry(),
            ),
          HomeError(:final message) => _ErrorView(
              message: message,
              onRetry: () => ref.read(homeViewModelProvider.notifier).retry(),
            ),
          HomeReady(:final route, :final currentLat, :final currentLon, :final isOptimizedRouteEnabled) =>
            _ReadyView(
              route: route,
              currentLat: currentLat,
              currentLon: currentLon,
              isOptimizedRouteEnabled: isOptimizedRouteEnabled,
            ),
        },
      ),
    );
  }
}

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 22, width: 200, color: base),
          const SizedBox(height: 16),
          AspectRatio(
            aspectRatio: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(20)),
            ),
          ),
          const SizedBox(height: 24),
          const Center(child: CircularProgressIndicator()),
          const SizedBox(height: 12),
          const Center(child: Text('現在地周辺の安心ルートを探しています…')),
        ],
      ),
    );
  }
}

class _PermissionDeniedView extends StatelessWidget {
  const _PermissionDeniedView({required this.onRetry});
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_off_outlined, size: 64, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            const Text(
              '位置情報の利用が許可されていません',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              '現在地周辺の安心ルートを表示するには、設定から位置情報を許可してください。'
              '（バックグラウンドでの位置取得は行いません）',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            PrimaryButton(label: 'もう一度試す', onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 56, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            PrimaryButton(label: 'もう一度試す', onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}

class _ReadyView extends ConsumerWidget {
  const _ReadyView({
    required this.route,
    required this.currentLat,
    required this.currentLon,
    required this.isOptimizedRouteEnabled,
  });

  final RouteResult route;
  final double currentLat;
  final double currentLon;
  final bool isOptimizedRouteEnabled;

  Future<void> _handleOptimizedToggle(BuildContext context, WidgetRef ref, bool enabled) async {
    final applied = await ref.read(homeViewModelProvider.notifier).setOptimizedRouteEnabled(enabled);
    if (applied || !enabled) return;
    if (!context.mounted) return;
    // プレミアム未契約でONにしようとした場合はペイウォールへ誘導する
    // （設計書「Aha Moment直後ではなく、詳細ルート最適化利用時にトリガー」）
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PaywallView(triggerLabel: '詳細ルート最適化')),
    );
    // 購入完了していれば再度トグルをONにする
    await ref.read(homeViewModelProvider.notifier).setOptimizedRouteEnabled(true);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final comfortPercent = (route.averageComfortScore * 100).round();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('近くの安心ルート', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          const Text('現在地周辺で見つかった、日陰や明るさに配慮したルートです'),
          const SizedBox(height: 16),
          SchematicMapView(route: route, currentLat: currentLat, currentLon: currentLon),
          const SizedBox(height: 16),
          Row(
            children: [
              _ScoreBadge(comfortPercent: comfortPercent),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '約${route.distanceM.round()}m ・ 安心スコア $comfortPercent%',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.workspace_premium_outlined),
            title: const Text('詳細ルート最適化'),
            subtitle: const Text('日陰・明るさをより強く優先します（プレミアム機能）'),
            value: isOptimizedRouteEnabled,
            onChanged: (value) => _handleOptimizedToggle(context, ref, value),
          ),
        ],
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.comfortPercent});
  final int comfortPercent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.comfortScoreColor(comfortPercent / 100),
      ),
      child: Text(
        '$comfortPercent',
        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
      ),
    );
  }
}
