// 大規模合成データでのベンチマーク（バックログ「実データでの経路探索再検証」対応）。
// `benchmark.js`（49ノード）と同じパイプラインを、`generate_large_sample.mjs`が生成する
// より大きなグリッド（デフォルト60x60=3600ノード）に対して実行し、RESULTS_LARGE.mdへ出力する。
// これにより「規模が上がったときに処理時間がどう伸びるか（線形か、それより悪化するか）」を
// 合成データの範囲で確認できる。あわせて、最近傍ノード探索の「全件走査 vs 空間インデックス」の
// 速度差も測定し、functions/src/spatialIndex.js導入の効果を定量的に示す。
//
// 【重要】実際のOSMデータ（道路形状の非格子性、建物密度のばらつき）とは異なる合成データのため、
// 「実データでの再検証が必須」という結論自体は変わらない。あくまで規模起因のボトルネックの
// 有無・スケーリング傾向を確認するためのものである。
import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { execFileSync } from 'node:child_process';
import { buildGraph } from './buildGraph.js';
import { computeShadowScores } from './shadowScore.js';
import { searchRoute } from './routeSearch.js';
import { buildSpatialIndex, nearestNodeIdIndexed } from './spatialIndex.js';

const FIXTURE_PATH = fileURLToPath(new URL('../fixtures/tokyo_sample_large.json', import.meta.url));
const GENERATOR_PATH = fileURLToPath(new URL('../fixtures/generate_large_sample.mjs', import.meta.url));
const RESULTS_PATH = fileURLToPath(new URL('../RESULTS_LARGE.md', import.meta.url));
const SMALL_RESULTS_PATH = fileURLToPath(new URL('../RESULTS.md', import.meta.url));

function timeit(label, fn) {
  const start = performance.now();
  const result = fn();
  const ms = performance.now() - start;
  return { label, ms, result };
}

