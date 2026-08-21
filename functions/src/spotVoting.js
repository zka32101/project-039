// 投稿（shadeSpots/brightnessSpots）の相互チェック機能（確認投票＋通報）。
//
// 【背景】`votes`フィールドはドキュメントモデルに存在していたが、増減させるロジック・
// クライアント側の意図説明がどちらも無い未使用フィールドだった。ユーザーからの指示に基づき、
// 以下の2つの意味を持つ相互チェック機構として実装する:
//   (1) 確認投票（confirm）: 「この投稿は正しい」という他ユーザーからの追認。
//       `votes`が閾値に達した時点で、人力承認待ち（'pending'）の投稿を自動承認へ引き上げる
//       （承認前の投稿でも、複数の第三者が現地確認した場合は信頼度が上がるとみなす）。
//   (2) 通報（report）: 「この投稿は不正確・不適切」という指摘。`reportCount`が閾値に達した
//       時点で、承認済み（'approved'）の投稿を人力再審査待ち（'pending'）へ差し戻す。
//
// いずれも「削除」ではなく「承認状態の往復」にとどめている（投稿・コメントの他のレート制限と
// 同じ、誤検知時にも復旧可能な可逆的措置という方針）。
//
// 【既知の制約】通報によって'approved'→'pending'へ差し戻しても、`aggregation.js`が
// 既に道路区間の集計スコアへ反映済みの影響度は自動的には巻き戻さない（過去の集計への
// 遡及的な取り消しは行わない設計。今後の反映を止めることが目的で、遡及訂正は将来課題）。

export const CONFIRM_APPROVE_THRESHOLD = 3; // 人力承認待ちの投稿を確認投票のみで自動承認へ引き上げる閾値
export const REPORT_HOLD_THRESHOLD = 3; // 承認済みの投稿を再審査待ちへ差し戻す通報閾値

export const VOTE_RATE_LIMIT_WINDOW_MS = 10 * 60 * 1000; // 直近10分間
export const VOTE_RATE_LIMIT_MAX_REQUESTS = 10; // コメントの連投レート制限と同じ上限

/**
 * 投票（確認/通報）が投稿の状態に与える影響を判定する純関数。Firestoreアクセスから
 * 分離することでunit testしやすくしている。
 * @param {{votes: number, reportCount: number, status: string}} current
 * @param {'confirm' | 'report'} voteType
 * @param {{confirmApproveThreshold?: number, reportHoldThreshold?: number}} [options]
 * @returns {{votes: number, reportCount: number, status: string}}
 */
export function decideVoteEffect(current, voteType, options = {}) {
  const confirmApproveThreshold = options.confirmApproveThreshold ?? CONFIRM_APPROVE_THRESHOLD;
  const reportHoldThreshold = options.reportHoldThreshold ?? REPORT_HOLD_THRESHOLD;

  if (voteType === 'confirm') {
    const votes = current.votes + 1;
    const status = current.status === 'pending' && votes >= confirmApproveThreshold ? 'approved' : current.status;
    return { votes, reportCount: current.reportCount, status };
  }

  if (voteType === 'report') {
    const reportCount = current.reportCount + 1;
    const status = current.status === 'approved' && reportCount >= reportHoldThreshold ? 'pending' : current.status;
    return { votes: current.votes, reportCount, status };
  }

  throw new Error(`unknown voteType: ${voteType}`);
}
