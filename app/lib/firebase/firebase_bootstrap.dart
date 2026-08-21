import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// アプリ起動時のFirebase初期化。
///
/// 【重要な注記】このセッションの実行環境にはFirebase CLI/実プロジェクトへの
/// ネットワークアクセスが無いため、`flutterfire configure` の実行・実接続確認は
/// 行えていない。ローカル環境で以下を実施すること:
///   1. Firebaseコンソールでプロジェクトを作成
///   2. Android: `android/app/google-services.json` を配置
///      iOS: `ios/Runner/GoogleService-Info.plist` を配置
///      （モバイルはネイティブ設定ファイルがあれば `Firebase.initializeApp()` に
///      オプション省略で初期化できるため、現状はこの方式を採用）
///   3. Web対応やCI環境向けに明示的な`FirebaseOptions`が必要な場合は、
///      `flutterfire configure` で `lib/firebase/firebase_options.dart` を生成し
///      （プロジェクト固有の値を含むため`.gitignore`済み）、このファイルの
///      `Firebase.initializeApp()` 呼び出しに `options: DefaultFirebaseOptions.currentPlatform`
///      を追加すること
///
/// 上記が未設定の環境でもアプリがクラッシュしないよう、初期化失敗時は
/// `FirebaseBootstrapResult.available = false` を返し、呼び出し側（`main.dart`）が
/// オンデバイス実装（Local*Service群）にフォールバックできるようにしている。
class FirebaseBootstrapResult {
  const FirebaseBootstrapResult({required this.available, this.error});
  final bool available;
  final Object? error;
}

Future<FirebaseBootstrapResult> bootstrapFirebase() async {
  try {
    await Firebase.initializeApp();

    // Crashlyticsへの未捕捉例外の転送。Firebase初期化が成功した場合のみ有効化する。
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };

    return const FirebaseBootstrapResult(available: true);
  } catch (error) {
    // firebase_options.dart未生成・google-services.json未配置などの環境では
    // ここで失敗する想定。ログのみ残しオフラインモードへフォールバックする。
    debugPrint('[FirebaseBootstrap] Firebase初期化に失敗したためローカル実装にフォールバックします: $error');
    return FirebaseBootstrapResult(available: false, error: error);
  }
}
