import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/spot_summary.dart';
import '../../services/spot_dispute_service.dart';
import '../../services/spot_retraction_service.dart';
import '../../viewmodels/providers.dart';

/// 「マイページ」機能: 自分の投稿履歴を審査状態込みで振り返る画面。
/// 「投稿を確認」画面（`SpotsListView`）が承認済み投稿のみを横断表示するのに対し、
/// こちらは`submitterId`で自分の投稿だけに絞り込み、審査待ち（pending）の投稿も表示する
/// （継続投稿のモチベーションになるよう、承認済み件数がひと目でわかるようにする）。
///
/// 「投稿の取り消し申請」「通報された投稿者への異議申し立て」の導線もここに置く
/// （自分の投稿に対する操作という点で共通するため）。
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
          for (final spot in spots) _MySubmissionTile(spot: spot, onChanged: _load),
        ],
      ),
    );
  }
}

class _MySubmissionTile extends ConsumerStatefulWidget {
  const _MySubmissionTile({required this.spot, required this.onChanged});

  final SpotSummary spot;

  /// 取り消し・異議申し立て成功後に呼び、一覧を最新化する。
  final Future<void> Function() onChanged;

  @override
  ConsumerState<_MySubmissionTile> createState() => _MySubmissionTileState();
}

class _MySubmissionTileState extends ConsumerState<_MySubmissionTile> {
  bool _isBusy = false;

  bool get _isDisputable => widget.spot.status == 'pending' && widget.spot.reportCount > 0;
  bool get _isRetracted => widget.spot.status == 'retracted';

  Future<void> _confirmRetract() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('投稿を取り消しますか？'),
        content: Text('「${widget.spot.label}」を取り消します。この操作は元に戻せません。'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('キャンセル')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('取り消す')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(() => ref.read(spotRetractionServiceProvider).retract(kind: widget.spot.kind, spotId: widget.spot.id));
  }

  Future<void> _openDisputeDialog() async {
    final controller = TextEditingController();
    final message = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('異議を申し立てる'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          maxLength: 500,
          decoration: const InputDecoration(hintText: '通報の内容に誤りがある場合など、状況を説明してください'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('キャンセル')),
          TextButton(onPressed: () => Navigator.of(context).pop(controller.text), child: const Text('送信')),
        ],
      ),
    );
    if (message == null || message.trim().isEmpty) return;
    await _run(
      () => ref.read(spotDisputeServiceProvider).dispute(
            kind: widget.spot.kind,
            spotId: widget.spot.id,
            message: message.trim(),
          ),
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      await action();
      await widget.onChanged();
    } on SpotRetractionException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } on SpotDisputeException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('操作に失敗しました')));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final spot = widget.spot;
    final isApproved = spot.status == 'approved';

    return ListTile(
      leading: Icon(_statusIcon(spot.status)),
      title: Text(spot.label),
      subtitle: Text(_statusText(spot)),
      trailing: _isBusy
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : _isRetracted
              ? null
              : PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'retract') _confirmRetract();
                    if (value == 'dispute') _openDisputeDialog();
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'retract', child: Text('取り消す')),
                    if (_isDisputable) const PopupMenuItem(value: 'dispute', child: Text('異議を申し立てる')),
                  ],
                ),
      isThreeLine: isApproved,
    );
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'approved':
        return Icons.check_circle_outline;
      case 'retracted':
        return Icons.block_outlined;
      default:
        return Icons.hourglass_empty;
    }
  }

  String _statusText(SpotSummary spot) {
    switch (spot.status) {
      case 'approved':
        return '承認済み・確認 ${spot.votes}・通報 ${spot.reportCount}';
      case 'retracted':
        return '取り消し済み';
      default:
        return _isDisputable ? '通報により再審査待ち・異議申し立てができます' : '審査待ち';
    }
  }
}
