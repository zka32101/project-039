import { test } from 'node:test';
import assert from 'node:assert/strict';
import { containsNgWord, decideCommentModerationStatus, decideInitialStatus } from '../src/moderationLogic.js';

test('containsNgWord: NGワードを含む場合はtrue', () => {
  assert.equal(containsNgWord('お前は死ねばいいのに'), true);
});

test('containsNgWord: NGワードを含まない場合はfalse', () => {
  assert.equal(containsNgWord('この木陰は涼しくて最高です'), false);
});

test('containsNgWord: 空文字・undefinedはfalse', () => {
  assert.equal(containsNgWord(''), false);
  assert.equal(containsNgWord(undefined), false);
});

test('decideCommentModerationStatus: NGワード含むコメントはrejected', () => {
  assert.equal(decideCommentModerationStatus('クズだな'), 'rejected');
});

test('decideCommentModerationStatus: 通常コメントはapproved', () => {
  assert.equal(decideCommentModerationStatus('助かりました、ありがとう'), 'approved');
});

test('decideInitialStatus: autoApproveAnonymous=trueならapproved', () => {
  assert.equal(decideInitialStatus({ autoApproveAnonymous: true }), 'approved');
});

test('decideInitialStatus: autoApproveAnonymous=falseならpending', () => {
  assert.equal(decideInitialStatus({ autoApproveAnonymous: false }), 'pending');
});
