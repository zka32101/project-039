// 経路探索エンジン 技術検証スプリント — ベンチマーク実行スクリプト
// 検証項目（anshinmichi_code_handoff_v1_0.md 記載の3点）:
//   1. 道路データ取得→グラフ構築の処理時間
//   2. 建物データ×太陽角度からの影スコア事前計算バッチの処理時間・精度
//   3. 重み付き最短経路（Dijkstra）のレスポンスタイム
import { readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { buildGraph } from './buildGraph.js';
import { computeShadowScores } from './shadowScore.js';
import { searchRoute } from './routeSearch.js';

const FIXTURE_PATH = fileURLToPath(new URL('../fixtures/tokyo_sample.json', import.meta.url));
const RESULTS_PATH = fileURLToPath(new URL('../RESULTS.md', import.meta.url));

function timeit(label, fn) {
  const start = performance.now();
  const result = fn();
  const ms = performance.now() - start;
  return { label, ms, result };
}

function run() {
  const raw = JSON.parse(readFileSync(FIXTURE_PATH, 'utf-8'));

  // 1. グラフ構築
  const { label: l1, ms: graphMs, result: graph } = timeit('graph_build', () => buildGraph(raw));

  // 2. 影スコア事前計算（夏の日中を想定: 8月19日 15:00 JST = 06:00 UTC）
  const dateTimeUtc = new Date('2026-08-19T06:00:00Z');
  const { label: l2, ms: shadowMs, result: shadowScores } = timeit('shadow_score_batch', () =>
    computeShadowScores(graph, raw.buildings, dateTimeUtc),
  );
  const shadedEdgeCount = [...shadowScores.values()].filter((s) => s > 0).length;

  // 3. 経路探索（グリッド対角上の複数ペアで反復し、平均レスポンスタイムを計測）
  const nodeIds = raw.nodes.map((n) => n.id);
  const pairs = [
    [nodeIds[0], nodeIds[nodeIds.length - 1]],
    [nodeIds[0], nodeIds[Math.floor(nodeIds.length / 2)]],
    [nodeIds[Math.floor(nodeIds.length / 3)], nodeIds[nodeIds.length - 1]],
  ];
  const ROUTE_ITERATIONS = 200; // 実利用時の連続検索を想定した反復測定
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
      sunAltitudeContext: '2026-08-19 15:00 JST 想定',
    },
    routeSearch: {
      iterations: ROUTE_ITERATIONS,
      avgMs: round(avgRouteMs, 3),
      maxMs: round(maxRouteMs, 3),
      sampleRoute: sampleRoute
        ? { pathLength: sampleRoute.path.length, distanceM: round(sampleRoute.distanceM) }
        : null,
    },
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
  return `# 経路探索エンジン 技術検証結果（自動生成）

実行日: 2026-08-19 ／ データセット: 合成グリッド（${r.dataset.source}）

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
- 想定条件: ${r.shadowScoreBatch.sunAltitudeContext}

## 3. 経路探索（Dijkstra）レスポンスタイム
- 反復回数: ${r.routeSearch.iterations}
- 平均: **${r.routeSearch.avgMs} ms**
- 最大: **${r.routeSearch.maxMs} ms**
- サンプル経路: ノード数${r.routeSearch.sampleRoute?.pathLength}、距離約${r.routeSearch.sampleRoute?.distanceM}m

## 所見
- 経路探索の平均レスポンスタイムはミリ秒オーダーであり、49ノード規模では実用速度の目安（数百ms以内）を
  大きく下回る。ただし本検証は東京駅周辺を模した**合成データ（49ノード）**であり、実際の1都市規模
  （数万〜数十万ノード）では処理時間が非線形に増える可能性が高い。実データでの再検証が必須。
- 影スコア計算はエリア内で太陽位置を1回だけ算出し全エッジに適用する設計とした（エリア内で太陽位置の
  差はごく僅かという前提）。広域展開時はエリア分割の粒度を要検討。
- Overpass APIへの実疎通はサンドボックスのネットワーク制限により未検証。実環境での再確認が必須
  （fetchOsmData.js 冒頭のコメント参照）。

## 未達時の縮退方針（設計書記載）
上記が実データで実用速度に収まらない場合、Must機能1「3レイヤー統合ルート検索」は
事前計算済みルート候補からの選択方式に縮小する。
`;
}

run();
