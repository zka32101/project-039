// functions/src/spatialIndex.js と同一（本番実装で導入した空間インデックスを、
// バックログ「実データでの経路探索再検証」対応でこのプロトタイプ側にも移植し、
// benchmark_large.jsで大規模合成データに対する効果を測定できるようにしている）。
//
// 全件走査が発生し、レイテンシ・課金の両面でスケールしない。
// 本モジュールは、ノード群を緯度経度の格子（グリッド）セルへ分割したインデックスを構築し、
// 近傍セルのみを走査することで最近傍探索を高速化する。

const DEFAULT_CELL_SIZE_DEG = 0.005; // 東京付近で概ね500m四方（探索対象がおおむね徒歩圏内という前提に合わせた粒度）

/**
 * @param {Iterable<{id: string, lat: number, lon: number}>} nodes
 * @param {number} [cellSizeDeg]
 * @returns {{cellSizeDeg: number, cells: Map<string, Array<{id: string, lat: number, lon: number}>>, bbox: {minCx: number, maxCx: number, minCy: number, maxCy: number}}}
 */
export function buildSpatialIndex(nodes, cellSizeDeg = DEFAULT_CELL_SIZE_DEG) {
  const cells = new Map();
  let minCx = Infinity;
  let maxCx = -Infinity;
  let minCy = Infinity;
  let maxCy = -Infinity;

  for (const node of nodes) {
    const cx = Math.floor(node.lon / cellSizeDeg);
    const cy = Math.floor(node.lat / cellSizeDeg);
    const key = `${cx}:${cy}`;
    const bucket = cells.get(key);
    if (bucket) {
      bucket.push(node);
    } else {
      cells.set(key, [node]);
    }
    if (cx < minCx) minCx = cx;
    if (cx > maxCx) maxCx = cx;
    if (cy < minCy) minCy = cy;
    if (cy > maxCy) maxCy = cy;
  }

  return { cellSizeDeg, cells, bbox: { minCx, maxCx, minCy, maxCy } };
}

/**
 * インデックス化されたノード群から(lat, lon)に最も近いノードのidを返す。
 * 中心セルから外側へリング状に走査半径を広げ、十分な候補が見つかり次第打ち切ることで、
 * 「全件走査」を「近傍セルのみの走査」に置き換える。
 * @returns {string | null}
 */
export function nearestNodeIdIndexed(index, lat, lon) {
  const { cellSizeDeg, cells, bbox } = index;
  if (cells.size === 0) return null;

  const cx = Math.floor(lon / cellSizeDeg);
  const cy = Math.floor(lat / cellSizeDeg);

  // クエリ地点がノード分布のバウンディングボックスから大きく離れている場合でも
  // 取りこぼさないよう、「ボックスまでのチェビシェフ距離」＋「ボックス自体の対角リング数」を
  // 安全な探索上限とする（ボックスに到達しさえすれば、内部は最大でこのリング数で覆いきれる）。
  const distToBoxX = Math.max(0, bbox.minCx - cx, cx - bbox.maxCx);
  const distToBoxY = Math.max(0, bbox.minCy - cy, cy - bbox.maxCy);
  const distToBox = Math.max(distToBoxX, distToBoxY);
  const boxSpan = Math.max(bbox.maxCx - bbox.minCx, bbox.maxCy - bbox.minCy);
  const maxRing = distToBox + boxSpan + 1;

  let bestId = null;
  let bestDistSq = Infinity;

  // ring=0(中心セルのみ)から始め、周囲のリングへ広げていく。
  // 候補が見つかっており、かつ現在のリング境界までの最短距離が既知の最良距離を
  // 超えた時点で、それ以上外側のセルは確実により遠いため打ち切ってよい。
  for (let ring = 0; ring <= maxRing; ring++) {
    if (bestId !== null) {
      const ringBoundaryDeg = (ring - 1) * cellSizeDeg;
      if (ringBoundaryDeg > 0 && ringBoundaryDeg * ringBoundaryDeg > bestDistSq) break;
    }
    for (const [gx, gy] of ringOffsets(ring)) {
      const key = `${cx + gx}:${cy + gy}`;
      const bucket = cells.get(key);
      if (!bucket) continue;
      for (const node of bucket) {
        const dLat = node.lat - lat;
        const dLon = node.lon - lon;
        const distSq = dLat * dLat + dLon * dLon;
        if (distSq < bestDistSq) {
          bestDistSq = distSq;
          bestId = node.id;
        }
      }
    }
  }
  return bestId;
}

/**
 * インデックス化された要素のうち、(lat, lon)を中心とした一辺2*radiusDegの正方形の
 * バウンディングボックス内にあるものを候補として返す（円形の厳密な絞り込みではない）。
 * `shadowScore.js`が「エッジ近傍の建物のみ」に絞り込む用途のように、呼び出し側が
 * 候補集合に対して厳密な距離・角度判定を行うことを前提にした緩い（が漏れの無い）フィルタ。
 * @returns {Array<{id: string, lat: number, lon: number}>}
 */
export function itemsWithinBoundingBoxIndexed(index, lat, lon, radiusDeg) {
  const { cellSizeDeg, cells } = index;
  if (cells.size === 0) return [];

  const cx = Math.floor(lon / cellSizeDeg);
  const cy = Math.floor(lat / cellSizeDeg);
  const cellSpan = Math.ceil(radiusDeg / cellSizeDeg);

  const results = [];
  for (let gx = -cellSpan; gx <= cellSpan; gx++) {
    for (let gy = -cellSpan; gy <= cellSpan; gy++) {
      const bucket = cells.get(`${cx + gx}:${cy + gy}`);
      if (bucket) results.push(...bucket);
    }
  }
  return results;
}

function* ringOffsets(ring) {
  if (ring === 0) {
    yield [0, 0];
    return;
  }
  for (let x = -ring; x <= ring; x++) {
    yield [x, -ring];
    yield [x, ring];
  }
  for (let y = -ring + 1; y <= ring - 1; y++) {
    yield [-ring, y];
    yield [ring, y];
  }
}
