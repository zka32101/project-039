/// pubspec.yamlの`version:`と手動で同期させる値。
/// 本来は package_info_plus 等で実行時に取得すべきだが、依存追加を最小限にするため
/// 本セッションでは定数管理とした（次スプリントでの置き換えを推奨）。
const String currentAppVersion = '0.1.0';

/// `min_supported_version`（Remote Config）と現在のアプリバージョンを比較する。
/// 現在バージョンが最小サポートバージョン未満なら true（更新が必要）。
bool isUpdateRequired({required String current, required String minSupported}) {
  final currentParts = _parse(current);
  final minParts = _parse(minSupported);
  final length = currentParts.length > minParts.length ? currentParts.length : minParts.length;

  for (var i = 0; i < length; i++) {
    final c = i < currentParts.length ? currentParts[i] : 0;
    final m = i < minParts.length ? minParts[i] : 0;
    if (c != m) return c < m;
  }
  return false;
}

List<int> _parse(String version) {
  return version.split('.').map((s) => int.tryParse(s) ?? 0).toList();
}
