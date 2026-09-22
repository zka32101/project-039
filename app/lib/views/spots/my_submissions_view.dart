import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/spot_summary.dart';
import '../../viewmodels/providers.dart';

/// 「マイページ」機能: 自分の投稿履歴を審査状態込みで振り返る画面。
/// 「投稿を確認」画面（`SpotsListView`）が承認済み投稿のみを横断表示するのに対し、
/// こちらは`submitterId`で自分の投稿だけに絞り込み、審査待ち（pending）の投稿も表示する
/// （継続投稿のモチベーションになるよう、承認済み件数がひと目でわかるようにする）。
class MySubmissionsView extends ConsumerStatefulWidget {
  const MySubmissionsView({super.key});

  @override
  ConsumerState<MySubmissionsView> createState() => _MySubmissionsViewState();
}

class _MySubmissionsViewState extends ConsumerState<MySubmissionsView> {
  List<SpotSummary>? _spots;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _errorMessage = null);
    try {
      final uid = await ref.read(authServiceProvider).ensureSignedIn();
      final spots = await ref.read(spotListServiceProvider).fetchOwnSubmissions(uid);
      if (!mounted) return;
      setState(() => _spots = spots);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = '投稿履歴の取得に失敗しました');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('マイページ')),
      body: SafeArea(child: _buildBody(context)),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_errorMessage!, textAlign: TextAlign.center),
        ),
      );
    }

    final spots = _spots;
    if (spots == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (spots.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_outline, size: 56, color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: 16),
              const Text('まだ投稿がありません', textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    final approvedCount = spots.where((s) => s.status == 'approved').length;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '投稿数 ${spots.length}件（承認済み $approvedCount件）',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const Divider(height: 1),
          for (final spot in spots) _MySubmissionTile(spot: spot),
        ],
      ),
    );
  }
}

class _MySubmissionTile extends StatelessWidget {
  const _MySubmissionTile({required this.spot});

  final SpotSummary spot;

  @override
  Widget build(BuildContext context) {
    final isApproved = spot.status == 'approved';
    return ListTile(
      leading: Icon(isApproved ? Icons.check_circle_outline : Icons.hourglass_empty),
      title: Text(spot.label),
      subtitle: Text(isApproved ? '承認済み・確認 ${spot.votes}・通報 ${spot.reportCount}' : '審査待ち'),
    );
  }
}
