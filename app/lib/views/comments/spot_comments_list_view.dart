import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/spot_comment.dart';
import '../../viewmodels/providers.dart';

/// 「みんなの声」画面。投稿時に任意で付けられるコメント（`spotComments`、NGワードフィルタで
/// 承認済みのもののみ）を新着順に一覧表示する。従来、コメントは投稿時に保存されるだけで
/// 閲覧できるUIが無かった（書き込み専用機能）ため、その解消として追加した
/// （`AnnouncementsListView`と同じ「取得専用・一覧表示」の構成を踏襲）。
class SpotCommentsListView extends ConsumerStatefulWidget {
  const SpotCommentsListView({super.key});

  @override
  ConsumerState<SpotCommentsListView> createState() => _SpotCommentsListViewState();
}

class _SpotCommentsListViewState extends ConsumerState<SpotCommentsListView> {
  List<SpotComment>? _comments;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _errorMessage = null);
    try {
      final comments = await ref.read(spotCommentServiceProvider).fetchRecent();
      if (!mounted) return;
      setState(() => _comments = comments);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'コメントの取得に失敗しました');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('みんなの声')),
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

    final comments = _comments;
    if (comments == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (comments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.forum_outlined, size: 56, color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: 16),
              const Text('コメントはまだありません', textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        itemCount: comments.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final comment = comments[index];
          return ListTile(
            leading: const Icon(Icons.forum_outlined),
            title: Text(comment.text),
            subtitle: comment.createdAt != null ? Text(_formatRelativeTime(comment.createdAt!)) : null,
            isThreeLine: comment.text.length > 40,
          );
        },
      ),
    );
  }

  /// 相対時刻表示（例:「3時間前」）。専用パッケージ（`intl`の`timeago`相当）を追加せず、
  /// Dart標準機能のみで簡易的に実装している。
  String _formatRelativeTime(DateTime createdAt) {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'たった今';
    if (diff.inHours < 1) return '${diff.inMinutes}分前';
    if (diff.inDays < 1) return '${diff.inHours}時間前';
    if (diff.inDays < 30) return '${diff.inDays}日前';
    return '${createdAt.year}/${createdAt.month}/${createdAt.day}';
  }
}
