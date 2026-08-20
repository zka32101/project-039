// 承認済み投稿を道路区間(roadSegments)のスコアへ反映する集計ロジック。
//
// 【旧実装からの変更】従来は単純な移動平均（(現在値+新規値)/2）だった。これだと
// 「投稿1件目の重みが50%、10件目でも依然50%」のままで、(a) 投稿が積み重なった区間ほど
// 1件の外れ値（悪意・誤操作）に振り回されやすい、(b) 逆に投稿が少ない区間でも
// baseShadowScore（バッチ計算値）が1件の投稿で一気に半分吹き飛ぶ、という2つの問題があった。
// 本実装は「これまでの投稿件数」を`shadeSampleCount`/`brightnessSampleCount`として区間ごとに
// 保持し、件数に応じて新規投稿1件あたりの重みを逓減させる加重移動平均に変更する。
// ただし際限なく重みを下げ続けると、区間の実状が変化した際に反映が遅くなりすぎるため、
// 重みの下限（＝実質的な直近N件分のウィンドウ相当）を`MAX_EFFECTIVE_SAMPLES`で頭打ちにする。

const MAX_EFFECTIVE_SAMPLES = 20; // これ以上は「直近20件相当」の重みで頭打ちにし、環境変化への追従性を保つ

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
      const sampleCount = current.shadeSampleCount ?? 0;
      update.aggregatedShadeScore = computeWeightedAverage(currentShade, delta.shade, sampleCount);
      update.shadeSampleCount = Math.min(sampleCount + 1, MAX_EFFECTIVE_SAMPLES);
    }
    if (delta.brightness !== undefined) {
      const currentBrightness = current.aggregatedBrightnessScore ?? 0;
      const sampleCount = current.brightnessSampleCount ?? 0;
      update.aggregatedBrightnessScore = computeWeightedAverage(currentBrightness, delta.brightness, sampleCount);
      update.brightnessSampleCount = Math.min(sampleCount + 1, MAX_EFFECTIVE_SAMPLES);
    }

    tx.update(ref, update);
  });
}

/**
 * 加重移動平均で新規報告値を織り込む（0〜1にクランプ）。unit testしやすいよう純関数として分離。
 * `sampleCount`件の投稿の積み重ねで得られた`current`に対し、新規1件を
 * 重み`1/(sampleCount+1)`で織り込む（＝算術平均と等価だが、`sampleCount`を
 * `MAX_EFFECTIVE_SAMPLES`で頭打ちにすることで、件数が増えても最低限の反応性を保つ）。
 * @param {number} current 現在の集計値（0..1）
 * @param {number} newValue 新規報告値（0..1）
 * @param {number} sampleCount これまでにcurrentへ織り込まれた投稿件数
 */
export function computeWeightedAverage(current, newValue, sampleCount) {
  const effectiveCount = Math.min(Math.max(0, sampleCount), MAX_EFFECTIVE_SAMPLES);
  const newWeight = 1 / (effectiveCount + 1);
  return Math.min(1, Math.max(0, current * (1 - newWeight) + newValue * newWeight));
}

/** @deprecated 後方互換のため残置。新規コードは`computeWeightedAverage`を使うこと。 */
export function computeMovingAverage(current, newValue) {
  return computeWeightedAverage(current, newValue, 1);
}
