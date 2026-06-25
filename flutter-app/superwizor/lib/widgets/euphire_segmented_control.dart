import 'package:flutter/material.dart';
import '../theme/euphire_theme.dart';
import '../utils/haptics.dart';

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
    final isLeft = selected == leftValue;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        height: 44,
        padding: const EdgeInsets.all(4), // Padding around the sliding thumb
        decoration: BoxDecoration(
          color: EuphireColors.nocturne,
          borderRadius: BorderRadius.circular(12),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final halfWidth = constraints.maxWidth / 2;
            return Stack(
              children: [
                // Animated sliding thumb
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  top: 0,
                  bottom: 0,
                  left: isLeft ? 0 : halfWidth,
                  width: halfWidth,
                  child: Container(
                    decoration: BoxDecoration(
                      color: EuphireColors.ember,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
                // Clickable text areas
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          AppHapticFeedback.selectionClick();
                          onSelect(leftValue);
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              color: isLeft ? EuphireColors.obsidianBlack : EuphireColors.frostWhite.withValues(alpha: 0.8),
                              fontWeight: isLeft ? FontWeight.bold : FontWeight.w500,
                              fontSize: 14,
                            ),
                            child: Text(leftLabel),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          AppHapticFeedback.selectionClick();
                          onSelect(rightValue);
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              color: !isLeft ? EuphireColors.obsidianBlack : EuphireColors.frostWhite.withValues(alpha: 0.8),
                              fontWeight: !isLeft ? FontWeight.bold : FontWeight.w500,
                              fontSize: 14,
                            ),
                            child: Text(rightLabel),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
