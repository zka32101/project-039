// Overpass API から対象地域の道路網・建物データを取得するモジュール。
//
// 【検証環境に関する注記】
// このサンドボックス環境は Overpass API (overpass-api.de) への外向きネットワーク接続が
// プロキシでブロックされており（CONNECT tunnel failed, 403）、実データでの疎通確認は
// 本スプリントでは実施できていない。そのため本番投入前に実環境で下記 fetchRoadsAndBuildings()
// の疎通・レート制限挙動を必ず再検証すること。
//
// 検証パイプライン本体（グラフ構築・影スコア計算・経路探索の速度と精度）は
// fixtures/tokyo_sample.json（実データ相当の密度で生成した合成データ）で代替検証済み。
// データ構造は Overpass Overpass QL の応答を正規化した後の形に合わせてあるため、
// 実データに差し替えても後段のパイプラインはそのまま動作する設計。

const OVERPASS_ENDPOINT = 'https://overpass-api.de/api/interpreter';
const REQUEST_TIMEOUT_MS = 10_000;
const MAX_RETRIES = 3;

/**
 * 指定バウンディングボックス内の道路(highway=*)と建物(building=*)を取得し、
 * 内部形式 { nodes, roads, buildings } に正規化して返す。
 * @param {{south:number, west:number, north:number, east:number}} bbox
 */
export async function fetchRoadsAndBuildings(bbox) {
  const query = buildOverpassQuery(bbox);
  const raw = await queryOverpassWithRetry(query);
  return normalizeOverpassResponse(raw);
}

function buildOverpassQuery({ south, west, north, east }) {
  return `
    [out:json][timeout:25];
    (
      way["highway"](${south},${west},${north},${east});
      way["building"](${south},${west},${north},${east});
    );
    out body;
    >;
    out skel qt;
  `;
}

async function queryOverpassWithRetry(query) {
  let lastError;
  for (let attempt = 1; attempt <= MAX_RETRIES; attempt++) {
    try {
      const controller = new AbortController();
      const timer = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);
      try {
        const res = await fetch(OVERPASS_ENDPOINT, {
          method: 'POST',
          body: `data=${encodeURIComponent(query)}`,
          headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
          signal: controller.signal,
        });
        if (!res.ok) throw new Error(`Overpass HTTP ${res.status}`);
        return await res.json();
      } finally {
        clearTimeout(timer);
      }
    } catch (err) {
      lastError = err;
      // レートリミット・タイムアウトを想定した簡易バックオフ
      await new Promise((r) => setTimeout(r, attempt * 1000));
    }
  }
  throw new Error(`Overpass fetch failed after ${MAX_RETRIES} retries: ${lastError?.message}`);
}

function normalizeOverpassResponse(raw) {
  const nodeById = new Map();
  const roads = [];
  const buildings = [];

  for (const el of raw.elements ?? []) {
    if (el.type === 'node') {
      nodeById.set(el.id, { id: `n_${el.id}`, lat: el.lat, lon: el.lon });
    }
  }

  for (const el of raw.elements ?? []) {
    if (el.type !== 'way') continue;
    const tags = el.tags ?? {};
    if (tags.highway) {
      roads.push({
        id: `way_${el.id}`,
        name: tags.name ?? null,
        nodeIds: (el.nodes ?? []).map((id) => `n_${id}`),
      });
    } else if (tags.building) {
      const footprint = (el.nodes ?? [])
        .map((id) => nodeById.get(id))
        .filter(Boolean)
        .map((n) => [n.lat, n.lon]);
      const levels = Number(tags['building:levels']) || 4; // OSMに無い場合は控えめな既定値
      buildings.push({
        id: `bldg_${el.id}`,
        levels,
        heightM: Number(tags.height) || levels * 3,
        footprint,
        center: centroid(footprint),
      });
    }
  }

  return { nodes: Array.from(nodeById.values()), roads, buildings };
}

function centroid(points) {
  if (points.length === 0) return [0, 0];
  const [sumLat, sumLon] = points.reduce(([la, lo], [lat, lon]) => [la + lat, lo + lon], [0, 0]);
  return [sumLat / points.length, sumLon / points.length];
}
