// functions/src配下は prototype/src の検証済みロジックをそのまま移植したもの。
// ここでは「移植が壊れていないか」の最小限のスモークテストのみ行う
// （アルゴリズム自体の網羅的なテストは prototype/test 側にある）。
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { buildGraph } from '../src/buildGraph.js';
import { searchRoute } from '../src/routeSearch.js';

test('buildGraph→searchRoute: 一直線の経路を発見できる', () => {
  const graph = buildGraph({
    nodes: [
      { id: 'A', lat: 35.0, lon: 139.0 },
      { id: 'B', lat: 35.001, lon: 139.0 },
      { id: 'C', lat: 35.002, lon: 139.0 },
    ],
    roads: [{ id: 'r1', nodeIds: ['A', 'B', 'C'] }],
  });

  const result = searchRoute(graph, new Map(), 'A', 'C');
  assert.ok(result);
  assert.deepEqual(result.path, ['A', 'B', 'C']);
});
