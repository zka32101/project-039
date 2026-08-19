import 'package:flutter/material.dart';

/// 投稿フローの種別選択（設計書Step2「投稿フロー」: 木/アーケード/雨よけ/明るさ）。
enum SpotType {
  tree('木陰', Icons.park_outlined, Color(0xFF2E7D5B)),
  arcade('アーケード', Icons.foundation_outlined, Color(0xFF6D4C41)),
  rainShelter('雨よけ', Icons.umbrella_outlined, Color(0xFF1565C0)),
  brightness('夜の明るさ', Icons.wb_incandescent_outlined, Color(0xFFF9A825));

  const SpotType(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;

  /// 木陰は日中のみ、アーケード/雨よけは終日、明るさは夜間に効く投稿種別かを表す
  /// （設計書 `ShadeSpot.timeDependent` に対応）。
  bool get isTimeDependent => this == SpotType.tree;
}
