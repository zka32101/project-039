import { test } from 'node:test';
import assert from 'node:assert/strict';
import { haversineDistanceM, pointToSegmentDistanceM } from '../src/geo.js';

test('haversineDistanceM: 同一点は距離0', () => {
  assert.equal(haversineDistanceM([35.68, 139.76], [35.68, 139.76]), 0);
});

test('haversineDistanceM: 既知の距離に近い値を返す（東京駅→有楽町駅 約800m）', () => {
  const d = haversineDistanceM([35.681236, 139.767125], [35.675069, 139.763328]);
  assert.ok(d > 600 && d < 1000, `distance was ${d}`);
});

test('pointToSegmentDistanceM: 線分上の点は距離ほぼ0', () => {
  const d = pointToSegmentDistanceM([35.6805, 139.7671], [35.6800, 139.7671], [35.6810, 139.7671]);
  assert.ok(d < 1, `distance was ${d}`);
});

test('pointToSegmentDistanceM: 線分から離れた点は距離>0', () => {
  const d = pointToSegmentDistanceM([35.6900, 139.7671], [35.6800, 139.7671], [35.6810, 139.7671]);
  assert.ok(d > 500, `distance was ${d}`);
});
