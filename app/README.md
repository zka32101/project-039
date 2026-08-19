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

Code引き継ぎ書の実装順序 1〜6（Aha Moment最短動線まで）:

- [x] データモデル（`RoadSegment` / `RouteResult` 等。User/ShadeSpot等は次スプリントで追加）
- [x] Service層: `LocationService` / `RouteSearchService`
  （オンデバイス実装。technical validation済みの経路探索エンジンをDart移植）
- [x] 計測3点セットのうちイベント発火部分（`AnalyticsService`。Firebase SDK自体は未接続）
- [x] ViewModel（Riverpod, `HomeViewModel`）
- [x] Aha Moment動線: 起動 → オンボーディング(3枚) → 位置情報許可 → ホーム（安心ルート即表示）

## このセッションで実装していない範囲（次スプリント）

- 投稿フロー（ペイントUI・スナップ・反映モード分岐）— ホーム画面にボタンのみ配置済み
- Firebase(Firestore/Auth/Analytics/Crashlytics/Remote Config)・RevenueCat・Cloud Functionsの実接続
- 実地図タイル（Google Maps等）— 現状は道路網データを模式図として描画する`SchematicMapView`で代替
- petit_core / petit_ui — 台帳確認の結果、本セッションでは未使用（存在しないリポジトリのため単体実装）

## ディレクトリ構成

```
lib/
  models/            // RoadSegment, RouteResult
  services/
    road_graph_engine/  // prototype/ の検証済みロジックのDart移植（geo/sunPosition/graph/shadowScore/routeSearch）
    route_search_service.dart // インターフェース＋オンデバイス実装（Cloud Functions版に後で差し替え）
    location_service.dart
    analytics_service.dart
    onboarding_storage.dart
  viewmodels/        // Riverpod providers, HomeViewModel
  views/
    onboarding/      // オンボーディング(3枚)
    home/            // ホーム（安心ルート表示）
  theme/             // ダークモード対応テーマ・安心スコアのカラーグラデーション
  widgets/           // PrimaryButton（二度押し防止）
assets/
  sample_road_network.json // prototype/fixtures/tokyo_sample.json と同一の検証用データ
test/
  road_graph_engine_test.dart // ルートエンジンのunit test
  onboarding_view_test.dart   // オンボーディングのwidget test
```

## 実行方法（ローカル環境・Flutter SDKインストール後）

```bash
flutter create .        # プラットフォームディレクトリを生成（初回のみ）
flutter pub get
flutter analyze
flutter test
flutter run
```
