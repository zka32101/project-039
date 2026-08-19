import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:anshinmichi/services/verification_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('LocalVerificationService: 初期状態は未確認', () async {
    final service = LocalVerificationService();
    final profile = await service.getProfile();
    expect(profile.isVerified, isFalse);
  });

  test('LocalVerificationService: 誤ったコードで確認するとVerificationExceptionを投げる', () async {
    final service = LocalVerificationService();
    final verificationId = await service.sendVerificationCode('+819012345678');
    expect(
      () => service.confirmVerificationCode(verificationId: verificationId, smsCode: '000000'),
      throwsA(isA<VerificationException>()),
    );
  });

  test('LocalVerificationService: デモコードで確認すると本人確認済みになる', () async {
    final service = LocalVerificationService();
    final verificationId = await service.sendVerificationCode('+819012345678');
    final profile = await service.confirmVerificationCode(
      verificationId: verificationId,
      smsCode: LocalVerificationService.demoCode,
    );
    expect(profile.isVerified, isTrue);

    final reloaded = await service.getProfile();
    expect(reloaded.isVerified, isTrue);
  });
}
