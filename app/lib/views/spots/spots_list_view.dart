import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/spot_comment.dart';
import '../../models/spot_summary.dart';
import '../../services/spot_vote_service.dart';
import '../../viewmodels/providers.dart';

/// 「投稿を確認」画面。承認済み投稿（`shadeSpots`/`brightnessSpots`）を一覧表示し、
/// 確認投票（この投稿は正しい）／通報（この投稿は不正確・不適切）ができる
/// （`functions/index.js`の`voteSpot`、詳細な設計意図は`functions/README.md`
/// 「投稿の相互チェック」参照）。`AnnouncementsListView`/`SpotCommentsListView`と同じ
/// 「取得専用・一覧表示」の構成を踏襲している。
class SpotsListView extends ConsumerStatefulWidget {
  const SpotsListView({super.key});

  @override
  ConsumerState<SpotsListView> createState() => _SpotsListViewState();
}

class _SpotsListViewState extends ConsumerState<SpotsListView> {
  List<SpotSummary>? _spots;
  String? _errorMessage;

  /// 投票中の投稿ID（多重タップによる二重送信を防ぐ）。
  final _votingInProgress = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _errorMessage = null);
    try {
      final spots = await ref.read(spotListServiceProvider).fetchRecentApproved();
      if (!mounted) return;
      setState(() => _spots = spots);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = '投稿の取得に失敗しました');
    }
  }

  void _showComments(SpotSummary spot) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SpotCommentsSheet(spot: spot),
    );
  }

  Future<void> _vote(SpotSummary spot, SpotVoteType voteType) async {
    if (_votingInProgress.contains(spot.id)) return;
    setState(() => _votingInProgress.add(spot.id));
    try {
      await ref.read(spotVoteServiceProvider).vote(kind: spot.kind, spotId: spot.id, voteType: voteType);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(voteType == SpotVoteType.confirm ? '確認投票しました' : '通報しました')),
      );
      await _load(); // votes/reportCountの表示を最新化
    } on SpotVoteException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('投票に失敗しました')));
    } finally {
      if (mounted) setState(() => _votingInProgress.remove(spot.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('投稿を確認')),
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
              Icon(Icons.fact_check_outlined, size: 56, color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: 16),
              const Text('投稿はまだありません', textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        itemCount: spots.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) => _SpotTile(
          spot: spots[index],
          isVoting: _votingInProgress.contains(spots[index].id),
          onVote: (voteType) => _vote(spots[index], voteType),
          onTap: () => _showComments(spots[index]),
        ),
      ),
    );
  }
}

class _SpotTile extends StatelessWidget {
  const _SpotTile({required this.spot, required this.isVoting, required this.onVote, required this.onTap});

  final SpotSummary spot;
  final bool isVoting;
  final void Function(SpotVoteType voteType) onVote;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: const Icon(Icons.place_outlined),
      title: Text(spot.label),
      subtitle: Text('確認 ${spot.votes} ・ 通報 ${spot.reportCount} ・ タップでコメントを見る'),
      trailing: isVoting
          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.check_circle_outline),
                  tooltip: 'この投稿は正しい',
                  onPressed: () => onVote(SpotVoteType.confirm),
                ),
                IconButton(
                  icon: const Icon(Icons.flag_outlined),
                  tooltip: 'この投稿は不正確・不適切',
                  onPressed: () => onVote(SpotVoteType.report),
                ),
              ],
            ),
    );
  }
}

/// 投稿1件に付けられた承認済みコメントを表示するボトムシート。「みんなの声」画面が
/// 承認済みコメントを横断的に一覧表示するのに対し、こちらは特定の投稿（[spot]）に
/// 絞り込んだ表示（`SpotCommentService.fetchForSpot`）。
class _SpotCommentsSheet extends ConsumerStatefulWidget {
  const _SpotCommentsSheet({required this.spot});

  final SpotSummary spot;

  @override
  ConsumerState<_SpotCommentsSheet> createState() => _SpotCommentsSheetState();
}

class _SpotCommentsSheetState extends ConsumerState<_SpotCommentsSheet> {
  List<SpotComment>? _comments;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final comments = await ref.read(spotCommentServiceProvider).fetchForSpot(widget.spot.id);
      if (!mounted) return;
      setState(() => _comments = comments);
    } catch (e) {
      if (!mounted) return;
      setState(() => _hasError = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${widget.spot.label}のコメント', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Flexible(child: _buildBody(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_hasError) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text('コメントの取得に失敗しました'),
      );
    }
    final comments = _comments;
    if (comments == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (comments.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text('この投稿にはまだコメントがありません'),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      itemCount: comments.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.forum_outlined),
        title: Text(comments[index].text),
      ),
    );
  }
}
