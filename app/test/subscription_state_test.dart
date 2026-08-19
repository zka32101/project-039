import 'package:flutter_test/flutter_test.dart';
import 'package:anshinmichi/models/subscription_state.dart';

void main() {
  test('SubscriptionState.free はプレミアムではない', () {
    expect(SubscriptionState.free.isPremium, isFalse);
  });

  test('SubscriptionTier.premium は isPremium が true', () {
    const state = SubscriptionState(tier: SubscriptionTier.premium);
    expect(state.isPremium, isTrue);
  });
}
