import 'package:flutter/material.dart';

/// 投稿フローの種別選択（設計書Step2「投稿フロー」: 木/アーケード/雨よけ/明るさ/人通り）。
enum SpotType {
  tree('木陰', Icons.park_outlined, Color(0xFF2E7D5B)),
  arcade('アーケード', Icons.foundation_outlined, Color(0xFF6D4C41)),
  rainShelter('雨よけ', Icons.umbrella_outlined, Color(0xFF1565C0)),
  brightness('夜の明るさ', Icons.wb_incandescent_outlined, Color(0xFFF9A825)),
  lowFootTraffic('人通りが少ない', Icons.groups_outlined, Color(0xFF6A1B9A)),

  // 「危険・困りごと」系の投稿種別。日陰・雨よけのような環境の快適さではなく、
  // 歩行の安全性そのものに関わる情報（段差・階段の暗さ・歩道の狭さ）。
  // 【スコープ】経路探索の重み付け（comfortScore）には反映せず、投稿一覧・地図上の
  // 表示情報としてのみ扱う（安心スコアへの統合は専用の設計検討が必要なため次スプリント送り）。
  unevenGround('段差・でこぼこ', Icons.warning_amber_outlined, Color(0xFFD84315)),
  darkStairs('暗い階段', Icons.stairs_outlined, Color(0xFF4E342E)),
  narrowSidewalk('狭い歩道', Icons.compress_outlined, Color(0xFF37474F));

  const SpotType(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;

  /// 木陰は日中のみ、アーケード/雨よけは終日、明るさ・人通りは夜間に効く投稿種別かを表す
  /// （設計書 `ShadeSpot.timeDependent` に対応）。危険・困りごと系は時間帯に依存しない。
  bool get isTimeDependent => this == SpotType.tree;

  /// このアプリの「安心スコア」（日陰・明るさの集計）に寄与する投稿種別かどうか。
  /// 危険・困りごと系は安全性に関する別軸の情報のため、現状は集計対象に含めない
  /// （`functions/index.js`の`handleSpotCreated`、`_shadeSpotTypeName`参照）。
  bool get isHazardReport =>
      this == SpotType.unevenGround || this == SpotType.darkStairs || this == SpotType.narrowSidewalk;

  /// 「特定エリアが危険」という主観的な印象の投稿は、日陰・雨よけの有無のような客観的な
  /// 観測と異なり、投稿者の偏見の影響を受けやすく、特定の属性の人が多いエリアへの
  /// スティグマ助長や荒らしのリスクが大きい。そのため地域のモデレーション設定
  /// （自動承認/承認待ち）に関わらず、常に人力承認を必須とする
  /// （`functions/index.js`の`handleSpotCreated`参照）。危険・困りごと系も同じ理由
  /// （虚偽・誇張報告による特定エリアへのスティグマ助長リスク）で常に人力承認とする。
  bool get requiresManualReview => this == SpotType.lowFootTraffic || isHazardReport;
}
