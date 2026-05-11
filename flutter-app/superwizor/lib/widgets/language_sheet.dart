import 'package:flutter/material.dart';
import 'euphire_action_sheet.dart';
import 'euphire_bottom_sheet.dart';

class LanguageSheet extends StatefulWidget {
  const LanguageSheet({super.key});

  @override
  State<LanguageSheet> createState() => _LanguageSheetState();
}

class _LanguageSheetState extends State<LanguageSheet> {
  String _selectedLanguage = 'pl';

  Future<void> _onLanguageChanged(String code) async {
    if (code == 'pl') {
      setState(() => _selectedLanguage = 'pl');
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) Navigator.of(context).pop();
      });
      return;
    }
    
    // EN selected -> show popup, snap back to PL
    await showEuphireBottomSheet<void>(
      context: context,
      builder: (ctx) => EuphireActionSheet(
        header: 'Language unavailable',
        body: 'English interface is currently disabled in the MVP version. Coming soon.',
        primary: EuphireSheetAction(
          label: 'Rozumiem',
          onPressed: () => Navigator.of(ctx).pop(),
        ),
      ),
    );
    if (mounted) {
      setState(() => _selectedLanguage = 'pl');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Język aplikacji', style: Theme.of(context).textTheme.headlineMedium),
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
