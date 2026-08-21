import { test } from 'node:test';
import assert from 'node:assert/strict';
import { computeMovingAverage, computeWeightedAverage, computeTrustWeight } from '../src/aggregation.js';

test('computeMovingAverage: 後方互換（sampleCount=1相当の単純平均）を返す', () => {
  assert.equal(computeMovingAverage(0.4, 1), 0.7);
});

test('computeMovingAverage: 結果は0〜1にクランプされる', () => {
  assert.equal(computeMovingAverage(0, 0), 0);
  assert.equal(computeMovingAverage(1, 1), 1);
});

test('computeWeightedAverage: sampleCount=0（初回投稿）は新規値をそのまま採用する', () => {
  assert.equal(computeWeightedAverage(0, 1, 0), 1);
  assert.equal(computeWeightedAverage(0.3, 0.9, 0), 0.9);
});

test('computeWeightedAverage: sampleCountが増えるほど新規値1件あたりの影響は小さくなる', () => {
  const afterFirst = computeWeightedAverage(0.5, 1, 0); // weight=1 → 1.0
  const afterTenth = computeWeightedAverage(0.5, 1, 9); // weight=1/10 → 0.55
  const afterFiftieth = computeWeightedAverage(0.5, 1, 49); // 上限で頭打ち
  assert.ok(afterFirst > afterTenth);
  assert.ok(afterTenth > afterFiftieth || afterTenth === afterFiftieth);
  assert.equal(Math.round(afterTenth * 100), 55);
});

test('computeWeightedAverage: sampleCountはMAX_EFFECTIVE_SAMPLES(20)で頭打ちになる', () => {
  const at20 = computeWeightedAverage(0.5, 1, 20);
  const at1000 = computeWeightedAverage(0.5, 1, 1000);
  assert.equal(at20, at1000);
  // 頭打ち後の重みは 1/21 相当
  assert.equal(Math.round(at20 * 10000), Math.round((0.5 * (20 / 21) + 1 * (1 / 21)) * 10000));
});

test('computeWeightedAverage: 結果は0〜1にクランプされる', () => {
  assert.equal(computeWeightedAverage(0, 0, 5), 0);
  assert.equal(computeWeightedAverage(1, 1, 5), 1);
});

test('computeWeightedAverage: trustWeightを省略すると従来通り(=1)の重みになる', () => {
  assert.equal(computeWeightedAverage(0.5, 1, 9), computeWeightedAverage(0.5, 1, 9, 1));
});

test('computeWeightedAverage: trustWeightが大きいほど新規値の影響が大きくなる', () => {
  const lowTrust = computeWeightedAverage(0.5, 1, 9, 0.7); // 未確認ユーザー相当
  const baseline = computeWeightedAverage(0.5, 1, 9, 1);
  const highTrust = computeWeightedAverage(0.5, 1, 9, 1.5); // 本人確認済み相当
  assert.ok(lowTrust < baseline);
  assert.ok(baseline < highTrust);
});

test('computeWeightedAverage: trustWeightが大きくても結果は0〜1にクランプされる', () => {
  assert.equal(computeWeightedAverage(0.9, 1, 0, 10), 1);
  assert.equal(computeWeightedAverage(0.1, 0, 0, 10), 0);
});

test('computeTrustWeight: 本人確認済みユーザーは匿名ユーザーより重みが大きい', () => {
  const verified = computeTrustWeight({ isVerified: true });
  const anonymous = computeTrustWeight({ isVerified: false });
  const noProfile = computeTrustWeight(null); // usersドキュメントが無い＝未確認の匿名ユーザー
  assert.ok(verified > anonymous);
  assert.equal(anonymous, noProfile);
});

test('computeTrustWeight: 匿名ユーザーの重みは0より大きい（投稿密度を稼ぐ効果を残すため）', () => {
  assert.ok(computeTrustWeight(null) > 0);
  assert.ok(computeTrustWeight({ isVerified: false }) > 0);
});
