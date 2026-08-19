# あんしんみち（Flutterアプリ）

`anshinmichi_code_handoff_v1_0.md` に基づく、Aha Moment動線（起動→位置情報許可→
ホームで安心ルート即表示）の実装。

## セットアップ上の重要な注記

このセッションの実行環境には **Flutter/Dart SDKがインストールされておらず**、
`flutter pub get` / `flutter analyze` / `flutter test` / `flutter create` を実行できていない。
そのため:

- `lib/` 配下のコードはレビューベースで作成しており、**実機・エミュレータでのビルド確認は未実施**。
  ローカル環境で `flutter pub get && flutter analyze` を最初に実行し、型エラー等を確認すること。
- `android/` `ios/` 等のプラットフォームディレクトリは含まれていない（`flutter create .` で生成される
  ため）。**ローカルで `flutter create .` を実行してプラットフォームコードを生成した上で**、
  位置情報権限の設定を追加すること:
  - Android: `android/app/src/main/AndroidManifest.xml` に
    `ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION` の `<uses-permission>` を追加
  - iOS: `ios/Runner/Info.plist` に `NSLocationWhenInUseUsageDescription` を追加
    （常時位置情報は不要な設計のため `NSLocationAlwaysUsageDescription` は不要）
- **Firebase接続も同様に実接続確認ができていない**（Firebaseコンソール・CLIへのネットワークアクセスが
  無いため）。ローカルで以下を実施すること:
  1. Firebaseコンソールでプロジェクトを作成し、Firestore/Auth(匿名認証を有効化)/Analytics/
     Crashlytics/Remote Configを有効化
  2. Android: `android/app/google-services.json` を配置
     iOS: `ios/Runner/GoogleService-Info.plist` を配置
     （詳細は `lib/firebase/firebase_bootstrap.dart` のコメント参照）
  3. `firestore.rules` をFirebaseプロジェクトへデプロイ（**未検証のドラフト**。
     `firebase emulators:exec` 等でのローカル検証を推奨）
  4. Remote Configに以下のキーを設定（`lib/firebase/firebase_remote_config_service.dart` 参照。
     未設定でも`setDefaults`分の値で動作する）:
     `moderation_region` / `moderation_auto_approve_anonymous` / `moderation_trust_score_threshold` /
     `route_default_shade_weight` / `min_supported_version`
  - Firebase未接続・初期化失敗時は自動的にオンデバイス実装（Local*Service群）へフォールバックし、
    アプリはクラッシュせず動作を続ける設計にしている（`main.dart` 参照）
- **RevenueCat接続も同様に実接続確認ができていない**（RevenueCatダッシュボードへのネットワークアクセスが
  無いため）。ローカルで以下を実施すること:
  1. RevenueCatダッシュボードでプロジェクトを作成し、App Store Connect/Google Play Consoleと連携
  2. 「premium」エンタイトルメントと紐づくProductを設定（`lib/purchases/revenuecat_subscription_service.dart`
     の`_entitlementId`参照）
  3. iOS/AndroidそれぞれのPublic API Keyを取得し、`flutter run --dart-define=REVENUECAT_IOS_API_KEY=xxx
     --dart-define=REVENUECAT_ANDROID_API_KEY=xxx` のように起動時に注入する
     （キー未設定時は自動的に`LocalSubscriptionService`＝端末内デモ購入へフォールバックする）
  4. `purchases_flutter`の`purchasePackage`戻り値の型はSDKバージョンで変わるため、
     `flutter pub get`後に`lib/purchases/revenuecat_subscription_service.dart`のコメント箇所を
     必ず確認すること

## このセッションで実装した範囲

Code引き継ぎ書の実装順序 1〜7＋一部2（Firebase接続）:

- [x] データモデル（`RoadSegment` / `RouteResult` / `SpotType` / `SpotSubmissionRequest`
  / `ModerationConfig` 等。永続化するUserドキュメント設計は次スプリントで追加）
