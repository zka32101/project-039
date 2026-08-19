import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anshinmichi/views/announcements/announcements_list_view.dart';

void main() {
  testWidgets('AnnouncementsListView: Firebase未接続時は「お知らせはまだありません」を表示', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: AnnouncementsListView()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('お知らせはまだありません'), findsOneWidget);
  });
}
