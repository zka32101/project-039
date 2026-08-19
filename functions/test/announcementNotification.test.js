import { test } from 'node:test';
import assert from 'node:assert/strict';
import { buildAnnouncementMessage, ANNOUNCEMENTS_TOPIC } from '../src/announcementNotification.js';

test('buildAnnouncementMessage: title/bodyをそのままnotificationへ詰める', () => {
  const message = buildAnnouncementMessage({ title: '新機能のお知らせ', body: '目的地入力ができるようになりました' });
  assert.equal(message.topic, ANNOUNCEMENTS_TOPIC);
  assert.equal(message.notification.title, '新機能のお知らせ');
  assert.equal(message.notification.body, '目的地入力ができるようになりました');
});

test('buildAnnouncementMessage: titleが無い場合はデフォルト値を使う', () => {
  const message = buildAnnouncementMessage({ body: '本文のみ' });
  assert.equal(message.notification.title, 'あんしんみちからのお知らせ');
});

test('buildAnnouncementMessage: bodyが無い場合は空文字', () => {
  const message = buildAnnouncementMessage({ title: 'タイトルのみ' });
  assert.equal(message.notification.body, '');
});
