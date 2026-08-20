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
   モデレーション）・本人確認基盤（電話番号SMS認証）・目的地入力画面・
   プッシュ通知/お知らせ機能（FCM）を実装
   （このセッションの実行環境にFlutter SDK・Firebase/RevenueCat/Firebase CLIへの
   ネットワークアクセスが無いため、ビルド・実機確認・実接続確認・実デプロイは未実施。要ローカル検証）

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
