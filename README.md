# project-039 — あんしんみち

影・雨よけ・夜の明るさをユーザーが「塗る」投稿で地図化し、経路探索へ統合する実用ユーティリティアプリ。
設計根拠は `anshinmichi_sekkei_v1_0.md` / `anshinmichi_code_handoff_v1_0.md`（社内台帳参照）。

## 構成

- [`prototype/`](./prototype) — 実装着手前必須の経路探索エンジン技術検証（Node.js）。
  グラフ構築・影スコア計算・Dijkstra経路探索の速度検証。詳細は `prototype/README.md` を参照。
- [`app/`](./app) — Flutterアプリ本体。Aha Moment動線
  （起動→オンボーディング→位置情報許可→ホームで安心ルート即表示）と、
  投稿フロー（種別選択→ペイント→道路スナップ→投稿完了）を実装。
  詳細・セットアップ上の注意点は `app/README.md` を参照。

## 現在の状況（完了した範囲）

1. 経路探索エンジンの技術検証プロトタイプを実装・実行し、結果を `prototype/RESULTS.md` に記録
   （小規模データでは実用速度を確認。実データでのスケーラビリティは未検証、要再検証）
2. Flutterアプリの雛形・Aha Moment動線・投稿フロー（ペイントUI）を実装
   （このセッションの実行環境にFlutter SDKが無いため、ビルド・実機確認は未実施。要ローカル検証）

## 次のアクション

- ローカル環境で `app/` の `flutter pub get && flutter analyze && flutter test` を実行し、
  型エラー・ビルドエラーが無いことを確認
- `prototype/` の技術検証を、ネットワーク制限のない環境でOverpass API実疎通ありで再実施
- 本人確認基盤・Firebase接続・Cloud Functions実装へ進む
