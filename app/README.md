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

## このセッションで実装した範囲

Code引き継ぎ書の実装順序 1〜7（投稿フローまで）:

- [x] データモデル（`RoadSegment` / `RouteResult` / `SpotType` / `SpotSubmissionRequest`
  / `ModerationConfig` 等。User/永続化を伴うShadeSpot・BrightnessSpotコレクションは次スプリントで追加）
- [x] Service層: `LocationService` / `RouteSearchService` / `SpotSubmissionService`
  （オンデバイス実装。technical validation済みの経路探索エンジン・スナップロジックをDart移植）
- [x] 計測3点セットのうちイベント発火部分（`AnalyticsService`。Firebase SDK自体は未接続）
- [x] ViewModel/状態管理（Riverpod, `HomeViewModel`。投稿フローは画面ローカルの状態機械）
- [x] Aha Moment動線: 起動 → オンボーディング(3枚) → 位置情報許可 → ホーム（安心ルート即表示）
- [x] 投稿フロー（ペイントUI）: 種別選択 → 指でなぞる → 道路区間へ自動スナップ → 確認
  → [デモ用トグルで本人確認済み扱いにするとコメント入力可] → 投稿完了（確定演出）→
  反映モードにより「即時反映」「承認待ち」を表示分岐

## このセッションで実装していない範囲（次スプリント）

- 本人確認基盤（本物の認証・確認フロー）— 投稿画面では「本人確認済みとして投稿（デモ用）」という
  手動トグルで分岐のみ再現。実運用にはAuth・別コレクション分離実装が必須
- Lottieアニメーション・効果音（SE）— 確定演出は`TweenAnimationBuilder`+ハプティクスの簡易版で代替
- Firebase(Firestore/Auth/Analytics/Crashlytics/Remote Config)・RevenueCat・Cloud Functionsの実接続
  （投稿の反映も現状は端末内メモリ上のグラフを直接更新するのみ。サーバー永続化なし）
- 実地図タイル（Google Maps等）— 現状は道路網データを模式図として描画する`SchematicMapView`/`PaintCanvas`で代替
- petit_core / petit_ui — 台帳確認の結果、本セッションでは未使用（存在しないリポジトリのため単体実装）

## ディレクトリ構成

```
lib/
  models/            // RoadSegment, RouteResult, SpotType, SpotSubmission, ModerationConfig
  services/
    road_graph_engine/  // prototype/ の検証済みロジックのDart移植
                        // (geo/sunPosition/graph/shadowScore/routeSearch/snapToRoad)
    road_network_repository.dart // 道路網データの読み込み・キャッシュ（Route/Spot両サービスが共有）
    route_search_service.dart    // インターフェース＋オンデバイス実装（Cloud Functions版に後で差し替え）
    spot_submission_service.dart // 投稿の道路スナップ＋反映モード判定
    map_projection.dart          // 緯度経度⇔画面座標の変換（ホーム表示／投稿キャンバス共通）
    location_service.dart
    analytics_service.dart
    onboarding_storage.dart
  viewmodels/        // Riverpod providers, HomeViewModel
  views/
    onboarding/      // オンボーディング(3枚)
    home/            // ホーム（安心ルート表示）
    paint/           // 投稿フロー（種別選択→ペイント→確認→完了）
  theme/             // ダークモード対応テーマ・安心スコアのカラーグラデーション
  widgets/           // PrimaryButton（二度押し防止）
assets/
  sample_road_network.json // prototype/fixtures/tokyo_sample.json と同一の検証用データ
test/
  road_graph_engine_test.dart   // ルートエンジン・スナップロジックのunit test
  onboarding_view_test.dart     // オンボーディングのwidget test
  spot_type_selector_test.dart  // 投稿種別選択のwidget test
```

## 実行方法（ローカル環境・Flutter SDKインストール後）

```bash
flutter create .        # プラットフォームディレクトリを生成（初回のみ）
flutter pub get
flutter analyze
flutter test
flutter run
```
