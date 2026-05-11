import 'package:flutter/material.dart';
import '../theme/euphire_theme.dart';
import '../constants/modalities.dart';
import '../l10n/app_localizations.dart';

class ModalitySheet extends StatefulWidget {
  const ModalitySheet({super.key});

  @override
  State<ModalitySheet> createState() => _ModalitySheetState();
}

class _ModalitySheetState extends State<ModalitySheet> {
  // Temporary local state for MVP. Backend update would happen here.
  String _selectedModality = kModalities.first.code;

  String _modalityDisplayName(BuildContext context, String code) {
    final t = AppLocalizations.of(context);
    switch (code) {
      case 'integrative': return t.modality_integrative;
      case 'cbt': return t.modality_cbt;
      case 'psychodynamic': return t.modality_psychodynamic;
      case 'positive': return t.modality_positive;
      case 'schema': return t.modality_schema;
      case 'systemic': return t.modality_systemic;
      case 'eft': return t.modality_eft;
      case 'coaching': return t.modality_coaching;
      default: return code;
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
          Text('Domyślny nurt', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: kModalities.length,
              itemBuilder: (context, index) {
                final m = kModalities[index];
                final isSelected = m.code == _selectedModality;
                return ListTile(
                  title: Text(_modalityDisplayName(context, m.code)),
                  trailing: isSelected ? const Icon(Icons.check, color: EuphireColors.ember) : null,
                  onTap: () {
                    setState(() => _selectedModality = m.code);
                    // TODO: call identityClient.updateProfile()
                    Future.delayed(const Duration(milliseconds: 200), () {
                      if (context.mounted) Navigator.of(context).pop();
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
