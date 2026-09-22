import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  decideRetractionEligibility,
  decideDisputeEligibility,
  validateDisputeMessage,
  DISPUTE_MESSAGE_MAX_LENGTH,
} from '../src/spotOwnerActions.js';

test('decideRetractionEligibility: 自分の投稿かつ未取り消しなら許可', () => {
  const result = decideRetractionEligibility({ submitterId: 'u1', status: 'approved' }, 'u1');
  assert.deepEqual(result, { allowed: true });
});

test('decideRetractionEligibility: 他人の投稿は拒否', () => {
  const result = decideRetractionEligibility({ submitterId: 'u1', status: 'approved' }, 'u2');
  assert.deepEqual(result, { allowed: false, reason: 'not-owner' });
});

test('decideRetractionEligibility: すでに取り消し済みは拒否', () => {
  const result = decideRetractionEligibility({ submitterId: 'u1', status: 'retracted' }, 'u1');
  assert.deepEqual(result, { allowed: false, reason: 'already-retracted' });
});

test('decideRetractionEligibility: pending状態でも自分の投稿なら取り消し可能', () => {
  const result = decideRetractionEligibility({ submitterId: 'u1', status: 'pending' }, 'u1');
  assert.deepEqual(result, { allowed: true });
});

test('decideDisputeEligibility: 通報によりpendingかつreportCount>0なら許可', () => {
  const result = decideDisputeEligibility({ submitterId: 'u1', status: 'pending', reportCount: 3 }, 'u1');
  assert.deepEqual(result, { allowed: true });
});

test('decideDisputeEligibility: 他人の投稿は拒否', () => {
  const result = decideDisputeEligibility({ submitterId: 'u1', status: 'pending', reportCount: 3 }, 'u2');
  assert.deepEqual(result, { allowed: false, reason: 'not-owner' });
});

test('decideDisputeEligibility: 新規投稿直後のpending（reportCountなし）は拒否', () => {
  const result = decideDisputeEligibility({ submitterId: 'u1', status: 'pending' }, 'u1');
  assert.deepEqual(result, { allowed: false, reason: 'not-disputable' });
});

test('decideDisputeEligibility: 承認済み（通報されていない）は拒否', () => {
  const result = decideDisputeEligibility({ submitterId: 'u1', status: 'approved', reportCount: 0 }, 'u1');
  assert.deepEqual(result, { allowed: false, reason: 'not-disputable' });
});

test('validateDisputeMessage: 空文字は無効', () => {
  assert.deepEqual(validateDisputeMessage(''), { valid: false, reason: 'empty' });
  assert.deepEqual(validateDisputeMessage('   '), { valid: false, reason: 'empty' });
});

test('validateDisputeMessage: 上限文字数を超えると無効', () => {
  const tooLong = 'あ'.repeat(DISPUTE_MESSAGE_MAX_LENGTH + 1);
  assert.deepEqual(validateDisputeMessage(tooLong), { valid: false, reason: 'too-long' });
});

test('validateDisputeMessage: 通常のメッセージは有効', () => {
  assert.deepEqual(validateDisputeMessage('誤解です。実際には日陰があります。'), { valid: true });
});
