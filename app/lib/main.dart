import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'firebase/firebase_bootstrap.dart';
import 'firebase/firebase_push_notification_service.dart';
import 'firebase/firebase_remote_config_service.dart';
import 'purchases/purchases_bootstrap.dart';
import 'services/notification_preference_storage.dart';
import 'viewmodels/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final firebaseResult = await bootstrapFirebase();

  if (firebaseResult.available) {
    // Remote Configの初回フェッチ＆アクティベート、匿名認証の確立をアプリ描画前に済ませる。
    // どちらかが失敗してもアプリ自体は起動できるよう、個別にtry/catchする。
    try {
      await FirebaseRemoteConfigAdapter(FirebaseRemoteConfig.instance).initialize();
    } catch (_) {
      // Remote Config未取得でもsetDefaults分の値で動作継続する
    }
    try {
      await FirebaseAuth.instance.signInAnonymously();
    } catch (_) {
      // 匿名サインインの再試行は投稿時にAuthService.ensureSignedIn()側で行う
    }
    try {
      // 設定画面の「お知らせを受け取る」トグル（既定ON）に合わせて
      // announcementsトピックを購読する。許可プロンプト拒否等でもアプリは継続動作させる。
      final notificationEnabled = await NotificationPreferenceStorage().isEnabled();
      await FirebasePushNotificationService(FirebaseMessaging.instance).initialize(
        enabled: notificationEnabled,
      );
    } catch (_) {
      // 通知購読の失敗は致命的ではないため無視する（設定画面から再度トグルすれば再試行される）
    }
  }

  // RevenueCatはFirebaseとは独立した課金基盤のため、Firebaseの成否に関わらず初期化を試みる。
  final purchasesResult = await bootstrapPurchases();

  runApp(
    ProviderScope(
      overrides: [
        firebaseAvailableProvider.overrideWithValue(firebaseResult.available),
        purchasesAvailableProvider.overrideWithValue(purchasesResult.available),
      ],
      child: const AnshinmichiApp(),
    ),
  );
}
