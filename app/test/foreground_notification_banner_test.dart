import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anshinmichi/models/app_notification.dart';
import 'package:anshinmichi/widgets/foreground_notification_banner.dart';

void main() {
  testWidgets('ForegroundBannerQueue: 複数通知は重ねて表示されず、1件ずつ直列に表示される', (tester) async {
    late OverlayState overlay;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            overlay = Overlay.of(context);
            return const Scaffold(body: SizedBox());
          },
        ),
      ),
    );

    final queue = ForegroundBannerQueue();
    const first = AppNotification(title: '1件目', body: '最初のお知らせ');
    const second = AppNotification(title: '2件目', body: '2番目のお知らせ');

    // ほぼ同時に2件をキューへ投入する。
    queue.enqueue(overlay, first, displayDuration: const Duration(seconds: 2));
    queue.enqueue(overlay, second, displayDuration: const Duration(seconds: 2));
    await tester.pump(); // スライドイン開始
    await tester.pump(const Duration(milliseconds: 300)); // スライドイン完了

    // 1件目のみが表示され、2件目はまだキューで待機している。
    expect(find.text('1件目'), findsOneWidget);
    expect(find.text('2件目'), findsNothing);

    // 1件目の自動消滅（2秒）+ スライドアウトを待つ。
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 300));

    // 1件目が消え、2件目が表示される。
    expect(find.text('1件目'), findsNothing);
    expect(find.text('2件目'), findsOneWidget);

    // 後片付け（保留中のタイマーが残らないよう2件目も消しておく）。
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('ForegroundBannerQueue: タップすると即座に消えてonTapが呼ばれる', (tester) async {
    late OverlayState overlay;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            overlay = Overlay.of(context);
            return const Scaffold(body: SizedBox());
          },
        ),
      ),
    );

    final queue = ForegroundBannerQueue();
    var tapped = false;
    queue.enqueue(
      overlay,
      const AppNotification(title: 'タップテスト', body: ''),
      onTap: () => tapped = true,
      displayDuration: const Duration(seconds: 10),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('タップテスト'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tapped, true);
    expect(find.text('タップテスト'), findsNothing);
  });
}
