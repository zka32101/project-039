import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anshinmichi/views/destination/destination_picker_view.dart';

void main() {
  testWidgets('DestinationPickerView: 道路網読み込み後、地図タップの案内文とボタンが表示される', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: DestinationPickerView()),
      ),
    );

    // アセットからの道路網読み込み（非同期）を待つ
    await tester.pumpAndSettle();

    expect(find.text('地図をタップして目的地を選んでください'), findsOneWidget);
    expect(find.text('この場所を目的地にする'), findsOneWidget);
  });

  testWidgets('DestinationPickerView: 何も選択せずに確定を押しても画面は閉じない', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: DestinationPickerView()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('この場所を目的地にする'));
    await tester.pumpAndSettle();

    expect(find.byType(DestinationPickerView), findsOneWidget);
  });
}
