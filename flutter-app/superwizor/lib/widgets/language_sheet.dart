import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_localizations.dart';
import '../providers/locale_provider.dart';
import '../theme/euphire_theme.dart';

class LanguageSheet extends ConsumerStatefulWidget {
  const LanguageSheet({super.key});

  @override
  ConsumerState<LanguageSheet> createState() => _LanguageSheetState();
}

class _LanguageSheetState extends ConsumerState<LanguageSheet> {
  String _selectedLanguage = 'pl';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _selectedLanguage = ref.read(localeProvider).languageCode;
      });
    });
  }

  Future<void> _onLanguageChanged(String code) async {
    setState(() => _selectedLanguage = code);
    await ref.read(localeProvider.notifier).setLocale(Locale(code));
    
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context).drawer_language, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 24),
          _LanguageOption(
            title: 'Polski',
            isSelected: _selectedLanguage == 'pl',
            onTap: () => _onLanguageChanged('pl'),
          ),
          const SizedBox(height: 12),
          _LanguageOption(
            title: 'English',
            isSelected: _selectedLanguage == 'en',
            onTap: () => _onLanguageChanged('en'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageOption({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? EuphireColors.ember : theme.colorScheme.onSurface.withValues(alpha: 0.1),
            width: isSelected ? 2 : 1,
          ),
          color: isSelected ? EuphireColors.ember.withValues(alpha: 0.1) : Colors.transparent,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: EuphireColors.ember),
          ],
        ),
      ),
    );
  }
}
