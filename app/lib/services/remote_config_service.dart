import '../models/moderation_config.dart';

/// Remote Configの抽象インターフェース（設計書Step4.5）。
/// 「反映モード（地域別）／安心スコア計算の重みパラメータ／ペイウォールトリガー条件／
/// min_supported_version」をアプリ更新無しで切り替えるための窓口。
abstract class RemoteConfigService {
  /// フェッチ＆アクティベート（Firebase未接続時はno-op）。
  Future<void> initialize();

  ModerationConfig get moderationConfig;

  /// 経路探索のデフォルト重み（0=距離最優先, 1=安心スコア最優先）
  double get defaultShadeWeight;

  /// このバージョン未満のアプリには更新を促す
  String get minSupportedVersion;
}

/// Firebase未接続環境向けのフォールバック実装。固定のデフォルト値を返す。
class LocalRemoteConfigService implements RemoteConfigService {
  @override
  Future<void> initialize() async {}

  @override
  ModerationConfig get moderationConfig => ModerationConfig.defaultConfig;

  @override
  double get defaultShadeWeight => 0.6;

  @override
  String get minSupportedVersion => '0.1.0';
}
