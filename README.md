# project-039 — あんしんみち

影・雨よけ・夜の明るさをユーザーが「塗る」投稿で地図化し、経路探索へ統合する実用ユーティリティアプリ。
設計根拠は `anshinmichi_sekkei_v1_0.md` / `anshinmichi_code_handoff_v1_0.md`（社内台帳参照）。

## 構成

- [`prototype/`](./prototype) — 実装着手前必須の経路探索エンジン技術検証（Node.js）。
  グラフ構築・影スコア計算・Dijkstra経路探索の速度検証。詳細は `prototype/README.md` を参照。
- [`functions/`](./functions) — Cloud Functions（routeSearch/shadowCalc/moderation/お知らせ配信）。
  `prototype/`で検証したロジックをそのまま本番実装へ移植。詳細は `functions/README.md` を参照。
- [`app/`](./app) — Flutterアプリ本体。Aha Moment動線
  （起動→オンボーディング→位置情報許可→ホームで安心ルート即表示）、
  投稿フロー（種別選択→ペイント→道路スナップ→投稿完了）、
  Firebase接続（Firestore/Auth/Analytics/Crashlytics/Remote Config/Cloud Messaging、
  未接続時は自動フォールバック）、
  設定・ペイウォール画面（RevenueCat接続、未接続時はデモ購入へ自動フォールバック）、
  Cloud Functions連携（経路探索は`RemoteRouteSearchService`経由でサーバー側実行）、
  本人確認基盤（電話番号SMS認証、Auth Custom Claim `isVerified`で`isVerifiedUser()`のコメント投稿ゲートを判定）、
  目的地入力画面（道路網の模式図をタップして選択）、
  プッシュ通知・お知らせ機能（トピック購読方式のFCM配信）を実装。
  詳細・セットアップ上の注意点は `app/README.md` を参照。

## 現在の状況（完了した範囲）

1. 経路探索エンジンの技術検証プロトタイプを実装・実行し、結果を `prototype/RESULTS.md` に記録
   （小規模データでは実用速度を確認。実データでのスケーラビリティは未検証、要再検証）
2. Flutterアプリの雛形・Aha Moment動線・投稿フロー（ペイントUI）・Firebase接続・
   設定/ペイウォール画面（RevenueCat接続）・Cloud Functions（経路探索・影スコアバッチ・
   モデレーション）・本人確認基盤（電話番号SMS認証、Auth Custom Claim化）・目的地入力画面・
   プッシュ通知/お知らせ機能（FCM、フォアグラウンド受信時の専用オーバーレイバナー含む）・
   オフライン地図の実キャッシュ（直近ルート1件、位置・鮮度チェック込み）・
   投稿確定演出の強化（標準機能のみでの波紋+チェックマーク描画+効果音+触覚）・
   実地図タイル（Google Maps、`RealMapRouteView`、既定無効・`--dart-define`で有効化）を実装
   （このセッションの実行環境にFlutter SDK・Firebase/RevenueCat/Firebase CLIへの
   ネットワークアクセスが無いため、ビルド・実機確認・実接続確認・実デプロイは未実施。要ローカル検証）
3. Cloud Functions側の集計ロジック・空間インデックスを高度化
   （投稿件数に応じて重みを逓減させる加重移動平均、最近傍ノード探索の
   全件走査→グリッドインデックス化、影スコア事前計算バッチの建物候補絞り込み
   （3600ノード規模で約1秒→約350ms）。詳細は `functions/README.md` 参照）
4. Remote Config⇔`config/moderation`の自動同期を実装
   （`syncModerationConfigFromRemoteConfig`が1時間おきにRemote Configテンプレートを
   `config/moderation`ドキュメントへ反映。従来は手動同期が前提だった。
   詳細は `functions/README.md` 参照）
5. より大きな合成グリッド（60x60=3600ノード、実データ規模に近い4万ノードでの最近傍探索比較含む）
   での経路探索エンジンの再検証を実施し、`prototype/RESULTS_LARGE.md` に記録
   （空間インデックス導入で最近傍ノード探索が高速化することを確認。ただし
   Overpass API実疎通・実際のOSMデータでの検証は依然として未実施。詳細は
   `prototype/README.md` 参照）
6. 投稿の不正利用対策（連投・スパム投稿のレート制限）を実装
   （同一投稿者が直近10分間に一定件数を超えて投稿した場合、モデレーション設定に関わらず
   自動承認をスキップし人力承認キューへ留め置く。`functions/src/rateLimiting.js`、
   詳細は `functions/README.md` 参照）
7. 「人通りが少ない」投稿種別を追加（環境要因としての体感安全度。主観・偏見の影響を受けやすいため
   常に人力承認を必須とする荒らし対策付き）。加えて`searchRoute`の不正利用対策
   （認証必須化＋レート制限）を実装し、comfortScoreの機械的な収集による悪用リスクを緩和した
   （詳細は `functions/README.md` 参照）
8. 開発側リソース消費対策として、`searchRoute`が`roadSegments`（区間ごとのスコア）を
   呼び出しのたびに全件スキャンしていた問題を修正。グラフ本体と同じ5分間キャッシュへ統合し、
   認証済み・レート制限内の呼び出しであっても実質「5分に1回の全件読み取り」に抑えた
   （`functions/index.js`の`loadCachedGraph`、詳細は `functions/README.md` 参照）
9. 設計書が意図していた「投稿者の信頼スコアでの重みづけ」を実装。本人確認済みユーザーの
   投稿は匿名ユーザーの投稿より集計への影響度を大きくする（1.5倍 vs 0.7倍）。承認可否自体は
   変えず、承認後のスコアへの反映度合いのみを調整（`functions/src/aggregation.js`の
   `computeTrustWeight`、詳細は `functions/README.md` 参照）
10. フォアグラウンド通知バナーの複数通知キュー表示を実装。お知らせがほぼ同時に複数届いても
    重ねて表示せず、`ForegroundBannerQueue`が常に1件だけを直列に表示する
    （`app/lib/widgets/foreground_notification_banner.dart`、詳細は `app/README.md` 参照）
11. オフライン地図キャッシュを「直近ルート1件」から「複数エリア分（既定5件）」の保持に拡張。
    自宅・職場など、よく使う数か所を行き来する利用パターンに対応（同一エリアは重複させず
    上書き、複数該当時は最も新しいものを選択。`app/lib/services/route_result_cache.dart`、
    詳細は `app/README.md` 参照）

## 次のアクション

- ローカル環境で `app/` の `flutter pub get && flutter analyze && flutter test` を実行し、
  型エラー・ビルドエラーが無いことを確認
- ローカル環境でFirebaseプロジェクトを作成し、`app/README.md` の手順に沿って実接続を確認
  （`google-services.json`配置、Auth の電話番号認証プロバイダ有効化、Cloud Messaging有効化＋
  iOSはAPNs認証キー登録、`firestore.rules`デプロイ・検証、Remote Configキー設定）
- ローカル環境で `functions/` を `npm install` → デプロイし、`npm run seed` で検証用データを投入。
  実データ（1都市分）でのスケーラビリティ・レスポンスタイムを再測定
- ローカル環境でRevenueCatプロジェクトを作成し、`app/README.md` の手順に沿って実接続を確認
  （APIキーの`--dart-define`注入、`premium`エンタイトルメント設定）
- `prototype/` の技術検証を、ネットワーク制限のない環境でOverpass API実疎通ありで再実施
