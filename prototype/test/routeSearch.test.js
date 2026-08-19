import { test } from 'node:test';
import assert from 'node:assert/strict';
import { buildGraph } from '../src/buildGraph.js';
import { searchRoute } from '../src/routeSearch.js';

// シンプルな一直線グラフ: A - B - C
function makeLinearGraph() {
  return buildGraph({
    nodes: [
      { id: 'A', lat: 35.0, lon: 139.0 },
      { id: 'B', lat: 35.001, lon: 139.0 },
      { id: 'C', lat: 35.002, lon: 139.0 },
    ],
    roads: [{ id: 'r1', nodeIds: ['A', 'B', 'C'] }],
  });
}

test('searchRoute: 単純な一直線経路を発見できる', () => {
  const graph = makeLinearGraph();
  const result = searchRoute(graph, new Map(), 'A', 'C');
  assert.ok(result);
  assert.deepEqual(result.path, ['A', 'B', 'C']);
});

test('searchRoute: 存在しないノードはnullを返す', () => {
  const graph = makeLinearGraph();
  const result = searchRoute(graph, new Map(), 'A', 'Z');
  assert.equal(result, null);
});

test('searchRoute: shadeWeightが高いほど日陰区間を優先しコストが下がる', () => {
  // A-B-D（日陰なし・遠回り無し） vs 影のある区間のコスト比較
  const graph = buildGraph({
    nodes: [
      { id: 'A', lat: 35.0, lon: 139.0 },
      { id: 'B', lat: 35.001, lon: 139.0 },
    ],
    roads: [{ id: 'r1', nodeIds: ['A', 'B'] }],
  });
  const edgeId = graph.edges[0].id;
  const shaded = new Map([[edgeId, 1]]); // 完全に日陰
  const noShade = new Map([[edgeId, 0]]);

  const shadedResult = searchRoute(graph, shaded, 'A', 'B', { shadeWeight: 0.8 });
  const noShadeResult = searchRoute(graph, noShade, 'A', 'B', { shadeWeight: 0.8 });

  assert.ok(shadedResult.cost < noShadeResult.cost);
});

test('searchRoute: 200回連続実行しても実用速度(平均10ms未満)に収まる（小規模グラフでの目安）', () => {
  const graph = makeLinearGraph();
  const start = performance.now();
  for (let i = 0; i < 200; i++) searchRoute(graph, new Map(), 'A', 'C');
  const avgMs = (performance.now() - start) / 200;
  assert.ok(avgMs < 10, `avg was ${avgMs}ms`);
});
