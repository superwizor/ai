import 'package:flutter/material.dart';
import 'euphire_action_sheet.dart';
import 'euphire_bottom_sheet.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_localizations.dart';
import '../providers/locale_provider.dart';

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
          Text(AppLocalizations.of(context)!.drawer_language, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 24),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'pl', label: Text('Polski')),
              ButtonSegment(value: 'en', label: Text('English')),
            ],
            selected: {_selectedLanguage},
            showSelectedIcon: true,
            onSelectionChanged: (s) {
              if (s.isNotEmpty) _onLanguageChanged(s.first);
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
