import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  decideVoteEffect,
  CONFIRM_APPROVE_THRESHOLD,
  REPORT_HOLD_THRESHOLD,
} from '../src/spotVoting.js';

test('decideVoteEffect: confirmはvotesを1増やす', () => {
  const result = decideVoteEffect({ votes: 0, reportCount: 0, status: 'approved' }, 'confirm');
  assert.equal(result.votes, 1);
  assert.equal(result.reportCount, 0);
  assert.equal(result.status, 'approved');
});

test('decideVoteEffect: confirmでvotesが閾値未満なら状態はpendingのまま', () => {
  const result = decideVoteEffect(
    { votes: CONFIRM_APPROVE_THRESHOLD - 2, reportCount: 0, status: 'pending' },
    'confirm',
  );
  assert.equal(result.votes, CONFIRM_APPROVE_THRESHOLD - 1);
  assert.equal(result.status, 'pending');
});

test('decideVoteEffect: confirmでvotesが閾値に達したらpending→approvedへ引き上げる', () => {
  const result = decideVoteEffect(
    { votes: CONFIRM_APPROVE_THRESHOLD - 1, reportCount: 0, status: 'pending' },
    'confirm',
  );
  assert.equal(result.votes, CONFIRM_APPROVE_THRESHOLD);
  assert.equal(result.status, 'approved');
});

test('decideVoteEffect: confirmで既にapprovedの投稿は閾値到達してもstatusは変わらない', () => {
  const result = decideVoteEffect(
    { votes: CONFIRM_APPROVE_THRESHOLD - 1, reportCount: 0, status: 'approved' },
    'confirm',
  );
  assert.equal(result.status, 'approved');
});

test('decideVoteEffect: reportはreportCountを1増やす', () => {
  const result = decideVoteEffect({ votes: 0, reportCount: 0, status: 'approved' }, 'report');
  assert.equal(result.votes, 0);
  assert.equal(result.reportCount, 1);
  assert.equal(result.status, 'approved');
});

test('decideVoteEffect: reportでreportCountが閾値未満なら状態はapprovedのまま', () => {
  const result = decideVoteEffect(
    { votes: 0, reportCount: REPORT_HOLD_THRESHOLD - 2, status: 'approved' },
    'report',
  );
  assert.equal(result.reportCount, REPORT_HOLD_THRESHOLD - 1);
  assert.equal(result.status, 'approved');
});

test('decideVoteEffect: reportでreportCountが閾値に達したらapproved→pendingへ差し戻す', () => {
  const result = decideVoteEffect(
    { votes: 0, reportCount: REPORT_HOLD_THRESHOLD - 1, status: 'approved' },
    'report',
  );
  assert.equal(result.reportCount, REPORT_HOLD_THRESHOLD);
  assert.equal(result.status, 'pending');
});

test('decideVoteEffect: reportで既にpendingの投稿は閾値到達してもstatusは変わらない', () => {
  const result = decideVoteEffect(
    { votes: 0, reportCount: REPORT_HOLD_THRESHOLD - 1, status: 'pending' },
    'report',
  );
  assert.equal(result.status, 'pending');
});

test('decideVoteEffect: 閾値はoptionsで上書きできる', () => {
  const result = decideVoteEffect(
    { votes: 0, reportCount: 0, status: 'pending' },
    'confirm',
    { confirmApproveThreshold: 1 },
  );
  assert.equal(result.status, 'approved');
});

test('decideVoteEffect: 未知のvoteTypeは例外を投げる', () => {
  assert.throws(() => decideVoteEffect({ votes: 0, reportCount: 0, status: 'approved' }, 'like'));
});
