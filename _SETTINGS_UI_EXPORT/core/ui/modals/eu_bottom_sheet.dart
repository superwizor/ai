import 'package:flutter/material.dart';
import 'package:labirynt_premium/src/core/theme/euphire_design_tokens.dart';
import 'package:labirynt_premium/src/core/theme/eu_text_styles.dart';

/// EUPHIRE Bottom Sheet System
///
/// Centralny, reużywalny komponent dla wszystkich Bottom Sheetów w aplikacji.
/// Zapewnia spójny wygląd i eliminuje duplikację kodu.
///
/// Przykład użycia:
/// ```dart
/// EuBottomSheet.show(
///   context: context,
///   variant: EuBottomSheetVariant.evergreen,
///   icon: Icons.favorite,
///   title: "Zapisane!",
///   description: "Pytanie zostało dodane do ulubionych.",
///   primaryButton: EuBottomSheetButton(
///     label: "OK",
///     onPressed: () => Navigator.pop(context),
///   ),
/// );
/// ```
enum EuBottomSheetVariant {
  /// Główny wariant (zieleń Evergreen) - standardowe akcje, potwierdzenia
  evergreen,

  /// Ciemny wariant (Nocturne/Ebony) - poważne akcje, rozłączenia, disconnecty
  dark,

  /// Wariant destrukcyjny (Error red) - usuwanie, negatywne akcje
  destructive,
}

/// Konfiguracja przycisku dla Bottom Sheeta
class EuBottomSheetButton {
  final String label;
  final VoidCallback onPressed;
  final bool isDestructive;

  const EuBottomSheetButton({
    required this.label,
    required this.onPressed,
    this.isDestructive = false,
  });
}

/// Główny komponent Bottom Sheeta EUPHIRE
class EuBottomSheet extends StatelessWidget {
  final EuBottomSheetVariant variant;
  final IconData? icon;
  final String? emojiIcon;
  final String title;
  final String? description;
  final Widget? customContent;
  final EuBottomSheetButton? primaryButton;
  final EuBottomSheetButton? secondaryButton;

  const EuBottomSheet({
    super.key,
    required this.variant,
    this.icon,
    this.emojiIcon,
    required this.title,
    this.description,
    this.customContent,
    this.primaryButton,
    this.secondaryButton,
  });

