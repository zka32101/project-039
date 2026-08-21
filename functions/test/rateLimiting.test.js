import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  exceedsRateLimit,
  RATE_LIMIT_MAX_SUBMISSIONS,
  decideRateLimitTransition,
  COMMENT_RATE_LIMIT_WINDOW_MS,
  COMMENT_RATE_LIMIT_MAX_REQUESTS,
} from '../src/rateLimiting.js';

test('exceedsRateLimit: 上限件数以下なら超過しない', () => {
  assert.equal(exceedsRateLimit(0), false);
  assert.equal(exceedsRateLimit(1), false);
  assert.equal(exceedsRateLimit(RATE_LIMIT_MAX_SUBMISSIONS), false);
});

test('exceedsRateLimit: 上限件数を超えたら超過と判定する', () => {
  assert.equal(exceedsRateLimit(RATE_LIMIT_MAX_SUBMISSIONS + 1), true);
  assert.equal(exceedsRateLimit(RATE_LIMIT_MAX_SUBMISSIONS + 100), true);
});

test('decideRateLimitTransition: 初回呼び出し（既存カウンタ無し）は許可し、カウンタを1で初期化する', () => {
  const result = decideRateLimitTransition(null, 1000, 60_000, 30);
  assert.equal(result.allow, true);
  assert.deepEqual(result.nextState, { windowStartMs: 1000, count: 1 });
});

test('decideRateLimitTransition: ウィンドウ内かつ上限未満なら許可し、カウンタを1増やす', () => {
  const existing = { windowStartMs: 1000, count: 5 };
  const result = decideRateLimitTransition(existing, 1000 + 30_000, 60_000, 30);
  assert.equal(result.allow, true);
  assert.deepEqual(result.nextState, { windowStartMs: 1000, count: 6 });
});

test('decideRateLimitTransition: ウィンドウ内で上限に達していれば拒否し、カウンタは変更しない', () => {
  const existing = { windowStartMs: 1000, count: 30 };
  const result = decideRateLimitTransition(existing, 1000 + 30_000, 60_000, 30);
  assert.equal(result.allow, false);
  assert.deepEqual(result.nextState, existing);
});

test('decideRateLimitTransition: ウィンドウを過ぎていれば上限到達後でもリセットして許可する', () => {
  const existing = { windowStartMs: 1000, count: 30 };
  const result = decideRateLimitTransition(existing, 1000 + 60_000, 60_000, 30);
  assert.equal(result.allow, true);
  assert.deepEqual(result.nextState, { windowStartMs: 1000 + 60_000, count: 1 });
});

test('decideRateLimitTransition: ウィンドウ境界ちょうど（差分==windowMs）は新しいウィンドウとして扱う', () => {
  const existing = { windowStartMs: 0, count: 30 };
  const result = decideRateLimitTransition(existing, 60_000, 60_000, 30);
  assert.equal(result.allow, true);
});

test('コメントのレート制限定数: 投稿より軽量な操作として緩めの上限が設定されている', () => {
  assert.equal(COMMENT_RATE_LIMIT_WINDOW_MS, 10 * 60 * 1000);
  assert.ok(COMMENT_RATE_LIMIT_MAX_REQUESTS > RATE_LIMIT_MAX_SUBMISSIONS);
});

test('decideRateLimitTransition: コメントのレート制限設定でも同じ判定ロジックが機能する（上限到達で拒否）', () => {
  const existing = { windowStartMs: 1000, count: COMMENT_RATE_LIMIT_MAX_REQUESTS };
  const result = decideRateLimitTransition(
    existing,
    1000 + 60_000,
    COMMENT_RATE_LIMIT_WINDOW_MS,
    COMMENT_RATE_LIMIT_MAX_REQUESTS,
  );
  assert.equal(result.allow, false);
});
