import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anshinmichi/views/paywall/paywall_view.dart';

void main() {
  testWidgets('PaywallView: トリガー元の機能名と主要な導線が表示される', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: PaywallView(triggerLabel: '詳細ルート最適化')),
      ),
    );

    expect(find.textContaining('詳細ルート最適化'), findsWidgets);
    expect(find.text('プレミアムに登録する'), findsOneWidget);
    expect(find.text('購入を復元する'), findsOneWidget);
  });
}
