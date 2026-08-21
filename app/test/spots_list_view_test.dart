import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anshinmichi/views/spots/spots_list_view.dart';

void main() {
  testWidgets('SpotsListView: Firebase未接続時は「投稿はまだありません」を表示', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: SpotsListView()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('投稿はまだありません'), findsOneWidget);
  });
}