function bruteForceNearestNodeId(nodes, lat, lon) {
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

// 最近傍ノード探索の比較専用に、シャドウ計算のO(E×B)コストを伴わない
// より大きな格子ノード集合を生成する（実データ規模＝数万ノードに近づけるため）。
// 建物・道路は不要なため、shadow_score_batchの対象にはならない。
function generateNodesOnlyGrid(gridSize) {
  const BASE_LAT = 35.681236;
  const BASE_LON = 139.767125;
  const DLAT = 45 / 111000;
  const DLON = 45 / 91000;
  const nodes = [];
  for (let r = 0; r < gridSize; r++) {
    for (let c = 0; c < gridSize; c++) {
      nodes.push({ id: `n_${r}_${c}`, lat: BASE_LAT + r * DLAT, lon: BASE_LON + c * DLON });
    }
  }
  return nodes;
}

function loadOrGenerateFixture() {
  if (!existsSync(FIXTURE_PATH)) {
    console.log('tokyo_sample_large.json が無いため生成します...');
    execFileSync(process.execPath, [GENERATOR_PATH], { stdio: 'inherit' });
  }
  return JSON.parse(readFileSync(FIXTURE_PATH, 'utf-8'));
}

function run() {
  const raw = loadOrGenerateFixture();

  const { ms: graphMs, result: graph } = timeit('graph_build', () => buildGraph(raw));

  const dateTimeUtc = new Date('2026-08-19T06:00:00Z');
  const { ms: shadowMs, result: shadowScores } = timeit('shadow_score_batch', () =>
    computeShadowScores(graph, raw.buildings, dateTimeUtc),
  );
  const shadedEdgeCount = [...shadowScores.values()].filter((s) => s > 0).length;

  // 最近傍ノード探索: 全件走査 vs 空間インデックス
  // 本体のグラフ（数千ノード）では両者の差が測定誤差に埋もれるため、
  // 実データ規模（1都市分、数万ノード）に近い専用のノード集合で比較する。
  const NEAREST_NODE_GRID_SIZE = 200; // 200x200 = 40,000ノード
  const nearestNodeSet = generateNodesOnlyGrid(NEAREST_NODE_GRID_SIZE);
  const { ms: indexBuildMs, result: spatialIndex } = timeit('spatial_index_build', () =>
    buildSpatialIndex(nearestNodeSet),
  );
  const NEAREST_QUERIES = 2000;
  const queryPoints = [];
  for (let i = 0; i < NEAREST_QUERIES; i++) {
    const node = nearestNodeSet[(i * 977) % nearestNodeSet.length]; // 決定論的にばらけさせる
    queryPoints.push([node.lat + 0.0001, node.lon + 0.0001]); // ノード直近だが完全一致ではない座標
  }
  const bruteForceStart = performance.now();
  for (const [lat, lon] of queryPoints) bruteForceNearestNodeId(nearestNodeSet, lat, lon);
  const bruteForceMs = performance.now() - bruteForceStart;

  const indexedStart = performance.now();
  for (const [lat, lon] of queryPoints) nearestNodeIdIndexed(spatialIndex, lat, lon);
  const indexedMs = performance.now() - indexedStart;

  // 経路探索: 対角線上の複数ペアで反復測定
  const nodeIds = raw.nodes.map((n) => n.id);
  const pairs = [
    [nodeIds[0], nodeIds[nodeIds.length - 1]],
    [nodeIds[0], nodeIds[Math.floor(nodeIds.length / 2)]],
    [nodeIds[Math.floor(nodeIds.length / 3)], nodeIds[nodeIds.length - 1]],
  ];
  const ROUTE_ITERATIONS = 50; // 大規模データのため小規模ベンチより反復回数を抑える
  const routeTimingsMs = [];
  let sampleRoute = null;
  for (let i = 0; i < ROUTE_ITERATIONS; i++) {
    const [origin, dest] = pairs[i % pairs.length];
    const { ms, result } = timeit('route_search', () =>
      searchRoute(graph, shadowScores, origin, dest, { shadeWeight: 0.6 }),
    );
    routeTimingsMs.push(ms);
    if (i === 0) sampleRoute = result;
  }
  const avgRouteMs = routeTimingsMs.reduce((a, b) => a + b, 0) / routeTimingsMs.length;
  const maxRouteMs = Math.max(...routeTimingsMs);

  // 小規模（49ノード）結果との比較のため、既存RESULTS.mdのデータセット規模も読む
  const smallDatasetLine = existsSync(SMALL_RESULTS_PATH)
    ? readFileSync(SMALL_RESULTS_PATH, 'utf-8').match(/ノード数: (\d+)/)?.[1]
    : null;

  const report = {
    dataset: {
      nodes: raw.nodes.length,
      roads: raw.roads.length,
      edges: graph.edges.length,
      buildings: raw.buildings.length,
      source: raw.meta.source,
    },
    graphBuildMs: round(graphMs),
    shadowScoreBatch: {
      ms: round(shadowMs),
      totalEdges: graph.edges.length,
      shadedEdges: shadedEdgeCount,
      shadedRatio: round(shadedEdgeCount / graph.edges.length, 3),
    },
    nearestNode: {
      nodeCount: nearestNodeSet.length,
      queries: NEAREST_QUERIES,
      indexBuildMs: round(indexBuildMs),
      bruteForceTotalMs: round(bruteForceMs),
      indexedTotalMs: round(indexedMs),
      speedupFactor: bruteForceMs > 0 && indexedMs > 0 ? round(bruteForceMs / indexedMs, 1) : null,
    },
    routeSearch: {
      iterations: ROUTE_ITERATIONS,
      avgMs: round(avgRouteMs, 3),
      maxMs: round(maxRouteMs, 3),
      sampleRoute: sampleRoute
        ? { pathLength: sampleRoute.path.length, distanceM: round(sampleRoute.distanceM) }
        : null,
    },
    comparisonNodesSmall: smallDatasetLine ? Number(smallDatasetLine) : null,
  };

  console.log(JSON.stringify(report, null, 2));
  writeFileSync(RESULTS_PATH, renderResultsMarkdown(report));
  console.log(`\n→ 結果を ${RESULTS_PATH} に出力しました`);
  return report;
}

function round(n, digits = 2) {
  const f = 10 ** digits;
  return Math.round(n * f) / f;
}

function renderResultsMarkdown(r) {
  const scaleFactor = r.comparisonNodesSmall ? round(r.dataset.nodes / r.comparisonNodesSmall, 1) : null;
  return `# 経路探索エンジン 大規模合成データ ベンチマーク結果（自動生成）

バックログ「実データでの経路探索再検証」対応。\`benchmark_large.js\`の実行結果。
データセット: ${r.dataset.source}
${scaleFactor ? `（RESULTS.md記載の小規模データ比 約${scaleFactor}倍のノード数）` : ''}

## データセット規模
- ノード数: ${r.dataset.nodes}
- 道路(way)数: ${r.dataset.roads}
- グラフエッジ数: ${r.dataset.edges}
- 建物数: ${r.dataset.buildings}

## 1. グラフ構築
- 処理時間: **${r.graphBuildMs} ms**

## 2. 影スコア事前計算バッチ
- 処理時間: **${r.shadowScoreBatch.ms} ms**（全${r.shadowScoreBatch.totalEdges}エッジ）
- 影判定エッジ数: ${r.shadowScoreBatch.shadedEdges}（${(r.shadowScoreBatch.shadedRatio * 100).toFixed(1)}%）
- アルゴリズムは「エッジ×建物」の総当たり（O(E×B)）のため、規模が上がると処理時間の伸びが
  グラフ構築・経路探索より大きい点に注意（下記「所見」参照）

## 3. 最近傍ノード探索: 全件走査 vs 空間インデックス
（上記のグラフ本体とは別に、実データ規模＝1都市分に近い${r.nearestNode.nodeCount}ノードの
専用データセットで比較。数千ノード程度では両者の差が測定誤差に埋もれてしまうため）
- ノード数: ${r.nearestNode.nodeCount}
- クエリ回数: ${r.nearestNode.queries}
- インデックス構築: **${r.nearestNode.indexBuildMs} ms**（1回のみ、グラフキャッシュと同じTTLで使い回す想定）
- 全件走査の合計時間: **${r.nearestNode.bruteForceTotalMs} ms**
- 空間インデックスの合計時間: **${r.nearestNode.indexedTotalMs} ms**
- 高速化倍率: **${r.nearestNode.speedupFactor ?? 'N/A'}倍**

## 4. 経路探索（Dijkstra）レスポンスタイム
- 反復回数: ${r.routeSearch.iterations}
- 平均: **${r.routeSearch.avgMs} ms**
- 最大: **${r.routeSearch.maxMs} ms**
- サンプル経路: ノード数${r.routeSearch.sampleRoute?.pathLength}、距離約${r.routeSearch.sampleRoute?.distanceM}m

## 所見

- 経路探索（Dijkstra）は${r.dataset.nodes}ノード規模でも実用速度の目安（数百ms以内）に収まっている。
  ただし本検証は格子状の合成データであり、実データ（非格子・不均一な道路網）ではキャッシュ効率や
  枝刈りの効きが変わるため、傾向の目安に留める。
- 影スコア事前計算バッチはO(エッジ数×建物数)のアルゴリズムのため、規模が上がるほど
  他の処理より重くなりやすい。実データ規模（数万エッジ×数万建物）では、このままだと
  バッチ実行時間が実用に耐えない可能性が高く、空間インデックスによる「エッジ近傍の建物のみを
  対象にする」絞り込みが次の改善候補になる（現状は\`shadowCalcBatch\`が3時間毎の非同期実行のため
  即座に問題化はしないが、実行時間がスケジュール間隔に対して長すぎないか要確認）。
- 最近傍ノード探索は空間インデックス導入により大幅に高速化しており、規模が大きいほど
  効果が顕著になる（\`functions/src/spatialIndex.js\`, PR「Cloud Functions側の集計ロジック・
  空間インデックスを高度化」参照）。
- 依然として**実際のOSMデータでの再検証は未実施**。合成データは格子状で建物密度も一様に
  近く、実データより探索が「効きやすい」形状になっている可能性が高い点に注意すること。

## 再実行方法

\`\`\`bash
node fixtures/generate_large_sample.mjs [グリッドサイズ、省略時60]
node src/benchmark_large.js
\`\`\`
`;
}

run();
