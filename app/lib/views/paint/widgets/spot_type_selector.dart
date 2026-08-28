import 'package:flutter/material.dart';
import '../../../models/spot_type.dart';

/// 投稿フローの種別選択UI（設計書「種別選択（木/アーケード/雨よけ/明るさ）」）。
class SpotTypeSelector extends StatelessWidget {
  const SpotTypeSelector({super.key, required this.selected, required this.onSelected});

  final SpotType? selected;
  final ValueChanged<SpotType> onSelected;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.4,
      physics: const NeverScrollableScrollPhysics(),
      children: SpotType.values.map((type) {
        final isSelected = type == selected;
        return _SpotTypeCard(type: type, isSelected: isSelected, onTap: () => onSelected(type));
      }).toList(),
    );
  }
}

class _SpotTypeCard extends StatelessWidget {
  const _SpotTypeCard({required this.type, required this.isSelected, required this.onTap});

  final SpotType type;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? type.color.withOpacity(0.15) : Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? type.color : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(type.icon, size: 32, color: type.color),
              const SizedBox(height: 8),
              Text(type.label, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}
