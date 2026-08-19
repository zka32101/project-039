// フィクスチャ生成スクリプト（一度実行して tokyo_sample.json を生成する用途）。
// サンドボックス環境からOverpass APIへの実ネットワークアクセスが不可のため、
// 東京駅周辺を模した合成グリッド（道路網＋建物群）を生成し、本番同等のデータ構造で
// パイプライン（グラフ構築・影スコア計算・経路探索）を検証する。
import { writeFileSync } from 'node:fs';

const BASE_LAT = 35.681236;
const BASE_LON = 139.767125;
// 大まかに1マス=約45m四方のグリッド（緯度1度≒111km、経度1度≒91km@東京の緯度）
const DLAT = 45 / 111000;
const DLON = 45 / 91000;
const GRID_SIZE = 7; // 7x7 = 49交差点

const nodes = [];
const nodeId = (r, c) => `n_${r}_${c}`;
for (let r = 0; r < GRID_SIZE; r++) {
  for (let c = 0; c < GRID_SIZE; c++) {
    nodes.push({
      id: nodeId(r, c),
      lat: BASE_LAT + r * DLAT,
      lon: BASE_LON + c * DLON,
    });
  }
}

const roads = [];
let roadSeq = 0;
// 横方向の道路（行ごとに1本の長い道として、隣接ノードを結ぶ）
for (let r = 0; r < GRID_SIZE; r++) {
  const nodeIds = [];
  for (let c = 0; c < GRID_SIZE; c++) nodeIds.push(nodeId(r, c));
  roads.push({ id: `way_h_${roadSeq++}`, name: `東西通り${r + 1}丁目`, nodeIds });
}
// 縦方向の道路
for (let c = 0; c < GRID_SIZE; c++) {
  const nodeIds = [];
  for (let r = 0; r < GRID_SIZE; r++) nodeIds.push(nodeId(r, c));
  roads.push({ id: `way_v_${roadSeq++}`, name: `南北通り${c + 1}丁目`, nodeIds });
}

// 建物：グリッドの各セル（交差点に囲まれた区画）の中心付近に、決定論的な高さで配置。
// levels（階数）から概算高さ = levels * 3m として影計算に利用する。
const buildings = [];
let buildingSeq = 0;
for (let r = 0; r < GRID_SIZE - 1; r++) {
  for (let c = 0; c < GRID_SIZE - 1; c++) {
    // 全区画に建物があるわけではない（道路に面していない区画や公園を模して間引く）
    if ((r + c) % 3 === 2) continue;
    const centerLat = BASE_LAT + (r + 0.5) * DLAT;
    const centerLon = BASE_LON + (c + 0.5) * DLON;
    const halfLat = DLAT * 0.28;
    const halfLon = DLON * 0.28;
    // 決定論的な階数バリエーション（3〜18階）
    const levels = 3 + ((r * 5 + c * 7) % 16);
    buildings.push({
      id: `bldg_${buildingSeq++}`,
      levels,
      heightM: levels * 3,
      footprint: [
        [centerLat - halfLat, centerLon - halfLon],
        [centerLat - halfLat, centerLon + halfLon],
        [centerLat + halfLat, centerLon + halfLon],
        [centerLat + halfLat, centerLon - halfLon],
      ],
      center: [centerLat, centerLon],
    });
  }
}

const sample = {
  meta: {
    source: 'synthetic-grid (Overpass API直取得はサンドボックスのネットワーク制限により不可のため代替)',
    area: '東京駅周辺を模した合成データ（実データ相当の密度・規模で検証用途）',
    generatedAt: 'static-fixture-v1',
    gridSize: GRID_SIZE,
  },
  nodes,
  roads,
  buildings,
};

writeFileSync(new URL('./tokyo_sample.json', import.meta.url), JSON.stringify(sample, null, 2));
console.log(`generated: ${nodes.length} nodes, ${roads.length} roads, ${buildings.length} buildings`);
