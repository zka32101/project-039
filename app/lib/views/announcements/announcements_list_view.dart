import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/announcement.dart';
import '../../viewmodels/providers.dart';

/// お知らせ一覧画面（設計書Step7）。設定画面の「通知」から独立した機能として、
/// ホーム画面のAppBarからも遷移できる。
class AnnouncementsListView extends ConsumerStatefulWidget {
  const AnnouncementsListView({super.key});

  @override
  ConsumerState<AnnouncementsListView> createState() => _AnnouncementsListViewState();
}

class _AnnouncementsListViewState extends ConsumerState<AnnouncementsListView> {
  List<Announcement>? _announcements;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _errorMessage = null);
    try {
      final announcements = await ref.read(announcementServiceProvider).fetchRecent();
      if (!mounted) return;
      setState(() => _announcements = announcements);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'お知らせの取得に失敗しました');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('お知らせ')),
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

    final announcements = _announcements;
    if (announcements == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (announcements.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.campaign_outlined, size: 56, color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: 16),
              const Text('お知らせはまだありません', textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        itemCount: announcements.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final announcement = announcements[index];
          return ListTile(
            leading: const Icon(Icons.campaign_outlined),
            title: Text(announcement.title),
            subtitle: Text(announcement.body),
            isThreeLine: announcement.body.length > 40,
          );
        },
      ),
    );
  }
}
