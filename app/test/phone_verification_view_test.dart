import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:anshinmichi/views/verification/phone_verification_view.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('PhoneVerificationView: 初期表示は電話番号入力ステップ', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: PhoneVerificationView()),
      ),
    );

    expect(find.text('電話番号でSMS確認を行います'), findsOneWidget);
    expect(find.text('コードを送信'), findsOneWidget);
  });

  testWidgets('PhoneVerificationView: 電話番号未入力で送信するとエラーを表示', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: PhoneVerificationView()),
      ),
    );

    await tester.tap(find.text('コードを送信'));
    await tester.pumpAndSettle();

    expect(find.text('電話番号を入力してください'), findsOneWidget);
  });

  testWidgets('PhoneVerificationView: 電話番号入力後にコード送信するとコード入力ステップへ進む', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: PhoneVerificationView()),
      ),
    );

    await tester.enterText(find.byType(TextField).first, '+819012345678');
    await tester.tap(find.text('コードを送信'));
    await tester.pumpAndSettle();

    expect(find.text('確認コードを入力してください'), findsOneWidget);
  });
}
