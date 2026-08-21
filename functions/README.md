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
| `searchRoute` | Callable (`onCall`) | 重み付き最短経路探索。Flutterアプリの`RemoteRouteSearchService`から呼び出される（認証必須、レート制限あり） |
| `shadowCalcBatch` | Schedule（3時間毎） | 建物×太陽角度から`roadSegments`の`baseShadowScore`を再計算 |
| `onShadeSpotCreated` / `onBrightnessSpotCreated` | Firestore `onDocumentCreated` | 投稿作成時のモデレーション判定（自動承認/承認待ち、連投レート制限含む）＋承認時の集計反映 |
| `onShadeSpotApproved` / `onBrightnessSpotApproved` | Firestore `onDocumentUpdated` | 人力承認（pending→approved）時の集計反映 |
| `onSpotCommentCreated` | Firestore `onDocumentCreated` | コメントのNGワードフィルタ＋連投レート制限 |
| `voteSpot` | Callable (`onCall`) | 投稿の相互チェック（確認投票／通報、認証必須・レート制限あり） |
| `syncVerificationStatus` | Callable (`onCall`) | 電話番号認証完了後、ID Tokenの`phone_number`クレームを検証し`users/{uid}.isVerified`とAuth Custom Claim（`isVerified`）を更新 |
| `onAnnouncementCreated` | Firestore `onDocumentCreated` | お知らせ（設計書Step7）作成をトリガーに`announcements`トピック購読者へFCM配信 |
| `syncModerationConfigFromRemoteConfig` | Schedule（1時間毎） | Remote Configテンプレートの`moderation_*`パラメータを`config/moderation`へ自動反映 |

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

**投稿の不正利用対策（連投・スパム投稿のレート制限）**: `submitterId`は`firestore.rules`で
`request.auth.uid`との一致を強制しているため偽装できない。この`submitterId`を使い、
`handleSpotCreated`が投稿作成のたびに、同一投稿者の直近10分間の投稿件数
（`shadeSpots`/`brightnessSpots`横断、`src/rateLimiting.js`の`RATE_LIMIT_WINDOW_MS`/
`RATE_LIMIT_MAX_SUBMISSIONS`参照）を確認する。上限（既定5件）を超えていれば、
モデレーション設定が自動承認を許可していても'pending'（人力承認キュー）に留め置き、
即座の地図反映を止める。誤検知時にも復旧可能な可逆的措置（削除・拒否ではなく保留）にしている。

**コメントの不正利用対策（連投レート制限）**: `onSpotCommentCreated`はNGワードフィルタで
'approved'と判定された場合でも、`checkAndIncrementRateLimit`（`searchRoute`と共通の固定ウィンドウ
方式レート制限、`rateLimits/{key}`ドキュメント）で`comment:${submitterId}`ごとの直近10分間の
コメント数を確認する（`COMMENT_RATE_LIMIT_WINDOW_MS`/`COMMENT_RATE_LIMIT_MAX_REQUESTS`、既定
10件）。上限を超えていれば'pending'に差し替え、以降は人力確認待ちとする。コメントは
`isVerifiedUser()`（電話番号SMS認証必須）のため投稿ほど気軽には量産できないが、一度認証を
突破すれば無制限に連投できてしまう点は変わらないため、投稿・`searchRoute`と同様の対策を
コメントにも拡張した。

**投稿の相互チェック（確認投票／通報、`voteSpot`）**: `shadeSpots`/`brightnessSpots`の
`votes`フィールドはこれまで作成時に`0`で初期化されるのみで、増減させるロジックが存在しない
未使用フィールドだった。以下2つの意味を持つ投票として実装した（詳細な設計意図は
`src/spotVoting.js`のコメント参照）:
- confirm（確認投票）: 「この投稿は正しい」という他ユーザーからの追認。`votes`が
  `CONFIRM_APPROVE_THRESHOLD`（既定3）件集まると、人力承認待ち（'pending'）の投稿を
  自動承認へ引き上げる
- report（通報）: 「この投稿は不正確・不適切」という指摘。`reportCount`が
  `REPORT_HOLD_THRESHOLD`（既定3）件集まると、承認済み（'approved'）の投稿を人力再審査待ち
  （'pending'）へ差し戻す。削除ではなく可逆的な保留にとどめる（他のレート制限と同じ方針）

不正利用対策として、(1) 投稿者本人による自演投票を禁止（`submitterId`との一致チェック）、
(2) 同一ユーザーは同一投稿に対して1回のみ投票可能（`spotVotes/{spotKind}_{spotId}_{uid}`の
存在チェックをFirestoreトランザクションで原子的に判定）、(3) `checkAndIncrementRateLimit`に
よる短時間の大量投票の抑止（`VOTE_RATE_LIMIT_WINDOW_MS`/`VOTE_RATE_LIMIT_MAX_REQUESTS`）を
実装している。

