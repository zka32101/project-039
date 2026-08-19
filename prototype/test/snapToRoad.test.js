import { test } from 'node:test';
import assert from 'node:assert/strict';
import { buildGraph } from '../src/buildGraph.js';
import { snapTraceToRoad } from '../src/snapToRoad.js';

function makeGraph() {
  return buildGraph({
    nodes: [
      { id: 'A', lat: 35.0000, lon: 139.0000 },
      { id: 'B', lat: 35.0010, lon: 139.0000 }, // Aから約111m北
    ],
    roads: [{ id: 'r1', nodeIds: ['A', 'B'] }],
  });
}

test('snapTraceToRoad: 道路にほぼ沿った軌跡は正しい区間にスナップされる', () => {
  const graph = makeGraph();
  const trace = [
    [35.0002, 139.00002],
    [35.0005, 139.00003],
    [35.0008, 139.00001],
  ];
  const result = snapTraceToRoad(trace, graph);
  assert.ok(result);
  assert.equal(result.edgeId, graph.edges[0].id);
});

test('snapTraceToRoad: 道路から極端に離れた軌跡はnullを返す', () => {
  const graph = makeGraph();
  const trace = [
    [35.5, 139.5],
    [35.5, 139.5001],
  ];
  const result = snapTraceToRoad(trace, graph, 30);
  assert.equal(result, null);
});

test('snapTraceToRoad: 空の軌跡はnullを返す', () => {
  const graph = makeGraph();
  assert.equal(snapTraceToRoad([], graph), null);
});
