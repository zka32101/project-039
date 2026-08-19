import 'package:firebase_remote_config/firebase_remote_config.dart';
import '../models/moderation_config.dart';
import '../services/remote_config_service.dart';

const _keyRegion = 'moderation_region';
const _keyAutoApproveAnonymous = 'moderation_auto_approve_anonymous';
const _keyTrustScoreThreshold = 'moderation_trust_score_threshold';
const _keyDefaultShadeWeight = 'route_default_shade_weight';
const _keyMinSupportedVersion = 'min_supported_version';

/// Firebase Remote Config ラッパー。
class FirebaseRemoteConfigAdapter implements RemoteConfigService {
  FirebaseRemoteConfigAdapter(this._remoteConfig);

  final FirebaseRemoteConfig _remoteConfig;

  @override
  Future<void> initialize() async {
    await _remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(hours: 1),
      ),
    );
    await _remoteConfig.setDefaults({
      _keyRegion: 'JP',
      _keyAutoApproveAnonymous: true,
      _keyTrustScoreThreshold: 0.5,
      _keyDefaultShadeWeight: 0.6,
      _keyMinSupportedVersion: '0.1.0',
    });
    try {
      await _remoteConfig.fetchAndActivate();
    } catch (_) {
      // フェッチ失敗時はsetDefaults済みの値をそのまま使う（オフライン耐性）
    }
  }

  @override
  ModerationConfig get moderationConfig => ModerationConfig(
        region: _remoteConfig.getString(_keyRegion),
        autoApproveAnonymous: _remoteConfig.getBool(_keyAutoApproveAnonymous),
        trustScoreThreshold: _remoteConfig.getDouble(_keyTrustScoreThreshold),
      );

  @override
  double get defaultShadeWeight => _remoteConfig.getDouble(_keyDefaultShadeWeight);

  @override
  String get minSupportedVersion => _remoteConfig.getString(_keyMinSupportedVersion);
}
