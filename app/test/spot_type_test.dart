import 'package:flutter_test/flutter_test.dart';
import 'package:anshinmichi/models/spot_type.dart';

void main() {
  group('SpotType.isHazardReport / requiresManualReview', () {
    test('危険・困りごと系の投稿種別はisHazardReport=trueかつ常に人力承認', () {
      for (final type in [SpotType.unevenGround, SpotType.darkStairs, SpotType.narrowSidewalk]) {
        expect(type.isHazardReport, true, reason: '${type.name}はhazard report扱いのはず');
        expect(type.requiresManualReview, true, reason: '${type.name}は常に人力承認のはず');
      }
    });

    test('日陰・雨よけ系の投稿種別はisHazardReport=false', () {
      for (final type in [SpotType.tree, SpotType.arcade, SpotType.rainShelter]) {
        expect(type.isHazardReport, false);
      }
    });

    test('人通りが少ない投稿は危険報告ではないが人力承認は必須', () {
      expect(SpotType.lowFootTraffic.isHazardReport, false);
      expect(SpotType.lowFootTraffic.requiresManualReview, true);
    });

    test('危険・困りごと系は時間帯に依存しない', () {
      for (final type in [SpotType.unevenGround, SpotType.darkStairs, SpotType.narrowSidewalk]) {
        expect(type.isTimeDependent, false);
      }
    });
  });
}
