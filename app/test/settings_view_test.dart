import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:anshinmichi/views/settings/settings_view.dart';

void main() {
  setUp(() {
    // SettingsViewはAuthService/NotificationPreferenceStorageでSharedPreferencesを使うため、
    // テスト実行時はモック初期値で代替する。
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('SettingsView: 4セクションが表示される', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: SettingsView()),
      ),
    );

    // 非同期ロード（匿名ID発行・サブスク状態取得・通知設定取得）の完了を待つ
    await tester.pumpAndSettle();

    expect(find.text('アカウント'), findsOneWidget);
    expect(find.text('通知'), findsOneWidget);
    expect(find.text('サブスク管理'), findsOneWidget);
    expect(find.text('反映モード'), findsOneWidget);
  });
}
