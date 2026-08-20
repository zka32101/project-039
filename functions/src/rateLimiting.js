// 投稿の不正利用対策（連投・スパム投稿のレート制限）。
//
// 【背景】これまでのモデレーション判定（`moderationLogic.js`）は「地域設定に応じて
// 自動承認するか、承認待ちにするか」のみを見ており、同一ユーザーが短時間に大量投稿しても
// `autoApproveAnonymous`がtrueの地域では即座に全て地図へ反映されてしまっていた
// （荒らし・誤操作による連投で安心スコアが急激に汚染されるリスク）。
// 本モジュールは、投稿者（`submitterId`＝Firebase Authのuid。firestore.rulesで
// `request.auth.uid`との一致を強制済みのため偽装できない）ごとの直近投稿件数を見て、
// 一定件数を超えた場合は`autoApproveAnonymous`の設定に関わらず'pending'（人力承認キュー）に
// 留め置く。誤検知時にも復旧可能な可逆的措置（削除・拒否ではなく保留）にとどめている。

export const RATE_LIMIT_WINDOW_MS = 10 * 60 * 1000; // 直近10分間を見る
export const RATE_LIMIT_MAX_SUBMISSIONS = 5; // このドキュメント自身を含め、直近10分間に5件を超えたら以降は保留

/**
 * 直近`RATE_LIMIT_WINDOW_MS`以内の投稿件数（このドキュメント自身を含む）が、
 * レート制限を超えているかどうかを判定する。unit testしやすいよう純関数として分離している。
 * @param {number} recentSubmissionCount
 */
export function exceedsRateLimit(recentSubmissionCount) {
  return recentSubmissionCount > RATE_LIMIT_MAX_SUBMISSIONS;
}

/**
 * `submitterId`による直近`RATE_LIMIT_WINDOW_MS`以内の投稿件数を、shadeSpots/brightnessSpots
 * 両コレクション横断でカウントする（投稿種別を変えての連投もレート制限の対象にするため）。
 * @param {FirebaseFirestore.Firestore} db
 * @param {string} submitterId
 * @param {Date} now
 * @returns {Promise<number>}
 */
export async function countRecentSubmissions(db, submitterId, now) {
  const sinceDate = new Date(now.getTime() - RATE_LIMIT_WINDOW_MS);
  const [shadeSnapshot, brightnessSnapshot] = await Promise.all([
    db
      .collection('shadeSpots')
      .where('submitterId', '==', submitterId)
      .where('createdAt', '>=', sinceDate)
      .count()
      .get(),
    db
      .collection('brightnessSpots')
      .where('submitterId', '==', submitterId)
      .where('createdAt', '>=', sinceDate)
      .count()
      .get(),
  ]);
  return shadeSnapshot.data().count + brightnessSnapshot.data().count;
}

// ------------------------------------------------------------------
// searchRoute の不正利用対策（大量呼び出しによる安心スコアの機械的な収集を防ぐ）
//
// 【背景】投稿側（上記）にはレート制限があったが、`searchRoute`（Callable Function、
// 誰でも呼べる経路検索API）には呼び出し回数の制限が一切なかった。UIには都市全体を俯瞰する
// 「危険マップ」的な画面は無いが、`searchRoute`を任意の起点・終点で大量に呼び出せば、
// 区間ごとのcomfortScore（人通りが少ない/暗いといった主観投稿も混ざる）を機械的に収集して
// 独自の「人が少ない場所マップ」を作ることが技術的には可能だった。これは本アプリの
// 意図（歩行者自身の安心）とは逆方向の悪用（人が少ない場所を探す用途）に使われうるリスクを
// 増幅する。固定ウィンドウ方式のシンプルなレート制限で呼び出し頻度に上限を設け、
// 組織的・機械的な収集のコストを引き上げる（完全な防止ではなく、抑止・検知しやすくする対策）。
// ------------------------------------------------------------------

export const SEARCH_ROUTE_RATE_LIMIT_WINDOW_MS = 60 * 1000; // 1分間
// 通常利用（初回表示・目的地変更・詳細ルート最適化トグル・リトライ等）では十分な余裕を持たせつつ、
// 短時間の大量呼び出し（スクレイピング）のコストを引き上げる値として設定。
export const SEARCH_ROUTE_RATE_LIMIT_MAX_REQUESTS = 30;

/**
 * 固定ウィンドウ方式のレート制限の状態遷移を判定する純関数。Firestoreアクセスから
 * 分離することでunit testしやすくしている。
 * @param {{windowStartMs: number, count: number} | null} existing 現在保存されているカウンタ状態
 * @param {number} nowMs
 * @param {number} windowMs
 * @param {number} maxRequests
 * @returns {{allow: boolean, nextState: {windowStartMs: number, count: number}}}
 */
export function decideRateLimitTransition(existing, nowMs, windowMs, maxRequests) {
  const isFreshWindow = !existing || nowMs - existing.windowStartMs >= windowMs;
  if (isFreshWindow) {
    return { allow: true, nextState: { windowStartMs: nowMs, count: 1 } };
  }
  if (existing.count >= maxRequests) {
    return { allow: false, nextState: existing }; // 上限到達。カウンタは進めない
  }
  return { allow: true, nextState: { windowStartMs: existing.windowStartMs, count: existing.count + 1 } };
}

/**
 * `key`（呼び出し元を一意に識別する文字列、例: `searchRoute:${uid}`）ごとのレート制限を、
 * Firestoreの`rateLimits/{key}`ドキュメント1件のカウンタで判定・更新する。
 * トランザクションで読み取り→判定→書き込みを原子的に行い、同時リクエストでの
 * カウント漏れ・二重許可を防ぐ。
 * @param {FirebaseFirestore.Firestore} db
 * @param {string} key
 * @param {{windowMs: number, maxRequests: number, now: Date}} options
 * @returns {Promise<boolean>} true=許可, false=レート制限超過
 */
export async function checkAndIncrementRateLimit(db, key, { windowMs, maxRequests, now }) {
  const ref = db.collection('rateLimits').doc(key);
  return db.runTransaction(async (tx) => {
    const snapshot = await tx.get(ref);
    const existing = snapshot.exists ? snapshot.data() : null;
    const { allow, nextState } = decideRateLimitTransition(existing, now.getTime(), windowMs, maxRequests);
    tx.set(ref, nextState);
    return allow;
  });
}
