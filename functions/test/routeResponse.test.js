import { test } from 'node:test';
import assert from 'node:assert/strict';
import { buildGraph } from '../src/buildGraph.js';
import { buildSegmentBreakdown } from '../src/routeResponse.js';

test('buildSegmentBreakdown: 経路上の各区間の距離・安心スコアを返す', () => {
  const graph = buildGraph({
    nodes: [
      { id: 'A', lat: 35.0, lon: 139.0 },
      { id: 'B', lat: 35.001, lon: 139.0 },
      { id: 'C', lat: 35.002, lon: 139.0 },
    ],
    roads: [{ id: 'r1', nodeIds: ['A', 'B', 'C'] }],
  });
  graph.edgeById.get('r1_0').shadowScore = 0.8;
  graph.edgeById.get('r1_1').shadowScore = 0.2;

  const segments = buildSegmentBreakdown(graph, ['A', 'B', 'C']);

  assert.equal(segments.length, 2);
  assert.equal(segments[0].comfortScore, 0.8);
  assert.equal(segments[1].comfortScore, 0.2);
  assert.ok(segments[0].distanceM > 0);
});

test('buildSegmentBreakdown: 単一ノードの経路は空配列', () => {
  const graph = buildGraph({
    nodes: [{ id: 'A', lat: 35.0, lon: 139.0 }],
    roads: [],
  });
  assert.deepEqual(buildSegmentBreakdown(graph, ['A']), []);
});
