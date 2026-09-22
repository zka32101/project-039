import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/map_config.dart';
import '../../models/route_result.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/home_view_model.dart';
import '../../viewmodels/providers.dart';
import '../../widgets/primary_button.dart';
import '../announcements/announcements_list_view.dart';
import '../comments/spot_comments_list_view.dart';
import '../destination/destination_picker_view.dart';
import '../favorites/favorite_routes_view.dart';
import '../paint/paint_submission_view.dart';
import '../paywall/paywall_view.dart';
import '../settings/settings_view.dart';
import '../spots/my_submissions_view.dart';
import '../spots/spots_list_view.dart';
import 'widgets/real_map_route_view.dart';
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
            icon: const Icon(Icons.fact_check_outlined),
            tooltip: '投稿を確認',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SpotsListView()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.forum_outlined),
            tooltip: 'みんなの声',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SpotCommentsListView()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.campaign_outlined),
            tooltip: 'お知らせ',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AnnouncementsListView()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.star_border_outlined),
            tooltip: 'お気に入り',
            onPressed: () async {
              final selected = await Navigator.of(context).push<({double lat, double lon})>(
                MaterialPageRoute(builder: (_) => const FavoriteRoutesView()),
              );
              if (selected == null) return;
              await ref.read(homeViewModelProvider.notifier).setDestination(selected.lat, selected.lon);
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'マイページ',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MySubmissionsView()),
            ),
          ),
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
          HomeReady(
            :final route,
            :final currentLat,
            :final currentLon,
            :final isOptimizedRouteEnabled,
            :final hasCustomDestination,
          ) =>
            _ReadyView(
              route: route,
              currentLat: currentLat,
              currentLon: currentLon,
              isOptimizedRouteEnabled: isOptimizedRouteEnabled,
              hasCustomDestination: hasCustomDestination,
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

/// オフライン時、`RouteResultCache`から復元したルートを表示していることを明示するバナー
/// （バックログ「オフライン地図の実キャッシュ」対応）。実際の日陰・混雑状況とは
/// ズレている可能性があるため、その旨を伝えることを目的とする。
class _OfflineCacheBanner extends StatelessWidget {
  const _OfflineCacheBanner();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_outlined, size: 18, color: scheme.onTertiaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'オフラインのため前回の検索結果を表示中です。実際の状況と異なる場合があります',
              style: TextStyle(color: scheme.onTertiaryContainer, fontSize: 12),
            ),
          ),
        ],
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
    required this.hasCustomDestination,
  });

  final RouteResult route;
  final double currentLat;
  final double currentLon;
  final bool isOptimizedRouteEnabled;
  final bool hasCustomDestination;

  Future<void> _pickDestination(BuildContext context, WidgetRef ref) async {
    final selected = await Navigator.of(context).push<({double lat, double lon})>(
      MaterialPageRoute(builder: (_) => const DestinationPickerView()),
    );
    if (selected == null) return;
    await ref.read(homeViewModelProvider.notifier).setDestination(selected.lat, selected.lon);
  }

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
          Text(hasCustomDestination ? '選んだ目的地までの安心ルート' : '近くの安心ルート', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            hasCustomDestination
                ? '選んだ目的地までの、日陰や明るさに配慮したルートです'
                : '現在地周辺で見つかった、日陰や明るさに配慮したルートです',
          ),
          if (route.isFromCache) ...[
            const SizedBox(height: 8),
            const _OfflineCacheBanner(),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickDestination(context, ref),
                  icon: const Icon(Icons.place_outlined),
                  label: const Text('目的地を選ぶ'),
                ),
              ),
              if (hasCustomDestination) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => ref.read(homeViewModelProvider.notifier).clearDestination(),
                  child: const Text('自動提案に戻す'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          useGoogleMapTiles
              ? RealMapRouteView(route: route, currentLat: currentLat, currentLon: currentLon)
              : SchematicMapView(route: route, currentLat: currentLat, currentLon: currentLon),
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
          const SizedBox(height: 8),
          _ModeToggleRow(mode: route.mode),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _shareRoute(context, route, hasCustomDestination),
                  icon: const Icon(Icons.ios_share_outlined),
                  label: const Text('ルート情報をコピー'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _saveFavorite(context, ref, hasCustomDestination),
                  icon: const Icon(Icons.star_border_outlined),
                  label: const Text('お気に入り登録'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 「経路の共有」機能: ルート概要をクリップボードへコピーする。
  /// 【スコープ】ネイティブの共有シート（`share_plus`パッケージ）はこのセッションが
  /// `flutter pub get`を検証できないため見送り、Flutter SDK標準の`Clipboard`のみで実装。
  /// ローカル環境で`share_plus`を追加すれば`Share.share(text)`に差し替えるだけで済む。
  Future<void> _shareRoute(BuildContext context, RouteResult route, bool hasCustomDestination) async {
    final comfortPercent = (route.averageComfortScore * 100).round();
    final text = '【あんしんみち】${hasCustomDestination ? "選んだ目的地までの" : "近くの"}安心ルート\n'
        '距離: 約${route.distanceM.round()}m ・ 安心スコア $comfortPercent%';
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ルート情報をコピーしました')),
    );
  }

  /// 「お気に入りルート保存」機能: 現在の目的地を端末内に保存し、次回ホーム画面から
  /// ワンタップで呼び出せるようにする（`FavoriteRoutesView`参照）。
  Future<void> _saveFavorite(BuildContext context, WidgetRef ref, bool hasCustomDestination) async {
    if (!hasCustomDestination) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('先に「目的地を選ぶ」でお気に入りにしたい場所を選んでください')),
      );
      return;
    }
    final label = await showDialog<String>(
      context: context,
      builder: (context) => const _FavoriteNameDialog(),
    );
    if (label == null || label.trim().isEmpty) return;
    final destination = ref.read(homeViewModelProvider.notifier).currentDestination;
    if (destination == null) return;
    await ref.read(favoriteRouteServiceProvider).add(
          label: label.trim(),
          lat: destination.lat,
          lon: destination.lon,
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('「${label.trim()}」をお気に入りに登録しました')),
    );
  }
}

class _FavoriteNameDialog extends StatefulWidget {
  const _FavoriteNameDialog();

  @override
  State<_FavoriteNameDialog> createState() => _FavoriteNameDialogState();
}

class _FavoriteNameDialogState extends State<_FavoriteNameDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('お気に入りの名前'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: '例: 自宅、職場'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('キャンセル')),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('保存'),
        ),
      ],
    );
  }
}

/// 「日中/夜間モード切替」機能: `HomeViewModel.setMode()`（実装済みだが従来はUIから
/// 呼び出す手段が無かった）を呼び出すトグルボタン。日中は日陰、夜間は明るさを
/// 評価軸として優先する（`functions/index.js`の`searchRoute`の`mode`参照）。
class _ModeToggleRow extends ConsumerWidget {
  const _ModeToggleRow({required this.mode});
  final RouteMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Icon(
          mode == RouteMode.night ? Icons.nightlight_outlined : Icons.wb_sunny_outlined,
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 8),
        const Text('経路探索モード'),
        const Spacer(),
        SegmentedButton<RouteMode>(
          segments: const [
            ButtonSegment(value: RouteMode.day, label: Text('日中'), icon: Icon(Icons.wb_sunny_outlined)),
            ButtonSegment(value: RouteMode.night, label: Text('夜間'), icon: Icon(Icons.nightlight_outlined)),
          ],
          selected: {mode},
          onSelectionChanged: (selection) => ref.read(homeViewModelProvider.notifier).setMode(selection.first),
        ),
      ],
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
