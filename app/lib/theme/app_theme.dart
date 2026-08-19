import 'package:flutter/material.dart';

/// 設計書Step5.5「ダークモード必須（夜の明るさ確認という利用シーンの性質上、優先度最高）」に対応。
class AppTheme {
  AppTheme._();

  static const seedColor = Color(0xFF2E7D5B); // 木陰をイメージした緑

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.light);
    return _base(scheme);
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.dark);
    return _base(scheme);
  }

  static ThemeData _base(ColorScheme scheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(48), // タップ領域44pt+
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      appBarTheme: AppBarTheme(backgroundColor: scheme.surface, elevation: 0),
    );
  }

  /// 安心スコア(0〜1)を「影濃い緑〜明るい黄」のグラデーションへ変換する。
  static Color comfortScoreColor(double score) {
    final clamped = score.clamp(0.0, 1.0);
    return Color.lerp(const Color(0xFFFFF176), const Color(0xFF1B5E20), clamped)!;
  }
}
