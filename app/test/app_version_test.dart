import 'package:flutter_test/flutter_test.dart';
import 'package:anshinmichi/services/app_version.dart';

void main() {
  group('isUpdateRequired', () {
    test('現在バージョンが最小サポートバージョン以上ならfalse', () {
      expect(isUpdateRequired(current: '0.2.0', minSupported: '0.1.0'), isFalse);
      expect(isUpdateRequired(current: '0.1.0', minSupported: '0.1.0'), isFalse);
    });

    test('現在バージョンが最小サポートバージョン未満ならtrue', () {
      expect(isUpdateRequired(current: '0.1.0', minSupported: '0.2.0'), isTrue);
    });

    test('桁数が異なっても正しく比較できる', () {
      expect(isUpdateRequired(current: '1.0', minSupported: '1.0.1'), isTrue);
      expect(isUpdateRequired(current: '1.0.1', minSupported: '1.0'), isFalse);
    });
  });
}
