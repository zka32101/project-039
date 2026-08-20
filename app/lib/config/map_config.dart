/// 実地図タイル（Google Maps）を使うかどうかのコンパイル時フラグ（バックログ「実地図タイル」対応）。
///
/// 【重要】このセッションには`android/`/`ios/`プラットフォームディレクトリが存在しない
/// （`flutter create .`で生成する必要がある。`app/README.md`参照）ため、Google Maps SDKが要求する
/// ネイティブ側のAPIキー設定（AndroidManifest.xmlのmeta-data、iOSのGMSServices.provideAPIKey）を
/// このセッションでは行えていない。そのため既定値は`false`（未設定時は`SchematicMapView`を使う）とし、
/// ローカルでネイティブ設定を済ませたユーザーだけが`--dart-define=USE_GOOGLE_MAPS=true`で
/// 明示的に有効化する運用にしている（RevenueCat APIキーと同様の
/// `String.fromEnvironment`パターン、`purchases_bootstrap.dart`参照）。
const useGoogleMapTiles = bool.fromEnvironment('USE_GOOGLE_MAPS');
