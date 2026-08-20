import { test } from 'node:test';
import assert from 'node:assert/strict';
import { computeMovingAverage, computeWeightedAverage } from '../src/aggregation.js';

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
