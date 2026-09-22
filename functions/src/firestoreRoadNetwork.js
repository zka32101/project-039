// Firestoreの roadNodes / roadWays コレクションから、prototype/app と同じ
// buildGraph()・computeShadowScores()・searchRoute() にそのまま渡せる形へ変換する。
//
// コレクション構成（設計書Step3 RoadSegmentモデルに対応）:
//   roadNodes/{id}    = { lat, lon }
//   roadWays/{id}     = { name, nodeIds: [nodeId, ...] }
//   roadSegments/{id} = { roadId, fromNodeId, toNodeId, distanceM,
//                          baseShadowScore, aggregatedShadeScore, aggregatedBrightnessScore,
//                          lastCalculatedAt }
//     ※ idはbuildGraph()が生成するedge id（`${wayId}_${i}`）と一致させ、
//       shadeSpots/brightnessSpotsの`roadSegmentId`がこのドキュメントIDを指す
//   buildings/{id}    = { heightM, centerLat, centerLon }

/** Firestoreから道路網の生データ（buildGraph入力形式）を取得する */
export async function loadRoadNetworkGeometry(db) {
  const [nodesSnap, waysSnap] = await Promise.all([
    db.collection('roadNodes').get(),
    db.collection('roadWays').get(),
  ]);

  const nodes = nodesSnap.docs.map((doc) => ({
    id: doc.id,
    lat: doc.data().lat,
    lon: doc.data().lon,
  }));

  const roads = waysSnap.docs.map((doc) => ({
    id: doc.id,
    name: doc.data().name ?? null,
    nodeIds: doc.data().nodeIds ?? [],
  }));

  return { nodes, roads };
}

/** Firestoreから建物データ（computeShadowScores入力形式）を取得する */
export async function loadBuildings(db) {
  const snap = await db.collection('buildings').get();
  return snap.docs.map((doc) => ({
    id: doc.id,
    heightM: doc.data().heightM,
    center: [doc.data().centerLat, doc.data().centerLon],
  }));
}

/**
 * 道路区間ごとの現在のスコア（roadSegmentsコレクション）を取得し、
 * グラフのエッジと同じidをキーにしたMapで返す。
 * 経路探索時の「安心スコア」= baseShadowScoreとユーザー投稿集計値の統合に使う。
 */
export async function loadRoadSegmentScores(db) {
  const detailed = await loadRoadSegmentScoreDetails(db);
  const scores = new Map();
  for (const [id, { comfortScore }] of detailed) {
    scores.set(id, comfortScore);
  }
  return scores;
}

/**
 * loadRoadSegmentScores()の内訳版。影スコアと明るさスコアを分離したまま返す。
 * 日中モード（日陰優先）/夜間モード（明るさ優先）の経路探索切り替えに使う
 * （`index.js`の`searchRoute`参照。日中は影を評価軸に、夜間は明るさを評価軸にする）。
 */
export async function loadRoadSegmentScoreDetails(db) {
  const snap = await db.collection('roadSegments').get();
  const scores = new Map();
  for (const doc of snap.docs) {
    const d = doc.data();
    const shade = d.aggregatedShadeScore > 0 ? d.aggregatedShadeScore : (d.baseShadowScore ?? 0);
    const brightness = d.aggregatedBrightnessScore ?? 0;
    // RoadSegment.comfortScore（Flutter側）と同じ定義: 影と明るさの単純平均
    const comfortScore = Math.min(1, Math.max(0, (shade + brightness) / 2));
    scores.set(doc.id, { shade, brightness, comfortScore });
  }
  return scores;
}
