import { test } from 'node:test';
import assert from 'node:assert/strict';
import { extractModerationConfigFromTemplate } from '../src/remoteConfigSync.js';

test('extractModerationConfigFromTemplate: 明示値が設定されたパラメータを型変換して返す', () => {
  const template = {
    parameters: {
      moderation_region: { defaultValue: { value: 'JP' } },
      moderation_auto_approve_anonymous: { defaultValue: { value: 'false' } },
      moderation_trust_score_threshold: { defaultValue: { value: '0.7' } },
    },
  };
  assert.deepEqual(extractModerationConfigFromTemplate(template), {
    region: 'JP',
    autoApproveAnonymous: false,
    trustScoreThreshold: 0.7,
  });
});

test('extractModerationConfigFromTemplate: パラメータ未定義時はフォールバック値を返す', () => {
  assert.deepEqual(extractModerationConfigFromTemplate({ parameters: {} }), {
    region: 'JP',
    autoApproveAnonymous: true,
    trustScoreThreshold: 0.5,
  });
  assert.deepEqual(extractModerationConfigFromTemplate({}), {
    region: 'JP',
    autoApproveAnonymous: true,
    trustScoreThreshold: 0.5,
  });
  assert.deepEqual(extractModerationConfigFromTemplate(undefined), {
    region: 'JP',
    autoApproveAnonymous: true,
    trustScoreThreshold: 0.5,
  });
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
