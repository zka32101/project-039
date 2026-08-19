import { test } from 'node:test';
import assert from 'node:assert/strict';
import { getSunPosition } from '../src/sunPosition.js';

test('getSunPosition: 夏の東京・正午前後は高度角が高い（昼間）', () => {
  const { altitudeDeg } = getSunPosition(new Date('2026-08-19T03:00:00Z'), 35.681236, 139.767125); // 正午JST
  assert.ok(altitudeDeg > 40, `altitude was ${altitudeDeg}`);
});

test('getSunPosition: 深夜は高度角が負（地平線下）', () => {
  const { altitudeDeg } = getSunPosition(new Date('2026-08-19T16:00:00Z'), 35.681236, 139.767125); // 深夜1時JST
  assert.ok(altitudeDeg < 0, `altitude was ${altitudeDeg}`);
});

test('getSunPosition: 方位角は0〜360度の範囲', () => {
  const { azimuthDeg } = getSunPosition(new Date('2026-08-19T06:00:00Z'), 35.681236, 139.767125);
  assert.ok(azimuthDeg >= 0 && azimuthDeg < 360, `azimuth was ${azimuthDeg}`);
});
