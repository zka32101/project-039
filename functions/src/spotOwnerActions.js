// 投稿者自身が自分の投稿に対して行える操作（取り消し申請・通報への異議申し立て）。
// 「投稿を確認」画面の確認投票／通報（spotVoting.js）が他者からの操作なのに対し、
// こちらは投稿者本人による操作。Cloud Functions（Admin SDK、firestore.rulesの制約を
// 受けない）経由でのみ書き込み可能にすることで、submitterId照合をクライアントに
// 委ねず（偽装防止）サーバー側で行う（`index.js`の`requestRetraction`/`disputeSpotReport`参照）。

export const DISPUTE_MESSAGE_MAX_LENGTH = 500;

/**
 * 投稿の取り消し申請が可能かどうかを判定する（自分の投稿かつ未取り消しであること）。
 * unit testしやすいよう、Firestoreアクセスから分離した純関数として切り出している。
 * @param {{submitterId: string, status: string}} spot
 * @param {string} requesterUid
 * @returns {{allowed: true} | {allowed: false, reason: 'not-owner' | 'already-retracted'}}
 */
export function decideRetractionEligibility(spot, requesterUid) {
  if (spot.submitterId !== requesterUid) return { allowed: false, reason: 'not-owner' };
  if (spot.status === 'retracted') return { allowed: false, reason: 'already-retracted' };
  return { allowed: true };
}

/**
 * 通報への異議申し立てが可能かどうかを判定する（自分の投稿かつ、通報を受けて
 * 人力再審査待ち＝pending かつ reportCount>0 の状態であること）。新規投稿直後の
 * pending（まだ一度も承認されておらず、通報も受けていない）とは区別する。
 * @param {{submitterId: string, status: string, reportCount?: number}} spot
 * @param {string} requesterUid
 * @returns {{allowed: true} | {allowed: false, reason: 'not-owner' | 'not-disputable'}}
 */
export function decideDisputeEligibility(spot, requesterUid) {
  if (spot.submitterId !== requesterUid) return { allowed: false, reason: 'not-owner' };
  if (spot.status !== 'pending' || !(spot.reportCount > 0)) {
    return { allowed: false, reason: 'not-disputable' };
  }
  return { allowed: true };
}

/**
 * 異議申し立てメッセージのバリデーション（空文字・上限超過を弾く）。
 * @param {unknown} message
 * @returns {{valid: true} | {valid: false, reason: 'empty' | 'too-long'}}
 */
export function validateDisputeMessage(message) {
  if (typeof message !== 'string' || message.trim().length === 0) {
    return { valid: false, reason: 'empty' };
  }
  if (message.length > DISPUTE_MESSAGE_MAX_LENGTH) {
    return { valid: false, reason: 'too-long' };
  }
  return { valid: true };
}