【既知の制約】通報によって'approved'→'pending'へ差し戻しても、`aggregation.js`が既に
道路区間の集計スコアへ反映済みの影響度は自動的には巻き戻さない（過去の集計への遡及的な
取り消しは行わない設計。今後の反映を止めることが目的で、遡及訂正は将来課題）。
投票ボタンを表示するクライアント側UI（「投稿を確認」画面、`app/lib/views/spots/spots_list_view.dart`）
も実装済み（詳細は`app/README.md`参照）。

**主観的な投稿種別への荒らし対策（人通りが少ない）**: 「人通りが少ない」（`brightnessSpots`の
`reasonType: 'low_foot_traffic'`）は、日陰・雨よけの有無のような客観的な観測と異なり、
投稿者の主観・偏見の影響を受けやすい（特定エリア・属性への偏った印象の助長・荒らしのリスク）。
そのため`decideInitialStatus`に`requiresManualReview: true`を渡し、地域のモデレーション設定
（`autoApproveAnonymous`）に関わらず常に'pending'（人力承認キュー）に留め置く
（`moderationLogic.js`参照）。上記のレート制限とは独立した、この投稿種別固有の追加防御。

**`searchRoute`の不正利用対策（大量呼び出しによるスコアの機械的な収集を防ぐ）**: 「人通りが
少ない」等の主観投稿が地図のcomfortScoreに混ざるため、これを悪用されると「人が少ない場所を
探す」目的で使われるリスクがある。アプリのUI上には都市全体を俯瞰する画面は無いが、
`searchRoute`（誰でも呼べるCallable Function）自体には従来レート制限が無く、任意の起点・
終点で大量に呼び出せばcomfortScoreを機械的に収集できてしまっていた。対応として、
(1) `request.auth`が無い呼び出しを拒否（匿名認証済みであることを必須化）、
(2) `request.auth.uid`をキーにした固定ウィンドウ方式のレート制限（既定: 1分間に30回まで、
`SEARCH_ROUTE_RATE_LIMIT_WINDOW_MS`/`SEARCH_ROUTE_RATE_LIMIT_MAX_REQUESTS`参照）を追加した
（`rateLimiting.js`の`checkAndIncrementRateLimit`）。カウンタは`rateLimits/{key}`
Firestoreドキュメントで管理し、`firestore.rules`でクライアントからの直接読み書きを拒否している。
**完全な防止ではなく抑止策**である点に注意（同一デバイスで匿名アカウントを都度作り直す等の
迂回は技術的に可能。Firebase App Check等、より強固な対策の導入は次スプリントの検討候補）。

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
shadeSpots/{id}      = { roadSegmentId, type, timeDependent, submitterId, status, createdAt,
                          votes, reportCount }
brightnessSpots/{id} = { roadSegmentId, brightnessLevel, reasonType, submitterId, status, createdAt,
                          votes, reportCount }
  // reasonType: 'dark'（夜の明るさ投稿） | 'low_foot_traffic'（人通りが少ない投稿）
  // 'low_foot_traffic'は常に人力承認へ回す（上記「投稿の不正利用対策」参照）
  // votes/reportCountはvoteSpotが更新する（下記「投稿の相互チェック」参照）
spotComments/{id}    = { spotId, submitterId, text, moderationStatus, createdAt }
spotVotes/{voteId}   = { spotKind, spotId, uid, voteType, createdAt }
  // voteId = `${spotKind}_${spotId}_${uid}`。同一ユーザーの同一投稿への二重投票を防ぐための記録専用
config/moderation    = { region, autoApproveAnonymous, trustScoreThreshold }
users/{uid}          = { isVerified, verificationMethod, phoneNumber, updatedAt }
  // isVerified等はsyncVerificationStatusのみが書き込む（クライアントは読み取りのみ）
announcements/{id}   = { title, body, createdAt }
  // 運営が管理コンソール等から作成する想定（クライアントは作成不可）。
  // 作成をトリガーにonAnnouncementCreatedが'announcements'トピックへFCM配信する
rateLimits/{key}     = { windowStartMs, count }
  // searchRoute等の不正利用対策用カウンタ。keyは`searchRoute:${uid}`のような形式。
  // Cloud Functions（Admin SDK）のみが読み書きする（クライアントからはread/writeとも拒否）。
  // ドキュメント数は一意なuidの数に比例して増え続ける（自動削除は無し）。長期運用では
  // Firestoreの TTL ポリシー（`windowStartMs`を元にした有効期限フィールドを追加して設定）や、
  // 定期クリーンアップ用のスケジュール関数の追加を検討すること（現状はストレージコストが
  // 小さいため未対応。次スプリント候補）
