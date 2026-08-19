import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/verification_service.dart';
import '../../viewmodels/providers.dart';
import '../../widgets/primary_button.dart';

enum _Step { enterPhone, enterCode }

/// 本人確認（電話番号認証）フロー。設定画面の「本人確認」および、投稿確認画面の
/// 「本人確認してコメントを追加」から遷移する。
class PhoneVerificationView extends ConsumerStatefulWidget {
  const PhoneVerificationView({super.key});

  @override
  ConsumerState<PhoneVerificationView> createState() => _PhoneVerificationViewState();
}

class _PhoneVerificationViewState extends ConsumerState<PhoneVerificationView> {
  _Step _step = _Step.enterPhone;
  String? _verificationId;
  String? _errorMessage;
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      setState(() => _errorMessage = '電話番号を入力してください');
      return;
    }
    setState(() => _errorMessage = null);
    try {
      final verificationId = await ref.read(verificationServiceProvider).sendVerificationCode(phone);
      if (!mounted) return;
      setState(() {
        _verificationId = verificationId;
        _step = _Step.enterCode;
      });
    } on VerificationException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = 'コード送信に失敗しました。もう一度お試しください');
    }
  }

  Future<void> _confirmCode() async {
    final verificationId = _verificationId;
    final code = _codeController.text.trim();
    if (verificationId == null || code.isEmpty) return;

    setState(() => _errorMessage = null);
    try {
      final profile = await ref.read(verificationServiceProvider).confirmVerificationCode(
            verificationId: verificationId,
            smsCode: code,
          );
      if (!mounted) return;
      if (profile.isVerified) {
        Navigator.of(context).pop(true);
      } else {
        setState(() => _errorMessage = '確認に失敗しました。もう一度お試しください');
      }
    } on VerificationException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = '確認に失敗しました。もう一度お試しください');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFirebaseless = !ref.watch(firebaseAvailableProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('本人確認')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_step == _Step.enterPhone) ..._buildPhoneStep(context) else ..._buildCodeStep(context),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(_errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              if (isFirebaseless) ...[
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  'Firebase未接続環境のため、実際のSMS送信は行われません。'
                  '確認コードには「${LocalVerificationService.demoCode}」を入力してください。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildPhoneStep(BuildContext context) {
    return [
      Icon(Icons.phone_iphone_outlined, size: 64, color: Theme.of(context).colorScheme.primary),
      const SizedBox(height: 16),
      Text('電話番号でSMS確認を行います', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 4),
      const Text('本人確認済みになると、投稿にコメントを追加できるようになります'),
      const SizedBox(height: 16),
      TextField(
        controller: _phoneController,
        keyboardType: TextInputType.phone,
        decoration: const InputDecoration(
          labelText: '電話番号（国番号付き 例: +819012345678）',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 16),
      PrimaryButton(label: 'コードを送信', onPressed: _sendCode),
    ];
  }

  List<Widget> _buildCodeStep(BuildContext context) {
    return [
      Icon(Icons.sms_outlined, size: 64, color: Theme.of(context).colorScheme.primary),
      const SizedBox(height: 16),
      Text('確認コードを入力してください', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 4),
      Text('${_phoneController.text} 宛に送信しました'),
      const SizedBox(height: 16),
      TextField(
        controller: _codeController,
        keyboardType: TextInputType.number,
        maxLength: 6,
        decoration: const InputDecoration(
          labelText: '確認コード（6桁）',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 16),
      PrimaryButton(label: '確認する', onPressed: _confirmCode),
      TextButton(
        onPressed: () => setState(() {
          _step = _Step.enterPhone;
          _codeController.clear();
        }),
        child: const Text('電話番号を変更する'),
      ),
    ];
  }
}
