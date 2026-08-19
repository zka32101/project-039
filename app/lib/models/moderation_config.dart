/// 設計書 `ModerationConfig { region, autoApproveAnonymous, trustScoreThreshold }` に対応。
/// 地域別に「即時反映」か「承認待ち」かを切り替えるための設定。
/// 本番ではRemote Config/Firestoreから取得する想定。本セッションでは固定値で代替する。
class ModerationConfig {
  const ModerationConfig({
    required this.region,
    required this.autoApproveAnonymous,
    required this.trustScoreThreshold,
  });

  final String region;

  /// 本人未確認ユーザーの投稿を自動承認するか
  final bool autoApproveAnonymous;
  final double trustScoreThreshold;

  static const defaultConfig = ModerationConfig(
    region: 'JP',
    autoApproveAnonymous: true, // ソフトローンチ初期は投稿密度を優先し自動承認
    trustScoreThreshold: 0.5,
  );
}
