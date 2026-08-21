// あんしんみち Cloud Functions（設計書 functions/ ディレクトリに対応）
//
// 【重要な注記】このセッションはFirebase CLI・実プロジェクトへのネットワークアクセスが無いため、
// `firebase emulators:start`・`firebase deploy`のいずれも実行できておらず、本ファイル一式は
// レビューベースでの実装に留まる。ローカル環境で必ず以下を確認すること:
//   1. `cd functions && npm install`
//   2. `firebase emulators:start --only functions,firestore` でのローカル動作確認
//   3. `seed/seedRoadNetwork.js` でのFirestoreへの検証用データ投入（後述）
//   4. 実データ規模（1都市分、数万〜数十万エッジ）でのsearchRoute/shadowCalcBatchの
//      レスポンスタイム再測定（prototype/RESULTS.mdは49ノードの合成データでの結果に過ぎない）

import { initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';
import { getAuth } from 'firebase-admin/auth';
import { getRemoteConfig } from 'firebase-admin/remote-config';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { onDocumentCreated, onDocumentUpdated } from 'firebase-functions/v2/firestore';

import { buildGraph } from './src/buildGraph.js';
import { computeShadowScores } from './src/shadowScore.js';
import { searchRoute as searchRouteEngine } from './src/routeSearch.js';
import { loadRoadNetworkGeometry, loadBuildings, loadRoadSegmentScores } from './src/firestoreRoadNetwork.js';
import { loadModerationConfig, decideInitialStatus, decideCommentModerationStatus } from './src/moderationLogic.js';
import {
  exceedsRateLimit,
  countRecentSubmissions,
  checkAndIncrementRateLimit,
  SEARCH_ROUTE_RATE_LIMIT_WINDOW_MS,
  SEARCH_ROUTE_RATE_LIMIT_MAX_REQUESTS,
} from './src/rateLimiting.js';
import { applyApprovedSpotToRoadSegment, computeTrustWeight } from './src/aggregation.js';
import { buildSpatialIndex, nearestNodeIdIndexed } from './src/spatialIndex.js';
import { extractModerationConfigFromTemplate } from './src/remoteConfigSync.js';
import { buildSegmentBreakdown } from './src/routeResponse.js';
import { buildAnnouncementMessage } from './src/announcementNotification.js';

initializeApp();
const db = getFirestore();

// ------------------------------------------------------------------
// routeSearch: 経路探索（Callable Function）
// クライアント（Flutter）の RemoteRouteSearchService から呼び出される。
// 設計書「経路探索・影計算はサーバー側（Cloud Functions）で行う」を実現する本体。
// ------------------------------------------------------------------
let _graphCache = null; // ウォームインスタンス間の簡易キャッシュ（TTLはconst参照）
const GRAPH_CACHE_TTL_MS = 5 * 60 * 1000;

/**
 * グラフ・空間インデックス・区間スコア（roadSegments）をまとめてキャッシュする。
 *
 * 【開発側リソース消費対策】以前は`roadSegments`全件スキャン（`loadRoadSegmentScores`）を
 * `searchRoute`の呼び出しのたびに毎回実行していた。呼び出し側にレート制限を設けても、
 * 許可された呼び出し1回ごとにFirestoreの全件読み取りが発生する構造自体は変わらず、
 * 実データ規模（数万件のroadSegments）では呼び出し回数に比例してFirestore読み取り課金・
 * レイテンシが増大する。グラフ本体と同じTTL（5分）でスコアもまとめてキャッシュすることで、
 * ウォームインスタンスが生きている間は「5分に1回の全件読み取り」に抑える
 * （引き換えに、承認直後の投稿が経路探索へ反映されるまで最大5分のラグが生じる。
 * グラフ本体のキャッシュで既に許容していたラグと同じ性質のトレードオフ）。
 */
async function loadCachedGraph() {
  const now = Date.now();
  if (_graphCache && now - _graphCache.loadedAt < GRAPH_CACHE_TTL_MS) {
    return _graphCache;
  }
  const { nodes, roads } = await loadRoadNetworkGeometry(db);
  const graph = buildGraph({ nodes, roads });
  // 最近傍ノード探索を全件走査からグリッド走査へ置き換えるための空間インデックス。
  // グラフと同じTTLでキャッシュし、実データ規模でもリクエストごとの再構築を避ける。
  const spatialIndex = buildSpatialIndex(graph.nodeById.values());

  const scores = await loadRoadSegmentScores(db);
  for (const edge of graph.edges) {
    edge.shadowScore = scores.get(edge.id) ?? 0;
  }
  // computeShadowScores()による自動計算のフォールバックは、roadSegmentsに
  // baseShadowScoreが未投入の場合のみ使う（通常はshadowCalcBatchが事前計算済みの想定）
  if (scores.size === 0) {
    const buildings = await loadBuildings(db);
    const shadowScores = computeShadowScores(graph, buildings, new Date());
    for (const edge of graph.edges) edge.shadowScore = shadowScores.get(edge.id) ?? 0;
  }

  _graphCache = { graph, spatialIndex, loadedAt: now };
  return _graphCache;
}

export const searchRoute = onCall(async (request) => {
  // 匿名認証済みであることを必須にする（他のCloud Functionsと同じ前提）。加えて、
  // request.auth.uidをレート制限のキーにすることで、大量呼び出しによるcomfortScoreの
  // 機械的な収集（`rateLimiting.js`冒頭のコメント参照）のコストを引き上げる。
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'サインインが必要です');
  }
  const allowed = await checkAndIncrementRateLimit(db, `searchRoute:${request.auth.uid}`, {
    windowMs: SEARCH_ROUTE_RATE_LIMIT_WINDOW_MS,
    maxRequests: SEARCH_ROUTE_RATE_LIMIT_MAX_REQUESTS,
    now: new Date(),
  });
  if (!allowed) {
    throw new HttpsError('resource-exhausted', '短時間に検索が集中しています。しばらく待ってから再度お試しください');
  }

  const { originLat, originLon, destLat, destLon, shadeWeight } = request.data ?? {};
  if ([originLat, originLon, destLat, destLon].some((v) => typeof v !== 'number')) {
    throw new HttpsError('invalid-argument', 'originLat/originLon/destLat/destLonは数値で指定してください');
  }

  // graph.edges[].shadowScoreはloadCachedGraph()内でキャッシュ済みのroadSegmentsスコアが
  // 反映されている（上記コメント参照。呼び出しのたびに全件再読み込みはしない）。
  const { graph, spatialIndex } = await loadCachedGraph();
  if (graph.nodeById.size === 0) {
    throw new HttpsError('failed-precondition', '道路網データが投入されていません（seed未実施の可能性）');
  }

  const originId = nearestNodeIdIndexed(spatialIndex, originLat, originLon);
  const destId = nearestNodeIdIndexed(spatialIndex, destLat, destLon);
  const result = searchRouteEngine(graph, new Map(graph.edges.map((e) => [e.id, e.shadowScore])), originId, destId, {
    shadeWeight: shadeWeight ?? 0.6,
  });

  if (!result) {
    throw new HttpsError('not-found', '指定地点間の経路が見つかりませんでした');
  }

  return {
    path: result.path,
    distanceM: result.distanceM,
    cost: result.cost,
    nodes: result.path.map((id) => {
      const n = graph.nodeById.get(id);
      return { id, lat: n.lat, lon: n.lon };
    }),
    // クライアント（SchematicMapView）が区間ごとの色分け表示をできるよう、
    // 経路上の各区間の距離・安心スコアを併せて返す
    segments: buildSegmentBreakdown(graph, result.path),
  };
});

