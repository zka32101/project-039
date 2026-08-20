// お知らせ（announcements/{id}）作成時に送信するFCMメッセージの組み立て。
// トピック購読方式（'announcements'）を採用しており、個々のユーザーの
// デバイストークンをサーバー側で管理する必要が無い（アプリ側は設定画面の
// 「お知らせを受け取る」トグルでこのトピックを購読/解除するだけ）。

export const ANNOUNCEMENTS_TOPIC = 'announcements';

/**
 * @param {{title?: string, body?: string}} data announcementsドキュメントのデータ
 * @returns {{topic: string, notification: {title: string, body: string}}}
 */
export function buildAnnouncementMessage(data) {
  return {
    topic: ANNOUNCEMENTS_TOPIC,
    notification: {
      title: data.title ?? 'あんしんみちからのお知らせ',
      body: data.body ?? '',
    },
  };
}
