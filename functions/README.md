# あんしんみち — Cloud Functions

Code引き継ぎ書 `functions/` ディレクトリ構成（routeSearch / shadowCalc / moderation）の実装。
経路探索・影スコア計算ロジック本体は `prototype/` で技術検証したものをそのまま移植している
（`src/geo.js` 等は `prototype/src/` と同一内容）。

## 【重要】このセッションでの検証状況

このセッションはFirebase CLI・実プロジェクトへのネットワークアクセスが無いため、以下はいずれも
**未実行・未検証**:

- `firebase emulators:start` によるローカル動作確認
- `firebase deploy --only functions` での実デプロイ
- `seed/seedRoadNetwork.js` によるFirestoreへのデータ投入
- 実データ規模（1都市分、数万〜数十万エッジ）でのレスポンスタイム測定
  （`prototype/RESULTS.md` は49ノードの合成データでの結果に過ぎない）

ローカル環境で `npm install` 後、上記を必ず実施すること。

## エクスポートしている関数

| 関数名 | トリガー | 役割 |
|---|---|---|
| `searchRoute` | Callable (`onCall`) | 重み付き最短経路探索。Flutterアプリの`RemoteRouteSearchService`から呼び出される |
| `shadowCalcBatch` | Schedule（3時間毎） | 建物×太陽角度から`roadSegments`の`baseShadowScore`を再計算 |
| `onShadeSpotCreated` / `onBrightnessSpotCreated` | Firestore `onDocumentCreated` | 投稿作成時のモデレーション判定（自動承認/承認待ち）＋承認時の集計反映 |
| `onShadeSpotApproved` / `onBrightnessSpotApproved` | Firestore `onDocumentUpdated` | 人力承認（pending→approved）時の集計反映 |
| `onSpotCommentCreated` | Firestore `onDocumentCreated` | コメントのNGワードフィルタ |

## セキュリティ設計（クライアントを信用しない）

`shadeSpots`/`brightnessSpots`/`spotComments`のstatus系フィールドは、クライアントは常に
`'pending'`で作成することを`../app/firestore.rules`が強制する。実際の承認可否
（自動承認 or 人力承認キュー）はこのCloud Functions側（Admin SDK、ルールの制約を受けない）
のみが判定・更新する。これにより、クライアントが自己承認扱いで投稿する抜け道を塞いでいる。

## Firestoreコレクション構成

```
roadNodes/{id}       = { lat, lon }
roadWays/{id}        = { name, nodeIds: [nodeId, ...] }
roadSegments/{id}    = { roadId, fromNodeId, toNodeId, distanceM,
                          baseShadowScore, aggregatedShadeScore, aggregatedBrightnessScore,
                          lastCalculatedAt }
  // idはbuildGraph()が生成するedge id（`${wayId}_${i}`）と一致。
  // shadeSpots/brightnessSpotsの roadSegmentId がこのドキュメントIDを指す
buildings/{id}       = { heightM, centerLat, centerLon }
shadeSpots/{id}      = { roadSegmentId, type, timeDependent, submitterId, status, createdAt, votes }
brightnessSpots/{id} = { roadSegmentId, brightnessLevel, submitterId, status, createdAt }
spotComments/{id}    = { spotId, submitterId, text, moderationStatus, createdAt }
config/moderation    = { region, autoApproveAnonymous, trustScoreThreshold }
```

## セットアップ

`firebase.json`はリポジトリルートに配置済み（`functions`のsourceと`firestore.rules`のパスを
指定）。ローカルで`firebase use --add`を実行し対象プロジェクトを紐づけてから、リポジトリルートで
以下を実行する:

```bash
cd functions && npm install && cd ..
npm test --prefix functions   # unit test（純粋ロジックのみ。Firestore/Functions自体はエミュレータが必要）
firebase emulators:start --only functions,firestore   # ローカル動作確認（要Firebase CLI）
node functions/seed/seedRoadNetwork.js                 # 検証用データ投入（要FIRESTORE_EMULATOR_HOST or サービスアカウント）
firebase deploy --only functions,firestore:rules        # 本番デプロイ
```

## 既知の制約・次スプリントでの改善点

- `searchRoute`は毎回`roadNodes`/`roadWays`全件を読み込んでグラフを再構築する（5分間の簡易
  インスタンスキャッシュあり）。実データ規模では空間インデックス（地域分割・geohash等）による
  クエリ絞り込みが必須になる可能性が高い
- `shadowCalcBatch`は全エッジ×全建物の総当たりに近い実装（`shadowScore.js`参照）。
  広域展開時は空間インデックスでの最適化が必要
- モデレーション設定は`config/moderation`ドキュメントとFlutter側のRemote Configで
  二重管理になっている（現状は手動同期が前提）。将来的にはRemote Config更新を
  トリガーにこのドキュメントへ反映する仕組みが望ましい
- 集計ロジック（`src/aggregation.js`）は単純な移動平均のプレースホルダー。
  設計書が意図する「重み付け合算」（投稿者の信頼スコア等）は未実装
- NGワードフィルタ（`src/moderationLogic.js`）は検証用の最小限の辞書のみ。
  実運用では専用のモデレーションAPIへの置き換えを推奨
