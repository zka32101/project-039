import { test } from 'node:test';
import assert from 'node:assert/strict';
import { extractModerationConfigFromTemplate } from '../src/remoteConfigSync.js';
import { DEFAULT_NG_WORDS } from '../src/moderationLogic.js';

test('extractModerationConfigFromTemplate: 明示値が設定されたパラメータを型変換して返す', () => {
  const template = {
    parameters: {
      moderation_region: { defaultValue: { value: 'JP' } },
      moderation_auto_approve_anonymous: { defaultValue: { value: 'false' } },
      moderation_trust_score_threshold: { defaultValue: { value: '0.7' } },
      moderation_ng_words: { defaultValue: { value: 'あほ, ばか, 死ね' } },
    },
  };
  assert.deepEqual(extractModerationConfigFromTemplate(template), {
    region: 'JP',
    autoApproveAnonymous: false,
    trustScoreThreshold: 0.7,
    ngWords: ['あほ', 'ばか', '死ね'],
  });
});

test('extractModerationConfigFromTemplate: パラメータ未定義時はフォールバック値を返す', () => {
  assert.deepEqual(extractModerationConfigFromTemplate({ parameters: {} }), {
    region: 'JP',
    autoApproveAnonymous: true,
    trustScoreThreshold: 0.5,
    ngWords: DEFAULT_NG_WORDS,
  });
  assert.deepEqual(extractModerationConfigFromTemplate({}), {
    region: 'JP',
    autoApproveAnonymous: true,
    trustScoreThreshold: 0.5,
    ngWords: DEFAULT_NG_WORDS,
  });
  assert.deepEqual(extractModerationConfigFromTemplate(undefined), {
    region: 'JP',
    autoApproveAnonymous: true,
    trustScoreThreshold: 0.5,
    ngWords: DEFAULT_NG_WORDS,
  });
});

test('extractModerationConfigFromTemplate: ngWordsが空文字列・空要素のみならフォールバック辞書を返す', () => {
  assert.deepEqual(
    extractModerationConfigFromTemplate({ parameters: { moderation_ng_words: { defaultValue: { value: '' } } } })
      .ngWords,
    DEFAULT_NG_WORDS,
  );
  assert.deepEqual(
    extractModerationConfigFromTemplate({ parameters: { moderation_ng_words: { defaultValue: { value: ' , ,  ' } } } })
      .ngWords,
    DEFAULT_NG_WORDS,
  );
});

test('extractModerationConfigFromTemplate: useInAppDefault（明示値未設定）はフォールバック値を返す', () => {
  const template = {
    parameters: {
      moderation_auto_approve_anonymous: { defaultValue: { useInAppDefault: true } },
    },
  };
  assert.equal(extractModerationConfigFromTemplate(template).autoApproveAnonymous, true);
});

test('extractModerationConfigFromTemplate: 数値として不正な値はフォールバック値を返す', () => {
  const template = {
    parameters: {
      moderation_trust_score_threshold: { defaultValue: { value: 'not-a-number' } },
    },
  };
  assert.equal(extractModerationConfigFromTemplate(template).trustScoreThreshold, 0.5);
});
