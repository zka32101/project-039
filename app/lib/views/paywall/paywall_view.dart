import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/subscription_service.dart';
import '../../viewmodels/providers.dart';
import '../../widgets/primary_button.dart';

/// ペイウォール。設計書「Aha Moment直後ではなく、詳細ルート最適化・オフライン地図利用時に
/// トリガー」に従い、該当機能を使おうとしたタイミングでのみ表示する（プッシュ的な表示はしない）。
class PaywallView extends ConsumerStatefulWidget {
  const PaywallView({super.key, this.triggerLabel});

  /// 呼び出し元の機能名（例:「詳細ルート最適化」）。文脈を示すために表示する。
  final String? triggerLabel;

  @override
  ConsumerState<PaywallView> createState() => _PaywallViewState();
}

class _PaywallViewState extends ConsumerState<PaywallView> {
  bool _isProcessing = false;
  String? _errorMessage;

  Future<void> _purchase() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });
    try {
      final status = await ref.read(subscriptionServiceProvider).purchasePremium();
      if (!mounted) return;
      if (status.isPremium) {
        ref.read(analyticsServiceProvider).logPaywallConverted();
        Navigator.of(context).pop(true);
      }
    } on PurchaseException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = '購入処理でエラーが発生しました');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _restore() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });
    try {
      final status = await ref.read(subscriptionServiceProvider).restorePurchases();
      if (!mounted) return;
      if (status.isPremium) {
        Navigator.of(context).pop(true);
      } else {
        setState(() => _errorMessage = '復元できる購入情報が見つかりませんでした');
      }
    } catch (e) {
      setState(() => _errorMessage = '復元処理でエラーが発生しました');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFirebaseless = !ref.watch(purchasesAvailableProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('プレミアムプラン')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.triggerLabel != null) ...[
                Text(
                  '「${widget.triggerLabel}」はプレミアムプラン限定の機能です',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
              ],
              Icon(Icons.workspace_premium_outlined, size: 72, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              Text('あんしんみち プレミアム', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              const _FeatureRow(icon: Icons.route_outlined, label: '詳細ルート最適化（安心スコアをより強く優先）'),
              const _FeatureRow(icon: Icons.wifi_off_outlined, label: 'オフライン地図利用'),
              const SizedBox(height: 24),
              if (_errorMessage != null) ...[
                Text(_errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                const SizedBox(height: 12),
              ],
              PrimaryButton(label: 'プレミアムに登録する', onPressed: _purchase),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _isProcessing ? null : _restore,
                child: const Text('購入を復元する'),
              ),
              if (isFirebaseless) ...[
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  'RevenueCat未接続環境のため、実際の課金は発生しません。'
                  '「プレミアムに登録する」を押すと、デモとしてプレミアム状態が端末内に保存されます。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}