// ------------------------------------------------------------------
// shadowCalcBatch: 建物×太陽角度の事前計算バッチ（スケジュール実行）
// 設計書「建物データ×太陽角度→道路区間ごとのbaseShadowScoreをバッチ計算」に対応。
// ------------------------------------------------------------------
export const shadowCalcBatch = onSchedule('every 3 hours', async () => {
  const { nodes, roads } = await loadRoadNetworkGeometry(db);
  const graph = buildGraph({ nodes, roads });
  const buildings = await loadBuildings(db);
  const scores = computeShadowScores(graph, buildings, new Date());

  // Firestoreのバッチ書き込み上限(500)を考慮してチャンク分割する
  const edges = graph.edges;
  const CHUNK_SIZE = 400;
  for (let i = 0; i < edges.length; i += CHUNK_SIZE) {
    const batch = db.batch();
    for (const edge of edges.slice(i, i + CHUNK_SIZE)) {
      batch.set(
        db.collection('roadSegments').doc(edge.id),
        {
          roadId: edge.roadId,
          fromNodeId: edge.from,
          toNodeId: edge.to,
          distanceM: edge.distanceM,
          baseShadowScore: scores.get(edge.id) ?? 0,
          lastCalculatedAt: new Date(),
        },
        { merge: true }, // aggregatedShadeScore/aggregatedBrightnessScoreは上書きしない
      );
    }
    await batch.commit();
  }
});