- [x] Service層: `LocationService` / `RouteSearchService` / `SpotSubmissionService` / `AuthService` /
  `RemoteConfigService`（すべて抽象インターフェース＋オンデバイス実装＋Firebase実装の二本立て）
- [x] Firebase接続: `firebase_bootstrap.dart`でアプリ起動時に初期化を試み、失敗時は
  自動的にオンデバイス実装へフォールバック（未接続環境でもクラッシュしない設計）
  - Firestore: 投稿を`shadeSpots`/`brightnessSpots`/`spotComments`コレクションへ永続化
    （`FirestoreSpotSubmissionService`）。セキュリティルールのドラフトは`firestore.rules`
  - Auth: 匿名認証（`FirebaseAuthAdapter`）。本人確認フロー自体は未実装
  - Analytics: KPI5イベントをFirebase Analyticsへ送信（`FirebaseAnalyticsAdapter`）
  - Crashlytics: 未捕捉例外の転送を`main.dart`起動時に設定
  - Remote Config: `ModerationConfig`・経路探索の重み・`min_supported_version`を配信
    （`min_supported_version`未達時は`UpdateRequiredView`で更新を促す）
- [x] ViewModel/状態管理（Riverpod, `HomeViewModel`。投稿フローは画面ローカルの状態機械）
- [x] Aha Moment動線: 起動 → オンボーディング(3枚) → 位置情報許可 → ホーム（安心ルート即表示）
- [x] 投稿フロー（ペイントUI）: 種別選択 → 指でなぞる → 道路区間へ自動スナップ → 確認
  → [デモ用トグルで本人確認済み扱いにするとコメント入力可] → 投稿完了（確定演出）→
  反映モードにより「即時反映」「承認待ち」を表示分岐
- [x] 設定画面（アカウント／通知／サブスク管理／反映モード表示）とペイウォール:
  - アカウント: 匿名ユーザーID表示（本人確認状態は「未確認」固定表示。フロー自体は次スプリント）
  - 通知: お知らせ受信トグル（実際のプッシュ配信基盤=FCM等は未実装、設定値の永続化のみ）
  - サブスク管理: 現在のプラン表示、ペイウォールへの導線
  - 反映モード表示: `ModerationConfig`に基づき「即時反映」「承認待ち」を表示
  - ペイウォール: 設計書「Aha Moment直後ではなくトリガー」に従い、ホーム画面の
    「詳細ルート最適化」トグルON時のみ表示（Aha動線・投稿動線には挟まない）
  - RevenueCat: `SubscriptionService`（インターフェース＋オンデバイスのデモ購入実装＋
    `RevenueCatSubscriptionService`）の二本立て。未接続時は端末内フラグでの疑似購入で
    ペイウォール〜プレミアム機能解放までのフローを一通り確認できる

## このセッションで実装していない範囲（次スプリント）

- **本人確認基盤（本物の確認フロー）** — Authは匿名認証のみ実装済み。投稿画面の
  「本人確認済みとして投稿（デモ用）」は手動トグルで分岐のみ再現しており、
  実際の本人確認（電話番号確認等）とcustom claim連携は未実装
- Lottieアニメーション・効果音（SE）— 確定演出は`TweenAnimationBuilder`+ハプティクスの簡易版で代替
- **Cloud Functions**（経路探索・影スコアバッチ・モデレーション判定の本番実装）— 現状の
  経路探索・投稿反映はすべてオンデバイス（またはFirestore書き込みのみ）で完結しており、
  サーバー側の重み付け合算バッチは未実装
