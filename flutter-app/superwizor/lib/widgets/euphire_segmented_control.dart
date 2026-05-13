import 'package:flutter/material.dart';
import '../theme/euphire_theme.dart';

class EuphireSegmentedControl extends StatelessWidget {
  final String selected;
  final String leftValue;
  final String leftLabel;
  final String rightValue;
  final String rightLabel;
  final ValueChanged<String> onSelect;

  const EuphireSegmentedControl({
    super.key,
    required this.selected,
    required this.leftValue,
    required this.leftLabel,
    required this.rightValue,
    required this.rightLabel,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Row(
          children: [
            Expanded(
              child: _Segment(
                label: leftLabel,
                isSelected: selected == leftValue,
                onTap: () => onSelect(leftValue),
              ),
            ),
            Expanded(
              child: _Segment(
                label: rightLabel,
                isSelected: selected == rightValue,
                onTap: () => onSelect(rightValue),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _Segment({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? EuphireColors.ember : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? EuphireColors.obsidianBlack : EuphireColors.frostWhite,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
