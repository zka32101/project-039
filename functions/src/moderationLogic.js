// 投稿の自動承認判定＋NGワードフィルタ（設計書「投稿反映：submitSpot() → NGワードフィルタ
// （コメントのみ対象）→ モデレーション判定（ModerationConfigの地域設定に応じ自動承認 or
// 人力承認キューへ）」に対応）。
//
// 【重要】ステータス決定はクライアントを信用せずサーバー側（本ファイル）で行う。
// Firestoreルール(firestore.rules)はクライアントからの新規作成時 status を 'pending' 固定に
// 強制しており、'approved' への遷移はCloud Functions（Admin SDK、ルールの制約を受けない）
// からのみ行われる。

/**
 * 地域別モデレーション設定を読み込む。
 * config/moderation ドキュメントを唯一の正とする。値自体は
 * `syncModerationConfigFromRemoteConfig`（index.js）が1時間おきにRemote Configから
 * 自動反映するため、運営者はRemote Configコンソールを更新するだけでよい
 * （`remoteConfigSync.js`参照）。
 */
export async function loadModerationConfig(db) {
  const doc = await db.collection('config').doc('moderation').get();
  if (!doc.exists) {
    return { region: 'JP', autoApproveAnonymous: true, trustScoreThreshold: 0.5 };
  }
  const d = doc.data();
  return {
    region: d.region ?? 'JP',
    autoApproveAnonymous: d.autoApproveAnonymous ?? true,
    trustScoreThreshold: d.trustScoreThreshold ?? 0.5,
  };
}

/**
 * @param {{autoApproveAnonymous: boolean}} moderationConfig
 * @param {{requiresManualReview?: boolean}} [options] `requiresManualReview: true`の場合、
 *   地域のモデレーション設定に関わらず常に'pending'（人力承認キュー）に留め置く。
 *   「人通りが少ない」等、客観的な観測（日陰・雨よけの有無）と異なり主観的・偏見の
 *   影響を受けやすい投稿種別の荒らし対策として使う（`index.js`の`handleSpotCreated`参照）。
 */
export function decideInitialStatus(moderationConfig, options = {}) {
  if (options.requiresManualReview) return 'pending';
  return moderationConfig.autoApproveAnonymous ? 'approved' : 'pending';
}

// 【プレースホルダー】実運用では専用のモデレーションAPI（Perspective API等）や
// より網羅的な辞書に置き換えること。ここでは検証用途の最小限のNGワードのみ。
const NG_WORDS = ['死ね', 'クズ', 'バカ野郎'];

export function containsNgWord(text) {
  if (!text) return false;
  return NG_WORDS.some((word) => text.includes(word));
}

/** コメントのモデレーション判定（NGワードのみ、投稿種別のようなModerationConfig分岐は無し） */
export function decideCommentModerationStatus(text) {
  return containsNgWord(text) ? 'rejected' : 'approved';
}
