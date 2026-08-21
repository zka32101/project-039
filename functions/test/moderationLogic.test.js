import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  containsNgWord,
  decideCommentModerationStatus,
  decideInitialStatus,
  loadModerationConfig,
  DEFAULT_NG_WORDS,
} from '../src/moderationLogic.js';

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

test('containsNgWord: 引数で渡した辞書を使う（既定辞書に含まれない語も検知できる）', () => {
  assert.equal(containsNgWord('あほんだら', ['あほんだら']), true);
  assert.equal(containsNgWord('あほんだら'), false); // 既定辞書には含まれない
});

test('containsNgWord: 半角/全角スペース・中黒を挟んだ回避表記も検知する', () => {
  assert.equal(containsNgWord('お前は死 ねばいい'), true);
  assert.equal(containsNgWord('お前は死　ねばいい'), true); // 全角スペース
  assert.equal(containsNgWord('お前は死・ねばいい'), true);
  assert.equal(containsNgWord('お前は死-ねばいい'), true);
});

test('loadModerationConfig: config/moderationドキュメントが無ければ既定辞書を返す', async () => {
  const db = fakeDb(null);
  const config = await loadModerationConfig(db);
  assert.deepEqual(config.ngWords, DEFAULT_NG_WORDS);
});

test('loadModerationConfig: config/moderationドキュメントのngWordsを優先する', async () => {
  const db = fakeDb({ ngWords: ['カスタムNGワード'] });
  const config = await loadModerationConfig(db);
  assert.deepEqual(config.ngWords, ['カスタムNGワード']);
});

test('loadModerationConfig: ngWordsが不正な型（配列以外）・空配列なら既定辞書へフォールバック', async () => {
  assert.deepEqual((await loadModerationConfig(fakeDb({ ngWords: 'not-an-array' }))).ngWords, DEFAULT_NG_WORDS);
  assert.deepEqual((await loadModerationConfig(fakeDb({ ngWords: [] }))).ngWords, DEFAULT_NG_WORDS);
});

/** `db.collection('config').doc('moderation').get()`のみをサポートする最小限のFirestoreスタブ。 */
function fakeDb(moderationDocData) {
  return {
    collection: () => ({
      doc: () => ({
        get: async () => ({
          exists: moderationDocData !== null,
          data: () => moderationDocData,
        }),
      }),
    }),
  };
}

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

test('decideInitialStatus: requiresManualReview=trueなら、autoApproveAnonymous=trueでもpending', () => {
  assert.equal(
    decideInitialStatus({ autoApproveAnonymous: true }, { requiresManualReview: true }),
    'pending',
  );
});

test('decideInitialStatus: requiresManualReview=falseならautoApproveAnonymousの値に従う', () => {
  assert.equal(
    decideInitialStatus({ autoApproveAnonymous: true }, { requiresManualReview: false }),
    'approved',
  );
});
