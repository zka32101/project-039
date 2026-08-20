import { test } from 'node:test';
import assert from 'node:assert/strict';
import { exceedsRateLimit, RATE_LIMIT_MAX_SUBMISSIONS } from '../src/rateLimiting.js';

test('exceedsRateLimit: 上限件数以下なら超過しない', () => {
  assert.equal(exceedsRateLimit(0), false);
  assert.equal(exceedsRateLimit(1), false);
  assert.equal(exceedsRateLimit(RATE_LIMIT_MAX_SUBMISSIONS), false);
});

test('exceedsRateLimit: 上限件数を超えたら超過と判定する', () => {
  assert.equal(exceedsRateLimit(RATE_LIMIT_MAX_SUBMISSIONS + 1), true);
  assert.equal(exceedsRateLimit(RATE_LIMIT_MAX_SUBMISSIONS + 100), true);
});
