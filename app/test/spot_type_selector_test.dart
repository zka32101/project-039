import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anshinmichi/models/spot_type.dart';
import 'package:anshinmichi/views/paint/widgets/spot_type_selector.dart';

void main() {
  testWidgets('SpotTypeSelector: 4種別すべてが表示され、タップで選択が通知される', (tester) async {
    SpotType? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SpotTypeSelector(
            selected: null,
            onSelected: (type) => selected = type,
          ),
        ),
      ),
    );

    for (final type in SpotType.values) {
      expect(find.text(type.label), findsOneWidget);
    }

    await tester.tap(find.text(SpotType.tree.label));
    await tester.pump();

    expect(selected, SpotType.tree);
  });
}
