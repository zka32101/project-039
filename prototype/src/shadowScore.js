// 建物ジオメトリ×太陽角度から、道路区間（エッジ）ごとの baseShadowScore を事前計算するバッチ。
// 設計書 Step3「入稿・計算パイプライン」の 2〜3 に相当。
import { getSunPosition } from './sunPosition.js';
import { haversineDistanceM, midpoint, toRad } from './geo.js';

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

  for (const edge of graph.edges) {
    const from = graph.nodeById.get(edge.from);
    const to = graph.nodeById.get(edge.to);
    if (!from || !to) {
      scores.set(edge.id, 0);
      continue;
    }
    const mid = midpoint([from.lat, from.lon], [to.lat, to.lon]);
    let maxScore = 0;

    for (const b of buildings) {
      const shadowLengthM = b.heightM / Math.tan(toRad(altitudeDeg));
      const distToCenterM = haversineDistanceM(mid, b.center);
      // 建物のおおよその半径（フットプリント最大辺の半分相当を簡易的に25mと仮定するのではなく
      // heightMに依存しないよう固定の近接判定半径を使う）
      const buildingRadiusM = 20;
      if (distToCenterM > shadowLengthM + buildingRadiusM) continue;

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
