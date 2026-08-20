// Remote Config → config/moderation Firestoreドキュメントの自動同期。
//
// 【背景】モデレーション設定はこれまで、Flutter側のRemote Config（`moderation_*`キー、
// `firebase_remote_config_service.dart`参照）とCloud Functions側の`config/moderation`
// Firestoreドキュメント（`moderationLogic.js`が読む「唯一の正」）とで二重管理になっており、
// 運営者がRemote Configコンソールで値を変更しても、サーバー側の承認判定には反映されない
// （手動でFirestoreドキュメントも更新する必要があった）という不整合があった。
// 本モジュールは、Admin SDKでRemote Configテンプレートを取得し、`config/moderation`へ
// 反映する変換ロジックを提供する（実際のスケジュール実行は`index.js`の
// `syncModerationConfigFromRemoteConfig`）。

const PARAM_REGION = 'moderation_region';
const PARAM_AUTO_APPROVE_ANONYMOUS = 'moderation_auto_approve_anonymous';
const PARAM_TRUST_SCORE_THRESHOLD = 'moderation_trust_score_threshold';

const FALLBACK = { region: 'JP', autoApproveAnonymous: true, trustScoreThreshold: 0.5 };

/**
 * Remote Configテンプレート（`getRemoteConfig().getTemplate()`の戻り値）から
 * moderation関連パラメータを抽出する。Remote Configの値は常に文字列で保持されるため、
 * ここで型変換する。パラメータ未定義・`useInAppDefault`（明示値未設定）の場合は
 * `FALLBACK`（クライアント側の`setDefaults`と同じ値）を使う。unit testしやすいよう
 * Admin SDK呼び出しから分離した純関数として切り出している。
 * @param {{parameters?: Record<string, {defaultValue?: {value?: string, useInAppDefault?: boolean}}>}} template
 */
export function extractModerationConfigFromTemplate(template) {
  const params = template?.parameters ?? {};

  return {
    region: readStringParam(params[PARAM_REGION], FALLBACK.region),
    autoApproveAnonymous: readBoolParam(params[PARAM_AUTO_APPROVE_ANONYMOUS], FALLBACK.autoApproveAnonymous),
    trustScoreThreshold: readNumberParam(params[PARAM_TRUST_SCORE_THRESHOLD], FALLBACK.trustScoreThreshold),
  };
}

function readRawValue(param) {
  const defaultValue = param?.defaultValue;
  if (!defaultValue || defaultValue.useInAppDefault || typeof defaultValue.value !== 'string') {
    return undefined;
  }
  return defaultValue.value;
}

function readStringParam(param, fallback) {
  return readRawValue(param) ?? fallback;
}

function readBoolParam(param, fallback) {
  const raw = readRawValue(param);
  if (raw === undefined) return fallback;
  return raw === 'true';
}

function readNumberParam(param, fallback) {
  const raw = readRawValue(param);
  if (raw === undefined) return fallback;
  const parsed = Number(raw);
  return Number.isFinite(parsed) ? parsed : fallback;
}
