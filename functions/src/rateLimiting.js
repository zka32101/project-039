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
