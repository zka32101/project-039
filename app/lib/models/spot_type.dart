import 'package:flutter/material.dart';

/// 投稿フローの種別選択（設計書Step2「投稿フロー」: 木/アーケード/雨よけ/明るさ/人通り）。
enum SpotType {
  tree('木陰', Icons.park_outlined, Color(0xFF2E7D5B)),
  arcade('アーケード', Icons.foundation_outlined, Color(0xFF6D4C41)),
  rainShelter('雨よけ', Icons.umbrella_outlined, Color(0xFF1565C0)),
  brightness('夜の明るさ', Icons.wb_incandescent_outlined, Color(0xFFF9A825)),
  lowFootTraffic('人通りが少ない', Icons.groups_outlined, Color(0xFF6A1B9A));

  const SpotType(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;

  /// 木陰は日中のみ、アーケード/雨よけは終日、明るさ・人通りは夜間に効く投稿種別かを表す
  /// （設計書 `ShadeSpot.timeDependent` に対応）。
  bool get isTimeDependent => this == SpotType.tree;

  /// 「特定エリアが危険」という主観的な印象の投稿は、日陰・雨よけの有無のような客観的な
  /// 観測と異なり、投稿者の偏見の影響を受けやすく、特定の属性の人が多いエリアへの
  /// スティグマ助長や荒らしのリスクが大きい。そのため地域のモデレーション設定
  /// （自動承認/承認待ち）に関わらず、常に人力承認を必須とする
  /// （`functions/index.js`の`handleSpotCreated`参照）。
  bool get requiresManualReview => this == SpotType.lowFootTraffic;
}
