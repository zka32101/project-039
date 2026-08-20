// 建物ジオメトリ×太陽角度から、道路区間（エッジ）ごとの baseShadowScore を事前計算するバッチ。
// 設計書 Step3「入稿・計算パイプライン」の 2〜3 に相当。
//
// 【パフォーマンス】素朴な実装は「全エッジ×全建物」の総当たり（O(E×B)）で、
// prototype/RESULTS_LARGE.mdの計測により、規模が大きいほど他の処理より重くなりやすいことが
// 分かっている（3600ノード規模で約1秒。実データ規模＝数万エッジ×数万建物では実用に耐えない
// 可能性が高いと指摘していた）。本実装は建物群を空間インデックス化し、各エッジについて
// 「理論上その建物の影が到達しうる範囲」の建物のみを候補として絞り込むことで、
// 出力結果を変えずに計算量を削減する。
import { getSunPosition } from './sunPosition.js';
import { haversineDistanceM, midpoint, toRad } from './geo.js';
import { buildSpatialIndex, itemsWithinBoundingBoxIndexed } from './spatialIndex.js';

const METERS_PER_DEG_LAT = 111320;
// 建物のおおよその近接判定半径（フットプリント最大辺の半分相当を簡易的に固定値と仮定）。
// 空間インデックスの絞り込み半径にも使うため、既存の距離判定と同じ値を定数化した。
const BUILDING_RADIUS_M = 20;

/**
 * 指定日時における、各エッジの影スコア(0〜1)を計算する。
 * 1 = 建物の影が完全にかかっている、0 = 日向。
 *
 * アルゴリズム（簡易2D近似。設計書は将来的な高精度化を許容している前提）:
 *  1. 建物の高さと太陽高度から影の長さを算出: shadowLength = height / tan(altitude)
 *  2. 影は太陽と反対方向（azimuth+180）に伸びると仮定
 *  3. エッジ中点が「建物中心から影方向にshadowLength以内、かつ建物の広がり相当の幅」に入るか判定
 *
 * @param {{edges: Array<{id:string, from:string, to:string}>, nodeById: Map}} graph
 * @param {Array<{id:string, heightM:number, center:[number,number]}>} buildings
 * @param {Date} dateTimeUtc
 * @returns {Map<string, number>} edgeId -> shadowScore(0..1)
 */
export function computeShadowScores(graph, buildings, dateTimeUtc) {
  const scores = new Map();
  if (buildings.length === 0) {
    for (const edge of graph.edges) scores.set(edge.id, 0);
    return scores;
  }

  // 太陽位置はエリア内でほぼ一定とみなし、代表点（最初のノード）で1回だけ計算
  // → 設計書の SunPositionCache（時間帯別事前計算）と同じ考え方をエリア単位に適用
  const repNode = graph.nodeById.get(graph.edges[0]?.from);
  const { azimuthDeg, altitudeDeg } = getSunPosition(
    dateTimeUtc,
    repNode?.lat ?? 35.68,
    repNode?.lon ?? 139.76,
  );

  if (altitudeDeg <= 0) {
    // 日没後は「建物影」の概念自体が無意味（別途、夜の明るさスコアで扱う）
    for (const edge of graph.edges) scores.set(edge.id, 0);
    return scores;
  }

  const shadowDirDeg = (azimuthDeg + 180) % 360;

  // 建物群を空間インデックス化し、「最も高い建物が届きうる最大距離」を絞り込み半径として使う
  // （どのエッジについても、実際に影が届く可能性のある建物を漏れなく候補に含めるための上限値）。
  const buildingIndex = buildSpatialIndex(
    buildings.map((b) => ({ id: b.id, lat: b.center[0], lon: b.center[1], building: b })),
  );
  const tallestHeightM = Math.max(...buildings.map((b) => b.heightM));
  const maxShadowLengthM = tallestHeightM / Math.tan(toRad(altitudeDeg));
  const maxSearchRadiusM = maxShadowLengthM + BUILDING_RADIUS_M;
  // 経度方向は緯度が高いほど「1度あたりの距離」が短くなる（= 同じ距離でもより多くの度数が
  // 必要）。cos(lat)<=1のため、緯度換算(METERS_PER_DEG_LAT)より必ず大きくなるこの値を
  // 緯度・経度の両方に使うことで、取りこぼしなく安全側に広めの候補集合を得る。
  const repNodeForRadius = graph.nodeById.get(graph.edges[0]?.from);
  const metersPerDegLonAtArea = METERS_PER_DEG_LAT * Math.cos(toRad(repNodeForRadius?.lat ?? 35.68));
  const searchRadiusDeg = maxSearchRadiusM / Math.max(1, metersPerDegLonAtArea);

  for (const edge of graph.edges) {
    const from = graph.nodeById.get(edge.from);
    const to = graph.nodeById.get(edge.to);
    if (!from || !to) {
      scores.set(edge.id, 0);
      continue;
    }
    const mid = midpoint([from.lat, from.lon], [to.lat, to.lon]);
    let maxScore = 0;

    const candidates = itemsWithinBoundingBoxIndexed(buildingIndex, mid[0], mid[1], searchRadiusDeg);
    for (const { building: b } of candidates) {
      const shadowLengthM = b.heightM / Math.tan(toRad(altitudeDeg));
      const distToCenterM = haversineDistanceM(mid, b.center);
      if (distToCenterM > shadowLengthM + BUILDING_RADIUS_M) continue;

      const bearingToPointDeg = bearingDeg(b.center, mid);
      const angleDiff = angularDifferenceDeg(bearingToPointDeg, shadowDirDeg);
      // 影の広がり角（太陽高度が低いほど影は長く鋭くなるため、許容角度を高度角に応じて絞る）
      const toleranceDeg = Math.max(15, 45 - altitudeDeg * 0.3);
      if (angleDiff <= toleranceDeg) {
        maxScore = Math.max(maxScore, 1);
      }
    }
    scores.set(edge.id, maxScore);
  }

  return scores;
}

function bearingDeg([lat1, lon1], [lat2, lon2]) {
  const y = Math.sin(toRad(lon2 - lon1)) * Math.cos(toRad(lat2));
  const x =
    Math.cos(toRad(lat1)) * Math.sin(toRad(lat2)) -
    Math.sin(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.cos(toRad(lon2 - lon1));
  return (((Math.atan2(y, x) * 180) / Math.PI) + 360) % 360;
}

function angularDifferenceDeg(a, b) {
  const diff = Math.abs(a - b) % 360;
  return diff > 180 ? 360 - diff : diff;
}
