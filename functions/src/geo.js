// prototype/src/geo.js と同一（技術検証スプリントで速度・妥当性を確認済みのロジックをそのまま本番へ移植）。
// 座標計算の共通ユーティリティ（Haversine距離、度→ラジアン変換等）
const EARTH_RADIUS_M = 6_371_000;

export function toRad(deg) {
  return (deg * Math.PI) / 180;
}

export function toDeg(rad) {
  return (rad * 180) / Math.PI;
}

/** 2点間の距離（メートル） */
export function haversineDistanceM([lat1, lon1], [lat2, lon2]) {
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return EARTH_RADIUS_M * c;
}

/** 2点の中点（単純平均。区間程度の短距離であれば十分な近似） */
export function midpoint([lat1, lon1], [lat2, lon2]) {
  return [(lat1 + lat2) / 2, (lon1 + lon2) / 2];
}

/** 点から線分（2点間）への最短距離（メートル、簡易平面近似） */
export function pointToSegmentDistanceM([plat, plon], [alat, alon], [blat, blon]) {
  // 緯度経度をローカルなメートル平面に投影して計算（短距離前提の近似）
  const latRef = toRad(alat);
  const mPerDegLat = 111_320;
  const mPerDegLon = 111_320 * Math.cos(latRef);

  const px = (plon - alon) * mPerDegLon;
  const py = (plat - alat) * mPerDegLat;
  const bx = (blon - alon) * mPerDegLon;
  const by = (blat - alat) * mPerDegLat;

  const segLenSq = bx * bx + by * by;
  let t = segLenSq === 0 ? 0 : (px * bx + py * by) / segLenSq;
  t = Math.max(0, Math.min(1, t));
  const projX = bx * t;
  const projY = by * t;
  return Math.hypot(px - projX, py - projY);
}
