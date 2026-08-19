// 検証用データ（東京駅周辺を模した合成グリッド、prototype/fixtures/tokyo_sample.json と同一）を
// Firestoreへ投入するシードスクリプト。
//
// 【重要】このセッションはFirebaseプロジェクトへのネットワークアクセスが無いため未実行・未検証。
// ローカルで以下のいずれかの認証情報を用意した上で実行すること:
//   - `GOOGLE_APPLICATION_CREDENTIALS` 環境変数にサービスアカウントキーのパスを設定
//   - `firebase emulators:start` 実行中のエミュレータに対して `FIRESTORE_EMULATOR_HOST=localhost:8080` を設定
//
// 実行方法: `cd functions && npm run seed`
//
// 実データ（実際の1都市分のOSM道路網）投入時は、本スクリプトのロジックはそのまま流用しつつ、
// 入力元を tokyo_sample.json から実際のOverpass API取得結果（正規化済み）に差し替えること。

import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { buildGraph } from '../src/buildGraph.js';
import { computeShadowScores } from '../src/shadowScore.js';

const FIXTURE_PATH = fileURLToPath(new URL('../../prototype/fixtures/tokyo_sample.json', import.meta.url));

async function seed() {
  const raw = JSON.parse(readFileSync(FIXTURE_PATH, 'utf-8'));

  initializeApp();
  const db = getFirestore();

  console.log(`投入データ: ${raw.nodes.length}ノード, ${raw.roads.length}道路, ${raw.buildings.length}建物`);

  // roadNodes
  await commitInChunks(db, raw.nodes, (batch, node) => {
    batch.set(db.collection('roadNodes').doc(node.id), { lat: node.lat, lon: node.lon });
  });

  // roadWays
  await commitInChunks(db, raw.roads, (batch, road) => {
    batch.set(db.collection('roadWays').doc(road.id), { name: road.name ?? null, nodeIds: road.nodeIds });
  });

  // buildings
  await commitInChunks(db, raw.buildings, (batch, building) => {
    batch.set(db.collection('buildings').doc(building.id), {
      heightM: building.heightM,
      centerLat: building.center[0],
      centerLon: building.center[1],
    });
  });

  // roadSegments（グラフ構築＋初期baseShadowScore計算のうえ投入）
  const graph = buildGraph({ nodes: raw.nodes, roads: raw.roads });
  const buildingsForScore = raw.buildings.map((b) => ({ heightM: b.heightM, center: b.center }));
  const shadowScores = computeShadowScores(graph, buildingsForScore, new Date());

  await commitInChunks(db, graph.edges, (batch, edge) => {
    batch.set(db.collection('roadSegments').doc(edge.id), {
      roadId: edge.roadId,
      fromNodeId: edge.from,
      toNodeId: edge.to,
      distanceM: edge.distanceM,
      baseShadowScore: shadowScores.get(edge.id) ?? 0,
      aggregatedShadeScore: 0,
      aggregatedBrightnessScore: 0,
      lastCalculatedAt: new Date(),
    });
  });

  // モデレーション設定の初期値
  await db.collection('config').doc('moderation').set({
    region: 'JP',
    autoApproveAnonymous: true,
    trustScoreThreshold: 0.5,
  });

  console.log('シード完了');
}

async function commitInChunks(db, items, addToBatch, chunkSize = 400) {
  for (let i = 0; i < items.length; i += chunkSize) {
    const batch = db.batch();
    for (const item of items.slice(i, i + chunkSize)) addToBatch(batch, item);
    await batch.commit();
  }
}

seed().catch((err) => {
  console.error('シードに失敗しました:', err);
  process.exitCode = 1;
});