// ------------------------------------------------------------------
// syncModerationConfigFromRemoteConfig: Remote Config → config/moderation の自動同期
// 設計書の課題「モデレーション設定がRemote Config（アプリ表示・案内用）とFirestore
// （サーバー側の実際の承認判定、`moderationLogic.js`参照）とで二重管理になっている」を解消する。
// 運営者はRemote Configコンソールで`moderation_*`パラメータを更新するだけでよく、
// このバッチが1時間おきに`config/moderation`へ反映する（クライアント側の
// `minimumFetchInterval`も1時間のため、同程度の追従速度になる）。
// ------------------------------------------------------------------
export const syncModerationConfigFromRemoteConfig = onSchedule('every 1 hours', async () => {
  const template = await getRemoteConfig().getTemplate();
  const config = extractModerationConfigFromTemplate(template);
  await db.collection('config').doc('moderation').set(
    { ...config, syncedFromRemoteConfigAt: new Date() },
    { merge: true },
  );
});

// ------------------------------------------------------------------
// moderation: 投稿の承認/自動反映判定
// 設計書「投稿反映：submitSpot() → NGワードフィルタ（コメントのみ対象）→
// モデレーション判定（ModerationConfigの地域設定に応じ自動承認 or 人力承認キューへ）」に対応。
// クライアントは常にstatus:'pending'で作成し（firestore.rulesで強制）、
// 実際の承認可否はここで判定する。
//
// 投稿の不正利用対策（連投・スパム投稿のレート制限）: 自動承認対象と判定された場合でも、
// 同一投稿者（submitterId、firestore.rulesでrequest.auth.uidとの一致を強制済み）が
// 直近RATE_LIMIT_WINDOW_MS以内にRATE_LIMIT_MAX_SUBMISSIONS件を超えて投稿していれば、
// 自動承認をスキップして'pending'（人力承認キュー）に留め置く（`rateLimiting.js`参照）。
//
// 「人通りが少ない」（brightnessSpots, reasonType: 'low_foot_traffic'）は、日陰・雨よけの
// 有無のような客観的な観測と異なり、投稿者の主観や偏見の影響を受けやすい（特定エリア・
// 属性への偏った印象の助長・荒らしのリスク）ため、地域のモデレーション設定に関わらず
// 常に人力承認を必須とする（`decideInitialStatus`の`requiresManualReview`参照）。
//
// 投稿者の信頼スコアでの重みづけ: 集計（`applyApprovedSpotToRoadSegment`）への反映度合いを
// `users/{submitterId}.isVerified`に応じて変える（`aggregation.js`の`computeTrustWeight`参照）。
// 承認可否そのもの（自動承認 or 人力承認キュー）は変えず、承認された後の「1件あたりの
// スコアへの影響度」だけを調整する（未確認ユーザーの投稿も歓迎して密度を稼ぐ、という
// ソフトローンチ方針＝ModerationConfig.autoApproveAnonymousの意図と両立させるため）。
// ------------------------------------------------------------------
async function loadTrustWeight(submitterId) {
  const doc = await db.collection('users').doc(submitterId).get();
  return computeTrustWeight(doc.exists ? doc.data() : null);
}

async function handleSpotCreated(snapshot, spotKind) {
  const data = snapshot.data();
  const moderationConfig = await loadModerationConfig(db);
  const requiresManualReview = spotKind === 'brightness' && data.reasonType === 'low_foot_traffic';
  let status = decideInitialStatus(moderationConfig, { requiresManualReview });

  if (status === 'approved') {
    const recentCount = await countRecentSubmissions(db, data.submitterId, new Date());
    if (exceedsRateLimit(recentCount)) {
      status = 'pending'; // レート制限超過。人力承認キューへ留め置く（自動承認しない）
    }
  }

  if (status === 'approved') {
    await snapshot.ref.update({ status: 'approved' });
    const trustWeight = await loadTrustWeight(data.submitterId);
    await applyApprovedSpotToRoadSegment(
      db,
      data.roadSegmentId,
      spotKind === 'brightness' ? { brightness: 0 } : { shade: 1 },
      trustWeight,
    );
  }
  // status === 'pending' の場合はクライアントが設定した値のまま（人力承認キューで後日処理）
}

