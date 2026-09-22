import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/favorite_route.dart';
import '../../viewmodels/providers.dart';

/// 「お気に入りルート保存」機能の一覧画面。タップした場所をホーム画面の目的地として選択できる
/// （`DestinationPickerView`と同様、`Navigator.pop`で座標を返す設計）。
class FavoriteRoutesView extends ConsumerStatefulWidget {
  const FavoriteRoutesView({super.key});

  @override
  ConsumerState<FavoriteRoutesView> createState() => _FavoriteRoutesViewState();
}

class _FavoriteRoutesViewState extends ConsumerState<FavoriteRoutesView> {
  List<FavoriteRoute>? _favorites;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final favorites = await ref.read(favoriteRouteServiceProvider).loadAll();
    if (!mounted) return;
    setState(() => _favorites = favorites);
  }

  Future<void> _remove(FavoriteRoute favorite) async {
    await ref.read(favoriteRouteServiceProvider).remove(favorite.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('お気に入り')),
      body: SafeArea(child: _buildBody(context)),
    );
  }

  Widget _buildBody(BuildContext context) {
    final favorites = _favorites;
    if (favorites == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (favorites.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.star_border_outlined, size: 56, color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: 16),
              const Text(
                'お気に入りはまだありません\nホーム画面で目的地を選んでから「お気に入り登録」で追加できます',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: favorites.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final favorite = favorites[index];
        return ListTile(
          leading: const Icon(Icons.star_outlined),
          title: Text(favorite.label),
          onTap: () => Navigator.of(context).pop((lat: favorite.lat, lon: favorite.lon)),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '削除',
            onPressed: () => _remove(favorite),
          ),
        );
      },
    );
  }
}
