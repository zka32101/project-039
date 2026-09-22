import 'package:flutter_test/flutter_test.dart';
import 'package:anshinmichi/models/spot_submission.dart';
import 'package:anshinmichi/models/spot_type.dart';

void main() {
  group('SpotSubmissionRequest JSON round-trip', () {
    test('toJson→fromJsonで元の値を復元できる（オフライン投稿キューでの保存・復元用）', () {
      const request = SpotSubmissionRequest(
        roadSegmentId: 'seg1',
        type: SpotType.tree,
        comment: 'いい木陰です',
      );

      final restored = SpotSubmissionRequest.fromJson(request.toJson());

      expect(restored.roadSegmentId, request.roadSegmentId);
      expect(restored.type, request.type);
      expect(restored.comment, request.comment);
    });

    test('commentがnullでも往復できる', () {
      const request = SpotSubmissionRequest(roadSegmentId: 'seg2', type: SpotType.lowFootTraffic);
      final restored = SpotSubmissionRequest.fromJson(request.toJson());
      expect(restored.comment, null);
      expect(restored.type, SpotType.lowFootTraffic);
    });
  });
}