export const onShadeSpotCreated = onDocumentCreated('shadeSpots/{spotId}', async (event) => {
  await handleSpotCreated(event.data, 'shade');
});

export const onBrightnessSpotCreated = onDocumentCreated('brightnessSpots/{spotId}', async (event) => {
  await handleSpotCreated(event.data, 'brightness');
});

// 人力承認（管理コンソール等でstatusをpending→approvedへ更新した場合）でも
// 同じ集計ロジックを適用する
async function handleSpotApproved(change, spotKind) {
  const before = change.before.data();
  const after = change.after.data();
  if (before.status === after.status || after.status !== 'approved') return;

  const trustWeight = await loadTrustWeight(after.submitterId);
  await applyApprovedSpotToRoadSegment(
    db,
    after.roadSegmentId,
    spotKind === 'brightness' ? { brightness: 0 } : { shade: 1 },
    trustWeight,
  );
}

export const onShadeSpotApproved = onDocumentUpdated('shadeSpots/{spotId}', async (event) => {
  await handleSpotApproved(event.data, 'shade');
});

export const onBrightnessSpotApproved = onDocumentUpdated('brightnessSpots/{spotId}', async (event) => {
  await handleSpotApproved(event.data, 'brightness');
});

// コメントのモデレーション（NGワードフィルタのみ。本人確認要件はfirestore.rulesの
// isVerifiedUser()チェックで担保する）
export const onSpotCommentCreated = onDocumentCreated('spotComments/{commentId}', async (event) => {
  const data = event.data.data();
  const status = decideCommentModerationStatus(data.text);
  await event.data.ref.update({ moderationStatus: status });
});

// ------------------------------------------------------------------
// syncVerificationStatus: 本人確認（電話番号認証）の結果をFirestore＋Custom Claimへ反映
// クライアントは`users/{uid}`へ直接書き込めない（firestore.rules参照）。
// Firebase Authが発行するID Tokenの`phone_number`クレーム（電話番号クレデンシャルを
// リンクした本人のみ持つ）をサーバー側で検証してから書き込むことで、
// 自己申告による本人確認済み偽装を防ぐ。
//
// isVerifiedはFirestore(`users/{uid}.isVerified`、UI表示・プロフィール取得用)に加えて
// Auth Custom Claim（`request.auth.token.isVerified`）としても設定する。
// firestore.rulesの`isVerifiedUser()`はCustom Claimのみを参照するため、`spotComments`の
// create許可判定にFirestoreの`get()`（追加課金・レイテンシの原因になる）が不要になる。
// 【重要】Custom Claimはトークン発行時点でのスナップショットのため、付与後にクライアントが
// `getIdToken(true)`で強制リフレッシュするまで反映されない（`firebase_verification_service.dart`参照）。
// ------------------------------------------------------------------
export const syncVerificationStatus = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'サインインが必要です');
  }
  const phoneNumber = request.auth.token.phone_number;
  if (!phoneNumber) {
    throw new HttpsError(
      'failed-precondition',
      '電話番号クレデンシャルがリンクされていません。先にPhoneAuthCredentialをlinkWithCredentialしてください',
    );
  }
  const uid = request.auth.uid;

  await db.collection('users').doc(uid).set(
    {
      isVerified: true,
      verificationMethod: 'phone',
      phoneNumber,
      updatedAt: new Date(),
    },
    { merge: true },
  );

  // 既存クレームを消さないようマージしてから設定する
  const existingUser = await getAuth().getUser(uid);
  await getAuth().setCustomUserClaims(uid, {
    ...existingUser.customClaims,
    isVerified: true,
  });

  return { isVerified: true, verificationMethod: 'phone' };
});

// ------------------------------------------------------------------
// onAnnouncementCreated: お知らせ機能（設計書Step7「Cloud Functions + Firestore統一実装」）
// announcementsドキュメント作成をトリガーに、'announcements'トピック購読者へFCM配信する。
// ドキュメント自体はクライアントから作成不可（firestore.rules参照）。運営が管理コンソール等から作成する想定。
// ------------------------------------------------------------------
export const onAnnouncementCreated = onDocumentCreated('announcements/{announcementId}', async (event) => {
  const data = event.data.data();
  await getMessaging().send(buildAnnouncementMessage(data));
});
