import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'firebase/firebase_bootstrap.dart';
import 'firebase/firebase_remote_config_service.dart';
import 'viewmodels/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final bootstrapResult = await bootstrapFirebase();

  if (bootstrapResult.available) {
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
  }

  runApp(
    ProviderScope(
      overrides: [
        firebaseAvailableProvider.overrideWithValue(bootstrapResult.available),
      ],
      child: const AnshinmichiApp(),
    ),
  );
}
