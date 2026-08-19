import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anshinmichi/views/onboarding/onboarding_view.dart';

void main() {
  testWidgets('OnboardingView: 初期表示で1枚目のタイトルとスキップ・次へボタンが見える', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: OnboardingView()),
      ),
    );

    expect(find.text('影・雨よけ・明るさを、みんなで塗って共有'), findsOneWidget);
    expect(find.text('スキップ'), findsOneWidget);
    expect(find.text('次へ'), findsOneWidget);
  });

  testWidgets('OnboardingView: 「次へ」を2回押すと最終ページで「はじめる」に変わる', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: OnboardingView()),
      ),
    );

    await tester.tap(find.text('次へ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('次へ'));
    await tester.pumpAndSettle();

    expect(find.text('はじめる'), findsOneWidget);
  });
}
