// 大規模フィクスチャ生成スクリプト（バックログ「実データでの経路探索再検証」対応）。
// `generate_sample.mjs`が生成する49ノード（7x7）の合成データは、技術検証スプリント当時
// 「小規模データでの妥当性確認」を目的としたものだったが、README/RESULTS.md記載の通り
// 「実際の1都市規模（数万〜数十万ノード）では処理時間が非線形に増える可能性が高い」という
// 未検証事項が残ったままだった。
// このスクリプトは同じ合成グリッド生成ロジックをスケールアップし、より大きなグリッド
// （デフォルト60x60=3600ノード）を生成することで、少なくとも「規模を上げたときの
// 処理時間の伸び方（線形か、それより悪いか）」を合成データの範囲で検証できるようにする。
// 【重要】これでも実際のOSMデータ（道路の非格子な形状、建物密度のばらつき等）とは異なるため、
// 「実データでの再検証が必須」という結論自体は変わらない。あくまで規模起因のボトルネックの
// 有無を確認するための合成データである。
import { writeFileSync } from 'node:fs';

const GRID_SIZE = Number(process.argv[2]) || 60;

const BASE_LAT = 35.681236;
const BASE_LON = 139.767125;
const DLAT = 45 / 111000;
const DLON = 45 / 91000;

const nodes = [];
const nodeId = (r, c) => `n_${r}_${c}`;
for (let r = 0; r < GRID_SIZE; r++) {
  for (let c = 0; c < GRID_SIZE; c++) {
    nodes.push({ id: nodeId(r, c), lat: BASE_LAT + r * DLAT, lon: BASE_LON + c * DLON });
  }
}

const roads = [];
let roadSeq = 0;
for (let r = 0; r < GRID_SIZE; r++) {
  const nodeIds = [];
  for (let c = 0; c < GRID_SIZE; c++) nodeIds.push(nodeId(r, c));
  roads.push({ id: `way_h_${roadSeq++}`, name: `東西通り${r + 1}丁目`, nodeIds });
}
for (let c = 0; c < GRID_SIZE; c++) {
  const nodeIds = [];
  for (let r = 0; r < GRID_SIZE; r++) nodeIds.push(nodeId(r, c));
  roads.push({ id: `way_v_${roadSeq++}`, name: `南北通り${c + 1}丁目`, nodeIds });
}

const buildings = [];
let buildingSeq = 0;
for (let r = 0; r < GRID_SIZE - 1; r++) {
  for (let c = 0; c < GRID_SIZE - 1; c++) {
    if ((r + c) % 3 === 2) continue;
    const centerLat = BASE_LAT + (r + 0.5) * DLAT;
    const centerLon = BASE_LON + (c + 0.5) * DLON;
    const halfLat = DLAT * 0.28;
    const halfLon = DLON * 0.28;
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
    source: `synthetic-grid-large (${GRID_SIZE}x${GRID_SIZE}、規模起因のボトルネック検証用。Overpass API直取得は不可のため代替)`,
    area: `東京駅周辺を模した合成データ（${GRID_SIZE}x${GRID_SIZE}グリッド、実データではなく規模スケーリング検証用）`,
    generatedAt: 'static-fixture-large-v1',
    gridSize: GRID_SIZE,
  },
  nodes,
  roads,
  buildings,
};

const outPath = new URL('./tokyo_sample_large.json', import.meta.url);
writeFileSync(outPath, JSON.stringify(sample));
console.log(`generated (${GRID_SIZE}x${GRID_SIZE}): ${nodes.length} nodes, ${roads.length} roads, ${buildings.length} buildings -> ${outPath.pathname}`);
