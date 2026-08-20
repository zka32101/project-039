import { test } from 'node:test';
import assert from 'node:assert/strict';
import { buildSpatialIndex, nearestNodeIdIndexed } from '../src/spatialIndex.js';

function bruteForceNearest(nodes, lat, lon) {
  let bestId = null;
  let bestDistSq = Infinity;
  for (const node of nodes) {
    const dLat = node.lat - lat;
    const dLon = node.lon - lon;
    const distSq = dLat * dLat + dLon * dLon;
    if (distSq < bestDistSq) {
      bestDistSq = distSq;
      bestId = node.id;
    }
  }
  return bestId;
}

test('nearestNodeIdIndexed: 単一ノードに対しては常にそのノードを返す', () => {
  const nodes = [{ id: 'a', lat: 35.681, lon: 139.767 }];
  const index = buildSpatialIndex(nodes);
  assert.equal(nearestNodeIdIndexed(index, 35.7, 139.8), 'a');
});

test('nearestNodeIdIndexed: 空のインデックスに対してはnullを返す', () => {
  const index = buildSpatialIndex([]);
  assert.equal(nearestNodeIdIndexed(index, 35.7, 139.8), null);
});

test('nearestNodeIdIndexed: 7x7グリッド状のノード群でも全件走査と同じ結果になる', () => {
  const nodes = [];
  for (let i = 0; i < 7; i++) {
    for (let j = 0; j < 7; j++) {
      nodes.push({ id: `n${i}_${j}`, lat: 35.68 + i * 0.001, lon: 139.76 + j * 0.001 });
    }
  }
  const index = buildSpatialIndex(nodes, 0.002); // セル境界をまたぐケースも検証するため粗めのセルサイズにする

  const queries = [
    [35.6805, 139.7605],
    [35.686, 139.766],
    [35.679, 139.759], // グリッド範囲外（境界のリング探索が正しく機能するか）
    [35.6835, 139.7625],
  ];
  for (const [lat, lon] of queries) {
    assert.equal(nearestNodeIdIndexed(index, lat, lon), bruteForceNearest(nodes, lat, lon), `query (${lat},${lon})`);
  }
});

test('nearestNodeIdIndexed: 疎らに分布したノード（隣接セルが空）でも最近傍を正しく見つける', () => {
  const nodes = [
    { id: 'far', lat: 35.6, lon: 139.6 },
    { id: 'near', lat: 35.9, lon: 139.9 },
  ];
  const index = buildSpatialIndex(nodes, 0.005);
  assert.equal(nearestNodeIdIndexed(index, 35.901, 139.901), 'near');
  assert.equal(nearestNodeIdIndexed(index, 35.601, 139.601), 'far');
});
