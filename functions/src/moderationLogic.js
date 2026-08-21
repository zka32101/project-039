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
    return { region: 'JP', autoApproveAnonymous: true, trustScoreThreshold: 0.5, ngWords: DEFAULT_NG_WORDS };
  }
  const d = doc.data();
  return {
    region: d.region ?? 'JP',
    autoApproveAnonymous: d.autoApproveAnonymous ?? true,
    trustScoreThreshold: d.trustScoreThreshold ?? 0.5,
    // Array.isArray チェックはFirestoreに不正な型（文字列等）が入っていた場合の防御。
    ngWords: Array.isArray(d.ngWords) && d.ngWords.length > 0 ? d.ngWords : DEFAULT_NG_WORDS,
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

// 【本格実装】従来はコード内にハードコードされた最小限の辞書のみだったが、
// 運営者がデプロイ無しで辞書を更新できるよう、Remote Config（`moderation_ng_words`パラメータ、
// `remoteConfigSync.js`参照）→`config/moderation`ドキュメント（`ngWords`フィールド）→
// 本関数、という既存のモデレーション設定と同じ同期経路に載せた。専用のモデレーションAPI
// （Perspective API等）への置き換えは引き続き将来課題（外部サービス連携が必要なため）。
// ドキュメント未同期時・辞書が空の場合のフォールバックとして最小限の初期値は残す。
export const DEFAULT_NG_WORDS = ['死ね', 'クズ', 'バカ野郎'];

// NGワード判定前の正規化: 半角/全角スペース・中黒・ハイフン・アンダースコアを除去してから比較する。
// 「死　ね」「死・ね」のように区切り文字を挟んでNGワードフィルタを回避する典型的な手口を防ぐ
// （文字自体を差し替える高度な回避（例: 伏字・同音異字）までは対応しない。あくまで簡易対策）。
const EVASION_CHARS_PATTERN = /[\s・\-_]/g;

function normalizeForNgWordMatch(text) {
  return text.replace(EVASION_CHARS_PATTERN, '');
}

export function containsNgWord(text, ngWords = DEFAULT_NG_WORDS) {
  if (!text) return false;
  const normalized = normalizeForNgWordMatch(text);
  return ngWords.some((word) => normalized.includes(word));
}

/** コメントのモデレーション判定（NGワードのみ、投稿種別のようなModerationConfig分岐は無し） */
export function decideCommentModerationStatus(text, ngWords = DEFAULT_NG_WORDS) {
  return containsNgWord(text, ngWords) ? 'rejected' : 'approved';
}