  /// Helper method do szybkiego wyświetlania Bottom Sheeta
  static Future<T?> show<T>({
    required BuildContext context,
    required EuBottomSheetVariant variant,
    IconData? icon,
    String? emojiIcon,
    required String title,
    String? description,
    Widget? customContent,
    EuBottomSheetButton? primaryButton,
    EuBottomSheetButton? secondaryButton,
    bool isDismissible = true,
    bool enableDrag = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      builder: (context) => EuBottomSheet(
        variant: variant,
        icon: icon,
        emojiIcon: emojiIcon,
        title: title,
        description: description,
        customContent: customContent,
        primaryButton: primaryButton,
        secondaryButton: secondaryButton,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = _getColorsForVariant();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border(top: BorderSide(color: colors.border, width: 1)),
        ),
        padding: const EdgeInsets.all(24),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle (pasek u góry)
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.handle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 32),

              // Ikona (opcjonalna)
              if (emojiIcon != null) ...[
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: colors.iconBackground,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      emojiIcon!,
                      style: const TextStyle(fontSize: 32),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ] else if (icon != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.iconBackground,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: colors.iconColor, size: 32),
                ),
                const SizedBox(height: 24),
              ],

              // Tytuł
              Text(
                title,
                style: EuTextStyles.h3.copyWith(
                  color: colors.titleColor,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              // Opis (opcjonalny)
              if (description != null) ...[
                const SizedBox(height: 16),
                RichText(
                  textAlign: TextAlign.center,
                  text: _parseDescriptionText(description!, colors),
                ),
              ],

              // Custom content (np. TextField)
              if (customContent != null) ...[
                const SizedBox(height: 24),
                customContent!,
              ],

              // Przyciski
              if (primaryButton != null || secondaryButton != null) ...[
                const SizedBox(height: 40),
                _buildButtons(colors),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _insertParagraphBreaks(String text, {int minChunkLength = 120}) {
    // Split by existing newlines to preserve deliberate formatting
    final paragraphs = text.split(RegExp(r'\n+'));
    final sentenceRegex = RegExp(r'([.!?](?:\*\*|")?)\s+');

    final resultParts = <String>[];

    for (final paragraph in paragraphs) {
      if (paragraph.length <= minChunkLength) {
        resultParts.add(paragraph);
        continue;
      }

      final matches = sentenceRegex.allMatches(paragraph).toList();
      if (matches.isEmpty) {
        resultParts.add(paragraph);
        continue;
      }

      final buffer = StringBuffer();
      int currentPos = 0;
      int currentChunkStart = 0;

      for (final match in matches) {
        final sentenceEnd = match.end;
        final chunkLength = sentenceEnd - currentChunkStart;

        if (chunkLength >= minChunkLength) {
          buffer.write(
            paragraph.substring(
              currentPos,
              match.start + match.group(1)!.length,
            ),
          );
          buffer.write('\n\n');
          currentPos = match.end;
          currentChunkStart = match.end;
        }
      }

      if (currentPos < paragraph.length) {
        buffer.write(paragraph.substring(currentPos));
      }

      resultParts.add(buffer.toString().trimRight());
    }

    return resultParts.join('\n\n');
  }

  TextSpan _parseDescriptionText(String text, _BottomSheetColors colors) {
    final defaultStyle = EuTextStyles.bodyMedium.copyWith(
      color: colors.descriptionColor,
      height: 1.5,
    );
    final boldStyle = EuTextStyles.bodyMedium.copyWith(
      color: colors.descriptionColor,
      fontWeight: FontWeight.w800,
      height: 1.5,
    );

    // First break down long text into paragraphs
    final formattedText = _insertParagraphBreaks(text);

    // Split text by ** bold tags
    final regex = RegExp(r'\*\*(.*?)\*\*');
    final matches = regex.allMatches(formattedText);
    final spans = <TextSpan>[];
    int currentOffset = 0;

    for (final match in matches) {
      // Add text before the bold tag
      if (match.start > currentOffset) {
        spans.add(
          TextSpan(text: formattedText.substring(currentOffset, match.start)),
        );
      }
      // Add the bold text (group 1 is the content between **)
      spans.add(TextSpan(text: match.group(1), style: boldStyle));
      currentOffset = match.end;
    }

    // Add remaining text
    if (currentOffset < formattedText.length) {
      spans.add(TextSpan(text: formattedText.substring(currentOffset)));
    }

    return TextSpan(style: defaultStyle, children: spans);
  }

  Widget _buildButtons(_BottomSheetColors colors) {
    // Jeśli są dwa przyciski, wyświetl w rzędzie
    if (primaryButton != null && secondaryButton != null) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: secondaryButton!.onPressed,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: colors.buttonBorder),
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                secondaryButton!.label,
                style: EuTextStyles.button.copyWith(
                  color: colors.secondaryButtonText,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: _buildPrimaryButton(colors)),
        ],
      );
    }

    // Jeśli tylko jeden przycisk, wyświetl pełnej szerokości
    if (primaryButton != null) {
      return SizedBox(
        width: double.infinity,
        child: _buildPrimaryButton(colors),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildPrimaryButton(_BottomSheetColors colors) {
    final isDestructive = primaryButton!.isDestructive;

    return ElevatedButton(
      onPressed: primaryButton!.onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isDestructive
            ? EuDesignTokens.error
            : colors.primaryButtonBackground,
        foregroundColor: isDestructive
            ? Colors.white
            : colors.primaryButtonText,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),
      child: Text(
        primaryButton!.label,
        style: EuTextStyles.button.copyWith(
          color: isDestructive ? Colors.white : colors.primaryButtonText,
        ),
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  _BottomSheetColors _getColorsForVariant() {
    switch (variant) {
      case EuBottomSheetVariant.evergreen:
        return _BottomSheetColors(
          background: EuDesignTokens.evergreen,
          border: EuDesignTokens.glassWhite,
          handle: Colors.white24,
          iconBackground: EuDesignTokens.ember.withValues(alpha: 0.2),
          iconColor: EuDesignTokens.ember,
          titleColor: EuDesignTokens.frostWhite,
          descriptionColor: EuDesignTokens.frostWhite.withValues(alpha: 0.7),
          primaryButtonBackground: EuDesignTokens.ember,
          primaryButtonText: EuDesignTokens.obsidianBlack,
          secondaryButtonText: EuDesignTokens.frostWhite,
          buttonBorder: EuDesignTokens.glassWhite,
        );

      case EuBottomSheetVariant.dark:
        return _BottomSheetColors(
          background: EuDesignTokens.ebonyBlack,
          border: EuDesignTokens.glassWhite,
          handle: Colors.white24,
          iconBackground: EuDesignTokens.error.withValues(alpha: 0.1),
          iconColor: EuDesignTokens.error,
          titleColor: EuDesignTokens.frostWhite,
          descriptionColor: EuDesignTokens.frostWhite.withValues(alpha: 0.7),
          primaryButtonBackground: EuDesignTokens.error,
          primaryButtonText: Colors.white,
          secondaryButtonText: EuDesignTokens.frostWhite,
          buttonBorder: EuDesignTokens.glassWhite,
        );

      case EuBottomSheetVariant.destructive:
        return _BottomSheetColors(
          background: EuDesignTokens.ebonyBlack,
          border: EuDesignTokens.glassWhite,
          handle: Colors.white24,
          iconBackground: EuDesignTokens.error.withValues(alpha: 0.1),
          iconColor: EuDesignTokens.error,
          titleColor: EuDesignTokens.frostWhite,
          descriptionColor: EuDesignTokens.frostWhite.withValues(alpha: 0.7),
          primaryButtonBackground: EuDesignTokens.error,
          primaryButtonText: Colors.white,
          secondaryButtonText: EuDesignTokens.frostWhite,
          buttonBorder: EuDesignTokens.glassWhite,
        );
    }
  }
}

/// Wewnętrzna klasa do przechowywania kolorów dla danego wariantu
class _BottomSheetColors {
  final Color background;
  final Color border;
  final Color handle;
  final Color iconBackground;
  final Color iconColor;
  final Color titleColor;
  final Color descriptionColor;
  final Color primaryButtonBackground;
  final Color primaryButtonText;
  final Color secondaryButtonText;
  final Color buttonBorder;

  _BottomSheetColors({
    required this.background,
    required this.border,
    required this.handle,
    required this.iconBackground,
    required this.iconColor,
    required this.titleColor,
    required this.descriptionColor,
    required this.primaryButtonBackground,
    required this.primaryButtonText,
    required this.secondaryButtonText,
    required this.buttonBorder,
  });
}
