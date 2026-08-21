import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anshinmichi/views/destination/destination_picker_view.dart';

void main() {
  // rootBundle（グローバルなシングルトン）はloadStringの結果をFutureごとキャッシュするため、
  // 同一ファイル内で複数のtestWidgetsが同じアセットを読み込むと、2件目以降はキャッシュされた
  // Futureを再利用する。ただしそのFutureは1件目のtestWidgetsのfakeAsyncゾーンに紐づいており、
  // ゾーン終了後は完了コールバックが配送されず2件目が永久にハングする（pumpAndSettle timeout）。
  // 各テスト前にキャッシュを明示的に破棄し、テストごとに独立して読み込ませることで回避する。
  setUp(() => rootBundle.evict('assets/sample_road_network.json'));

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

    // 地図（AspectRatio）が横幅に対して正方形になるため、テスト用の画面サイズによっては
    // ボタンが画面外にスクロールされている場合がある。確実にタップするため先にスクロールする。
    await tester.ensureVisible(find.text('この場所を目的地にする'));
    await tester.tap(find.text('この場所を目的地にする'));
    await tester.pumpAndSettle();

    expect(find.byType(DestinationPickerView), findsOneWidget);
  });
}
