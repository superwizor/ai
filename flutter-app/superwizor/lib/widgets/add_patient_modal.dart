import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/euphire_theme.dart';
import 'euphire_text_field.dart';
import 'euphire_button.dart';
import '../providers/patient_provider.dart';

class AddPatientModal extends StatefulWidget {
  const AddPatientModal({super.key});

  @override
  State<AddPatientModal> createState() => _AddPatientModalState();
}

class _AddPatientModalState extends State<AddPatientModal> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nowy Klient.',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: EuphireColors.frostWhite,
            ),
          ),
          const SizedBox(height: 24),
          EuphireTextField(
            controller: _firstNameController,
            labelText: 'Imię.',
          ),
          const SizedBox(height: 16),
          EuphireTextField(
            controller: _lastNameController,
            labelText: 'Nazwisko (lub inicjał).',
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: Consumer(
              builder: (context, ref, child) {
                return EuphireButton(
                  text: 'Dodaj Klienta.',
                  onPressed: () {
                    final firstName = _firstNameController.text.trim();
                    final lastName = _lastNameController.text.trim();
                    if (firstName.isNotEmpty) {
                      ref.read(patientsProvider.notifier).addPatient(firstName, lastName);
                      Navigator.pop(context);
                    }
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