- 実際のプッシュ通知配信基盤（FCM等）— 設定画面のトグルは値の保存のみ
- オフライン地図の実キャッシュ — ペイウォールの訴求文言・導線のみ実装、実データキャッシュは未実装
- 実地図タイル（Google Maps等）— 現状は道路網データを模式図として描画する`SchematicMapView`/`PaintCanvas`で代替
- petit_core / petit_ui — 台帳確認の結果、本セッションでは未使用（存在しないリポジトリのため単体実装）
- **Firebase/RevenueCat実接続の検証** — このセッションはネットワークアクセスが無いため、
  `flutterfire configure`・RevenueCatダッシュボード連携・実プロジェクトへの疎通・
  Firestoreルールのデプロイ検証はいずれも未実施。ローカル環境での検証が必須（上記セットアップ手順参照）

## ディレクトリ構成

```
lib/
  models/            // RoadSegment, RouteResult, SpotType, SpotSubmission, ModerationConfig
  services/
    road_graph_engine/  // prototype/ の検証済みロジックのDart移植
                        // (geo/sunPosition/graph/shadowScore/routeSearch/snapToRoad)
    road_network_repository.dart // 道路網データの読み込み・キャッシュ（Route/Spot両サービスが共有）
    route_search_service.dart    // インターフェース＋オンデバイス実装（Cloud Functions版に後で差し替え）
    spot_submission_service.dart // インターフェース＋オンデバイス実装（道路スナップ＋反映モード判定）
    auth_service.dart            // インターフェース＋オンデバイスの匿名ID発行フォールバック
    remote_config_service.dart   // インターフェース＋固定デフォルト値のフォールバック
    map_projection.dart          // 緯度経度⇔画面座標の変換（ホーム表示／投稿キャンバス共通）
    app_version.dart             // min_supported_version比較ロジック
    subscription_service.dart    // インターフェース＋オンデバイスのデモ購入フォールバック
    notification_preference_storage.dart
    location_service.dart
    analytics_service.dart
    onboarding_storage.dart
  firebase/            // Firebase接続時に上記インターフェースへ差し込む実装群
    firebase_bootstrap.dart          // 起動時初期化＋失敗時フォールバック＋Crashlytics連携
    firebase_analytics_service.dart
    firebase_auth_service.dart
    firebase_remote_config_service.dart
    firebase_spot_submission_service.dart
    firebase_options.dart            // .gitignore済み。各自 `flutterfire configure` 等で生成
  purchases/           // RevenueCat接続時に上記インターフェースへ差し込む実装群
    purchases_bootstrap.dart         // 起動時初期化＋APIキー未設定時フォールバック
    revenuecat_subscription_service.dart
  viewmodels/        // Riverpod providers（Firebase/RevenueCat有無で実装を自動切替）, HomeViewModel
  views/
    onboarding/      // オンボーディング(3枚)
    home/            // ホーム（安心ルート表示、詳細ルート最適化トグル）
    paint/           // 投稿フロー（種別選択→ペイント→確認→完了）
    settings/        // 設定（アカウント/通知/サブスク管理/反映モード表示）
    paywall/         // ペイウォール（詳細ルート最適化・オフライン地図利用時にトリガー）
    update_required/ // min_supported_version未達時の強制更新画面
  theme/             // ダークモード対応テーマ・安心スコアのカラーグラデーション
  widgets/           // PrimaryButton（二度押し防止）
assets/
  sample_road_network.json // prototype/fixtures/tokyo_sample.json と同一の検証用データ
firestore.rules       // Firestoreセキュリティルールのドラフト（未検証、デプロイ前に要検証）
test/
  road_graph_engine_test.dart   // ルートエンジン・スナップロジックのunit test
  onboarding_view_test.dart     // オンボーディングのwidget test
  spot_type_selector_test.dart  // 投稿種別選択のwidget test
  app_version_test.dart         // min_supported_version比較のunit test
  subscription_state_test.dart  // SubscriptionStateのunit test
  paywall_view_test.dart        // ペイウォールのwidget test
  settings_view_test.dart       // 設定画面のwidget test
```

## 実行方法（ローカル環境・Flutter SDKインストール後）

```bash
flutter create .        # プラットフォームディレクトリを生成（初回のみ）
flutter pub get
flutter analyze
flutter test
flutter run
```
