import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { buildGraph } from '../src/buildGraph.js';
import { computeShadowScores } from '../src/shadowScore.js';
import { getSunPosition } from '../src/sunPosition.js';
import { haversineDistanceM, midpoint, toRad } from '../src/geo.js';

// computeShadowScores()の空間インデックスによる絞り込みが、素朴な「全エッジ×全建物」の
// 総当たり実装と完全に同じ結果を返すことを検証する（バックログ「集計ロジック・空間インデックスの
// 高度化」対応、影スコア計算版）。ロジック自体は同一で候補集合の絞り込みのみが異なるはずなので、
// 出力が一致しなければ絞り込み半径の計算に取りこぼしがあることを意味する。
function bruteForceShadowScores(graph, buildings, dateTimeUtc) {
  const scores = new Map();
  if (buildings.length === 0) {
    for (const edge of graph.edges) scores.set(edge.id, 0);
    return scores;
  }
  const repNode = graph.nodeById.get(graph.edges[0]?.from);
  const { azimuthDeg, altitudeDeg } = getSunPosition(dateTimeUtc, repNode?.lat ?? 35.68, repNode?.lon ?? 139.76);
  if (altitudeDeg <= 0) {
    for (const edge of graph.edges) scores.set(edge.id, 0);
    return scores;
  }
  const shadowDirDeg = (azimuthDeg + 180) % 360;

  function bearingDeg([lat1, lon1], [lat2, lon2]) {
    const y = Math.sin(toRad(lon2 - lon1)) * Math.cos(toRad(lat2));
    const x =
      Math.cos(toRad(lat1)) * Math.sin(toRad(lat2)) -
      Math.sin(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.cos(toRad(lon2 - lon1));
    return (((Math.atan2(y, x) * 180) / Math.PI) + 360) % 360;
  }
  function angularDifferenceDeg(a, b) {
    const diff = Math.abs(a - b) % 360;
    return diff > 180 ? 360 - diff : diff;
  }

  for (const edge of graph.edges) {
    const from = graph.nodeById.get(edge.from);
    const to = graph.nodeById.get(edge.to);
    if (!from || !to) {
      scores.set(edge.id, 0);
      continue;
    }
    const mid = midpoint([from.lat, from.lon], [to.lat, to.lon]);
    let maxScore = 0;
    for (const b of buildings) {
      const shadowLengthM = b.heightM / Math.tan(toRad(altitudeDeg));
      const distToCenterM = haversineDistanceM(mid, b.center);
      if (distToCenterM > shadowLengthM + 20) continue;
      const bearingToPointDeg = bearingDeg(b.center, mid);
      const angleDiff = angularDifferenceDeg(bearingToPointDeg, shadowDirDeg);
      const toleranceDeg = Math.max(15, 45 - altitudeDeg * 0.3);
      if (angleDiff <= toleranceDeg) maxScore = Math.max(maxScore, 1);
    }
    scores.set(edge.id, maxScore);
  }
  return scores;
}

test('computeShadowScores: 空間インデックス版は全件走査の素朴な実装と完全一致する（tokyo_sample.json）', () => {
  const fixturePath = fileURLToPath(new URL('../fixtures/tokyo_sample.json', import.meta.url));
  const raw = JSON.parse(readFileSync(fixturePath, 'utf-8'));
  const graph = buildGraph(raw);
  const dateTimeUtc = new Date('2026-08-19T06:00:00Z'); // 15:00 JST

  const indexed = computeShadowScores(graph, raw.buildings, dateTimeUtc);
  const bruteForce = bruteForceShadowScores(graph, raw.buildings, dateTimeUtc);

  assert.equal(indexed.size, bruteForce.size);
  for (const [edgeId, score] of bruteForce) {
    assert.equal(indexed.get(edgeId), score, `edge ${edgeId} の結果が一致しない`);
  }
});

test('computeShadowScores: 遠方の高い建物が誤って候補から漏れない（絞り込み半径の境界値）', () => {
  const graph = buildGraph({
    nodes: [
      { id: 'A', lat: 35.0, lon: 139.0 },
      { id: 'B', lat: 35.0002, lon: 139.0 },
    ],
    roads: [{ id: 'r1', nodeIds: ['A', 'B'] }],
  });
  // 低い建物（近い・影短い）と、高い建物（遠い・影が長く届く可能性がある）を混在させる。
  // 絞り込み半径は「最も高い建物」を基準に計算するため、低い建物しか見ていない場合に
  // 起きうる取りこぼしを検出する。
  const buildings = [
    { id: 'short', heightM: 5, center: [35.0001, 139.0005] },
    { id: 'tall', heightM: 200, center: [35.003, 139.003] }, // 数百m離れた高層建物
  ];
  const dateTimeUtc = new Date('2026-08-19T09:00:00Z'); // 太陽高度が低い時間帯（影が伸びやすい）

  const indexed = computeShadowScores(graph, buildings, dateTimeUtc);
  const bruteForce = bruteForceShadowScores(graph, buildings, dateTimeUtc);
  for (const [edgeId, score] of bruteForce) {
    assert.equal(indexed.get(edgeId), score, `edge ${edgeId} の結果が一致しない`);
  }
});
