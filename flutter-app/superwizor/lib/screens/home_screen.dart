import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/euphire_header.dart';
import '../widgets/euphire_text_field.dart';
import '../widgets/euphire_button.dart';
import '../widgets/euphire_bottom_sheet.dart';
import '../widgets/euphire_card.dart';
import '../widgets/euphire_list_tile.dart';
import '../theme/euphire_theme.dart';
import 'client_details_screen.dart';
import '../providers/patient_provider.dart';
import '../widgets/add_patient_modal.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  void _showAddPatientModal(BuildContext context, WidgetRef ref) {
    showEuphireBottomSheet(
      context: context,
      builder: (context) => const AddPatientModal(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;
    final patients = ref.watch(patientsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Twoje kartoteki.'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: EuphireColors.mist),
            onPressed: () => FirebaseAuth.instance.signOut(),
            tooltip: 'Wyloguj się.',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EuphireHeader(
              title: 'Cześć.',
              subtitle: 'Twój email to ${user?.email ?? "Nieznany"}.',
            ),
            const SizedBox(height: 32),
            Text(
              'Ostatnie kartoteki.',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: patients.isEmpty 
                ? const Center(
                    child: Text(
                      'Brak kartotek. Dodaj nowego klienta.',
                      style: TextStyle(color: EuphireColors.mist),
                    ),
                  )
                : ListView.builder(
                itemCount: patients.length,
                itemBuilder: (context, index) {
                  final patient = patients[index];
                  return EuphireCard(
                    child: EuphireListTile(
                      title: '${patient.firstName} ${patient.lastName}',
                      subtitle: 'Liczba sesji: ${patient.sessionCount}',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ClientDetailsScreen(
                              patientId: patient.id,
                              clientName: '${patient.firstName} ${patient.lastName}',
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddPatientModal(context, ref),
        backgroundColor: EuphireColors.ember,
        foregroundColor: EuphireColors.obsidianBlack,
        child: const Icon(Icons.add),
      ),
    );
  }
}
