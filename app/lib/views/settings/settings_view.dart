import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/subscription_state.dart';
import '../../models/user_profile.dart';
import '../../viewmodels/providers.dart';
import '../paywall/paywall_view.dart';
import '../verification/phone_verification_view.dart';

/// 設定画面（設計書Step2「設定 → アカウント（本人確認状態）／通知／サブスク管理／
/// 反映モード表示（自分の投稿がどちらの扱いか）」）。
class SettingsView extends ConsumerStatefulWidget {
  const SettingsView({super.key});

  @override
  ConsumerState<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends ConsumerState<SettingsView> {
  String? _uid;
  SubscriptionState _subscription = SubscriptionState.free;
  UserProfile _profile = UserProfile.unverified;
  bool _notificationEnabled = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = await ref.read(authServiceProvider).ensureSignedIn();
    final subscription = await ref.read(subscriptionServiceProvider).getStatus();
    final notificationEnabled = await ref.read(notificationPreferenceStorageProvider).isEnabled();
    final profile = await ref.read(verificationServiceProvider).getProfile();
    if (!mounted) return;
    setState(() {
      _uid = uid;
      _subscription = subscription;
      _notificationEnabled = notificationEnabled;
      _profile = profile;
      _isLoading = false;
    });
  }

  Future<void> _openPaywall() async {
    final purchased = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const PaywallView(triggerLabel: 'サブスク管理')),
    );
    if (purchased == true) {
      final subscription = await ref.read(subscriptionServiceProvider).getStatus();
      if (!mounted) return;
      setState(() => _subscription = subscription);
    }
  }

  Future<void> _openVerification() async {
    final verified = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const PhoneVerificationView()),
    );
    if (verified == true) {
      final profile = await ref.read(verificationServiceProvider).getProfile();
      if (!mounted) return;
      setState(() => _profile = profile);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('設定')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final remoteConfig = ref.watch(remoteConfigServiceProvider);
    final moderationConfig = remoteConfig.moderationConfig;

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        children: [
          const _SectionHeader('アカウント'),
          ListTile(
            leading: Icon(
              _profile.isVerified ? Icons.verified_user : Icons.verified_user_outlined,
              color: _profile.isVerified ? Theme.of(context).colorScheme.primary : null,
            ),
            title: const Text('本人確認'),
            subtitle: Text(_profile.isVerified ? '確認済み' : '未確認（電話番号で確認できます）'),
            trailing: _profile.isVerified ? null : const Icon(Icons.chevron_right),
            onTap: _profile.isVerified ? null : _openVerification,
          ),
          ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: const Text('ユーザーID'),
            subtitle: Text(_uid ?? '-'),
          ),
          const Divider(),
          const _SectionHeader('通知'),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_outlined),
            title: const Text('お知らせを受け取る'),
            subtitle: const Text('新機能・地域拡大等のお知らせを通知します'),
            value: _notificationEnabled,
            onChanged: (value) async {
              await ref.read(notificationPreferenceStorageProvider).setEnabled(value);
              if (!mounted) return;
              setState(() => _notificationEnabled = value);
            },
          ),
          const Divider(),
          const _SectionHeader('サブスク管理'),
          ListTile(
            leading: Icon(
              _subscription.isPremium ? Icons.workspace_premium : Icons.workspace_premium_outlined,
              color: _subscription.isPremium ? Theme.of(context).colorScheme.primary : null,
            ),
            title: Text(_subscription.isPremium ? 'プレミアムプラン利用中' : '無料プラン'),
            subtitle: Text(
              _subscription.isPremium ? '詳細ルート最適化・オフライン地図が利用できます' : 'プレミアムでできることを見る',
            ),
            trailing: _subscription.isPremium ? null : const Icon(Icons.chevron_right),
            onTap: _subscription.isPremium ? null : _openPaywall,
          ),
          const Divider(),
          const _SectionHeader('反映モード'),
          ListTile(
            leading: Icon(
              moderationConfig.autoApproveAnonymous ? Icons.flash_on_outlined : Icons.hourglass_top_outlined,
            ),
            title: Text(moderationConfig.autoApproveAnonymous ? '即時反映' : '承認待ち'),
            subtitle: Text(
              moderationConfig.autoApproveAnonymous
                  ? 'あなたの投稿は確認後すぐに地図へ反映されます（地域: ${moderationConfig.region}）'
                  : 'あなたの投稿は運営の承認後に地図へ反映されます（地域: ${moderationConfig.region}）',
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}
