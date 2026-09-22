import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anshinmichi/models/spot_type.dart';
import 'package:anshinmichi/views/paint/widgets/spot_type_selector.dart';

void main() {
  testWidgets('SpotTypeSelector: 全種別が表示され、タップで選択が通知される', (tester) async {
    SpotType? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          // SpotTypeSelectorはshrinkWrap+NeverScrollableScrollPhysicsのGridViewのため、
          // 実際の埋め込み先（_TypeSelectionStep）と同様にスクロール可能な親が必要
          // （投稿種別が8種になり、Scaffold.body直下では画面高に収まらない場合がある）。
          body: SingleChildScrollView(
            child: SpotTypeSelector(
              selected: null,
              onSelected: (type) => selected = type,
            ),
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
