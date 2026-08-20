# あんしんみち — Cloud Functions

Code引き継ぎ書 `functions/` ディレクトリ構成（routeSearch / shadowCalc / moderation）＋
設計書Step7「お知らせ機能」の実装。
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
| `syncVerificationStatus` | Callable (`onCall`) | 電話番号認証完了後、ID Tokenの`phone_number`クレームを検証し`users/{uid}.isVerified`とAuth Custom Claim（`isVerified`）を更新 |
| `onAnnouncementCreated` | Firestore `onDocumentCreated` | お知らせ（設計書Step7）作成をトリガーに`announcements`トピック購読者へFCM配信 |

## セキュリティ設計（クライアントを信用しない）

`shadeSpots`/`brightnessSpots`/`spotComments`のstatus系フィールドは、クライアントは常に
`'pending'`で作成することを`../app/firestore.rules`が強制する。実際の承認可否
（自動承認 or 人力承認キュー）はこのCloud Functions側（Admin SDK、ルールの制約を受けない）
のみが判定・更新する。これにより、クライアントが自己承認扱いで投稿する抜け道を塞いでいる。

同様に、`users/{uid}.isVerified`（本人確認状態）もクライアントは直接書き込めない
（`firestore.rules`で`allow write: if false`）。`syncVerificationStatus`が、Firebase Authが
電話番号クレデンシャルのリンクに成功した本人にのみ発行するID Tokenの`phone_number`クレームを
検証してから書き込むことで、自己申告による本人確認済み偽装を防いでいる。

`isVerified`はFirestoreドキュメントに加え、同じ関数内でAuth Custom Claimとしても
`getAuth().setCustomUserClaims(uid, { isVerified: true })`で設定する。
`firestore.rules`の`isVerifiedUser()`はCustom Claim（`request.auth.token.isVerified`）のみを
参照する構成にしており、`spotComments`の作成可否判定のたびにFirestoreドキュメントを
`get()`する必要がない（追加の読み取り課金・レイテンシを避けられる）。
Custom Claimはトークン発行時点のスナップショットのため、クライアント側は本人確認完了直後に
`user.getIdToken(true)`で強制リフレッシュしてから利用する（`app/lib/firebase/firebase_verification_service.dart`参照）。

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
users/{uid}          = { isVerified, verificationMethod, phoneNumber, updatedAt }
  // isVerified等はsyncVerificationStatusのみが書き込む（クライアントは読み取りのみ）
announcements/{id}   = { title, body, createdAt }
  // 運営が管理コンソール等から作成する想定（クライアントは作成不可）。
  // 作成をトリガーにonAnnouncementCreatedが'announcements'トピックへFCM配信する
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
  インスタンスキャッシュあり）。最近傍ノード探索自体は`src/spatialIndex.js`（緯度経度グリッド
  分割インデックス）で全件走査から近傍セル走査へ置き換え済みだが、Firestoreからの読み込み自体を
  地域分割・geohash等でクエリ側から絞り込む改善は未実装（実データ規模＝1都市分での再検証が必要）
- `shadowCalcBatch`は全エッジ×全建物の総当たりに近い実装（`shadowScore.js`参照）。
  広域展開時は空間インデックスでの最適化が必要
- モデレーション設定は`config/moderation`ドキュメントとFlutter側のRemote Configで
  二重管理になっている（現状は手動同期が前提）。将来的にはRemote Config更新を
  トリガーにこのドキュメントへ反映する仕組みが望ましい
- 集計ロジック（`src/aggregation.js`）は、投稿件数（`shadeSampleCount`/`brightnessSampleCount`）に
  応じて新規投稿1件あたりの重みを逓減させる加重移動平均（直近20件相当で頭打ち）に更新済み。
  設計書が意図する「投稿者の信頼スコアでの重みづけ」はまだ未実装
- NGワードフィルタ（`src/moderationLogic.js`）は検証用の最小限の辞書のみ。
  実運用では専用のモデレーションAPIへの置き換えを推奨
