// 承認済み投稿を道路区間(roadSegments)のスコアへ反映する集計ロジック。
// 【プレースホルダー】現状は単純な移動平均（(現在値+新規値)/2）。
// 設計書が意図する「重み付け合算」（投稿者の信頼スコア・投稿数での重みづけ等）は
// より精緻なアルゴリズムが必要なため次スプリントで拡張する。

/**
 * @param {FirebaseFirestore.Firestore} db
 * @param {string} roadSegmentId
 * @param {{shade?: number, brightness?: number}} delta 0..1の新規報告値（該当しない方はundefined）
 */
export async function applyApprovedSpotToRoadSegment(db, roadSegmentId, delta) {
  const ref = db.collection('roadSegments').doc(roadSegmentId);

  await db.runTransaction(async (tx) => {
    const doc = await tx.get(ref);
    if (!doc.exists) return; // 参照先の区間が無ければ何もしない（データ不整合はログで検知する運用を想定）

    const current = doc.data();
    const update = { lastCalculatedAt: new Date() };

    if (delta.shade !== undefined) {
      const currentShade = current.aggregatedShadeScore ?? current.baseShadowScore ?? 0;
      update.aggregatedShadeScore = computeMovingAverage(currentShade, delta.shade);
    }
    if (delta.brightness !== undefined) {
      const currentBrightness = current.aggregatedBrightnessScore ?? 0;
      update.aggregatedBrightnessScore = computeMovingAverage(currentBrightness, delta.brightness);
    }

    tx.update(ref, update);
  });
}

/** 単純な移動平均で新規報告値を織り込む（0〜1にクランプ）。unit testしやすいよう純関数として分離。 */
export function computeMovingAverage(current, newValue) {
  return Math.min(1, Math.max(0, (current + newValue) / 2));
}
