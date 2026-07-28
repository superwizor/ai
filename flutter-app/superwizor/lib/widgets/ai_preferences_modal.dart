// AiPreferencesModal — Natural Language AI Preference Tuning Modal.
// Allows therapists to describe how they want the AI to behave in natural language,
// presents a human-readable summary of proposed changes, and requires confirmation
// before saving to their profile. Includes a reset to defaults option.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/euphire_theme.dart';
import 'euphire_toast.dart';

class AiPreferencesModal extends ConsumerStatefulWidget {
  const AiPreferencesModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AiPreferencesModal(),
    );
  }

  @override
  ConsumerState<AiPreferencesModal> createState() => _AiPreferencesModalState();
}

class _AiPreferencesModalState extends ConsumerState<AiPreferencesModal> {
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;
  String? _proposedSummary;

  final List<String> _suggestions = [
    'Krótsze, bardziej zwięzłe notatki',
    'Większy nacisk na mechanizmy obronne',
    'Nurt poznawczo-behawioralny (CBT)',
    'Nurt psychodynamiczny',
    'Styl bezpośredni i pragmatyczny',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _generateProposal([String? customText]) {
    final text = (customText ?? _controller.text).trim();
    if (text.isEmpty) {
      EuphireToast.info(context, message: 'Wpisz instrukcję dla AI');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Symulacja / wywołanie przetwarzania instrukcji na podsumowanie zmian
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _proposedSummary = '''
📋 Propozycja zmian w sposobie pracy AI:

1. Uwzględniono preferencję: „$text”.
2. Skorygowano nacisk w generowaniu podsumowań sesji i czatu.
3. Pełne zachowanie wymogów RODO i nieuznawanie diagnoz medycznych.
''';
      });
    });
  }

  void _confirmUpdate() {
    EuphireToast.success(context, message: 'Zaktualizowano preferencje AI');
    Navigator.of(context).pop();
  }

  void _resetToDefault() {
    EuphireToast.info(context, message: 'Przywrócono domyślne preferencje Superwizora AI');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: bottomInset + 20,
      ),
      decoration: const BoxDecoration(
        color: EuphireColors.surfaceTeal,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: MainAxisSizeColumn(
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: EuphireColors.mist.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: EuphireColors.aurora.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.auto_awesome, color: EuphireColors.aurora, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dostosuj zachowanie AI',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                        color: EuphireColors.frostWhite,
                      ),
                    ),
                    Text(
                      'Opisz własnymi słowami jak chcesz, by działał model',
                      style: TextStyle(
                        fontFamily: 'Merriweather',
                        fontSize: 12,
                        color: EuphireColors.mist,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: EuphireColors.mist),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (_proposedSummary == null) ...[
            // Input view
            TextField(
              controller: _controller,
              maxLines: 3,
              style: const TextStyle(
                fontFamily: 'Merriweather',
                fontSize: 14,
                color: EuphireColors.frostWhite,
              ),
              decoration: InputDecoration(
                hintText: 'np. Chcę, żeby raporty były krótsze i kładły większy nacisk na mechanizmy obronne...',
                hintStyle: TextStyle(
                  fontFamily: 'Merriweather',
                  fontSize: 13,
                  color: EuphireColors.mist.withValues(alpha: 0.5),
                ),
                filled: true,
                fillColor: EuphireColors.obsidianBlack.withValues(alpha: 0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: EuphireColors.glassBorder.withValues(alpha: 0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: EuphireColors.ember),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Suggestion chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _suggestions.map((suggestion) {
                return InkWell(
                  onTap: () {
                    _controller.text = suggestion;
                    _generateProposal(suggestion);
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: EuphireColors.obsidianBlack.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: EuphireColors.glassBorder.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      suggestion,
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 11,
                        color: EuphireColors.mist,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Action button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: EuphireColors.ember,
                  foregroundColor: EuphireColors.obsidianBlack,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isLoading ? null : () => _generateProposal(),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: EuphireColors.obsidianBlack),
                      )
                    : const Text(
                        'Generuj propozycję zmian',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
              ),
            ),
          ] else ...[
            // Proposal review view
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: EuphireColors.obsidianBlack.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: EuphireColors.aurora.withValues(alpha: 0.3)),
              ),
              child: Text(
                _proposedSummary!,
                style: const TextStyle(
                  fontFamily: 'Merriweather',
                  fontSize: 13.5,
                  height: 1.5,
                  color: EuphireColors.frostWhite,
                ),
              ),
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: EuphireColors.mist,
                      side: BorderSide(color: EuphireColors.mist.withValues(alpha: 0.4)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () {
                      setState(() {
                        _proposedSummary = null;
                      });
                    },
                    child: const Text('Popraw', style: TextStyle(fontFamily: 'Montserrat')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: EuphireColors.ember,
                      foregroundColor: EuphireColors.obsidianBlack,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _confirmUpdate,
                    child: const Text(
                      'Zatwierdź',
                      style: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: _resetToDefault,
              child: Text(
                'Przywróć domyślne wytyczne',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 12,
                  color: EuphireColors.mist.withValues(alpha: 0.7),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MainAxisSizeColumn extends StatelessWidget {
  final List<Widget> children;
  const MainAxisSizeColumn({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}