```

## セットアップ

`firebase.json`はリポジトリルートに配置済み（`functions`のsourceと`firestore.rules`/
`firestore.indexes.json`のパスを指定）。ローカルで`firebase use --add`を実行し対象プロジェクトを
紐づけてから、リポジトリルートで以下を実行する:

```bash
cd functions && npm install && cd ..
npm test --prefix functions   # unit test（純粋ロジックのみ。Firestore/Functions自体はエミュレータが必要）
firebase emulators:start --only functions,firestore   # ローカル動作確認（要Firebase CLI）
node functions/seed/seedRoadNetwork.js                 # 検証用データ投入（要FIRESTORE_EMULATOR_HOST or サービスアカウント）
firebase deploy --only functions,firestore:rules,firestore:indexes  # 本番デプロイ
```

**注意**: `firestore.indexes.json`の複合インデックス（`shadeSpots`/`brightnessSpots`の
`submitterId`+`createdAt`、連投レート制限判定用、下記参照。加えて`spotComments`の
`moderationStatus`+`createdAt`、「みんなの声」画面の一覧取得用）は`firestore:indexes`の
デプロイを忘れるとそれぞれ`countRecentSubmissions`・`FirestoreSpotCommentService.fetchRecent`の
クエリが失敗する（`FAILED_PRECONDITION`エラー）。

## 既知の制約・次スプリントでの改善点

- `searchRoute`は`roadNodes`/`roadWays`/`roadSegments`全件を読み込んでグラフ・スコアを構築する
  （ウォームインスタンス内で5分間キャッシュ、`GRAPH_CACHE_TTL_MS`）。以前は`roadSegments`の
  スコアだけキャッシュ対象外で、認証済み・レート制限内の呼び出しであっても毎回全件スキャンが
  発生していたが、グラフ本体と同じキャッシュへ統合し「5分に1回の全件読み取り」に抑えた
  （開発側リソース消費対策。`loadCachedGraph`のコメント参照）。トレードオフとして、
  投稿承認直後の反映まで最大5分のラグが生じる点に注意。最近傍ノード探索自体は
  `src/spatialIndex.js`（緯度経度グリッド分割インデックス）で全件走査から近傍セル走査へ
  置き換え済みだが、Firestoreからの読み込み自体を地域分割・geohash等でクエリ側から絞り込む
  改善（ウォームインスタンスが無いコールドスタート直後の1回目の呼び出しコスト削減）は
  未実装（実データ規模＝1都市分での再検証が必要）
- `shadowCalcBatch`（`shadowScore.js`）は、建物群を`spatialIndex.js`で空間インデックス化し、
  各エッジについて「理論上その建物の影が到達しうる範囲」の建物のみを候補に絞り込むよう
  最適化済み（大規模合成データでの実測は`prototype/RESULTS_LARGE.md`参照。3600ノード規模で
  約1秒→約350msに短縮）。ただし絞り込み半径は「最も高い建物」基準の上限値のため、
  極端に高い建物が1棟でも混在すると効果が薄れる。実データ規模（数万エッジ×数万建物）での
  再検証は引き続き必要
- モデレーション設定（`config/moderation`）は、`syncModerationConfigFromRemoteConfig`
  （1時間おきのスケジュール実行）がRemote Configテンプレートから自動反映するように
  なった（`src/remoteConfigSync.js`）。トリガー方式ではなくポーリング方式のため、
  Remote Config更新から反映までに最大1時間のラグがある点に注意
  （即時反映が必要になった場合はRemote Config管理APIのWebhook等への切り替えを検討）
- 集計ロジック（`src/aggregation.js`）は、投稿件数（`shadeSampleCount`/`brightnessSampleCount`）に
  応じて新規投稿1件あたりの重みを逓減させる加重移動平均（直近20件相当で頭打ち）に更新済み。
  設計書が意図する「投稿者の信頼スコアでの重みづけ」も実装済み: `users/{submitterId}.isVerified`
  に応じて1件あたりの重み倍率を変える（本人確認済み=1.5倍、匿名=0.7倍、`computeTrustWeight`
  参照）。承認可否（自動承認/人力承認キュー）自体は変えず、承認された後の「スコアへの
  影響度」だけを調整する設計にしている（匿名投稿も0倍にはせず歓迎し続けることで、
  `ModerationConfig.autoApproveAnonymous`が意図する「ソフトローンチ初期は投稿密度優先」
  という方針を損なわないため）
- NGワードフィルタ（`src/moderationLogic.js`）は、辞書をコード内ハードコードから
  Remote Config（`moderation_ng_words`パラメータ、カンマ区切り文字列）→`config/moderation`
  ドキュメントの`ngWords`フィールド、という既存のモデレーション設定と同じ同期経路
  （`syncModerationConfigFromRemoteConfig`）へ載せる形に更新した。運営者はデプロイ無しで
  Remote Configコンソールから辞書を更新できる（反映まで上記と同じく最大1時間のラグ）。
  あわせて、半角/全角スペース・中黒・ハイフン等の区切り文字を挟んでNGワードフィルタを
  回避する簡易的な手口（例:「死　ね」）を正規化で吸収するようにした（`normalizeForNgWordMatch`）。
  ただし専用のモデレーションAPI（Perspective API等）が持つような文脈判定・表記ゆれ吸収
  （伏字・同音異字等）までは対応しておらず、あくまで辞書ベースの簡易フィルタである点は
  変わらない
