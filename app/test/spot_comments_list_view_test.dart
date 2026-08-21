import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anshinmichi/views/comments/spot_comments_list_view.dart';

void main() {
  testWidgets('SpotCommentsListView: Firebase未接続時は「コメントはまだありません」を表示', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: SpotCommentsListView()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('コメントはまだありません'), findsOneWidget);
  });
}
