import { test } from 'node:test';
import assert from 'node:assert/strict';
import { buildGraph } from '../src/buildGraph.js';
import { computeShadowScores } from '../src/shadowScore.js';

test('computeShadowScores: 建物が無ければ全エッジのスコアは0', () => {
  const graph = buildGraph({
    nodes: [
      { id: 'A', lat: 35.0, lon: 139.0 },
      { id: 'B', lat: 35.001, lon: 139.0 },
    ],
    roads: [{ id: 'r1', nodeIds: ['A', 'B'] }],
  });
  const scores = computeShadowScores(graph, [], new Date('2026-08-19T06:00:00Z'));
  assert.equal(scores.get(graph.edges[0].id), 0);
});

test('computeShadowScores: 太陽が地平線下（深夜）なら全エッジのスコアは0', () => {
  const graph = buildGraph({
    nodes: [
      { id: 'A', lat: 35.0, lon: 139.0 },
      { id: 'B', lat: 35.001, lon: 139.0 },
    ],
    roads: [{ id: 'r1', nodeIds: ['A', 'B'] }],
  });
  const buildings = [{ id: 'b1', heightM: 30, center: [35.0005, 139.0002] }];
  const scores = computeShadowScores(graph, buildings, new Date('2026-08-19T16:00:00Z')); // 深夜1時JST
  assert.equal(scores.get(graph.edges[0].id), 0);
});

test('computeShadowScores: スコアは常に0または1の範囲', () => {
  const graph = buildGraph({
    nodes: [
      { id: 'A', lat: 35.0, lon: 139.0 },
      { id: 'B', lat: 35.001, lon: 139.0 },
    ],
    roads: [{ id: 'r1', nodeIds: ['A', 'B'] }],
  });
  const buildings = [{ id: 'b1', heightM: 30, center: [35.0005, 139.0002] }];
  const scores = computeShadowScores(graph, buildings, new Date('2026-08-19T06:00:00Z'));
  for (const s of scores.values()) assert.ok(s === 0 || s === 1);
});
