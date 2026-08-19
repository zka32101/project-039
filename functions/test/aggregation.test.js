import { test } from 'node:test';
import assert from 'node:assert/strict';
import { computeMovingAverage } from '../src/aggregation.js';

test('computeMovingAverage: 現在値と新規値の単純平均を返す', () => {
  assert.equal(computeMovingAverage(0.4, 1), 0.7);
});

test('computeMovingAverage: 結果は0〜1にクランプされる', () => {
  assert.equal(computeMovingAverage(0, 0), 0);
  assert.equal(computeMovingAverage(1, 1), 1);
});
