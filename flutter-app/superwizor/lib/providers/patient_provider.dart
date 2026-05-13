import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/patient.dart';
import '../models/session.dart';
import 'current_user_provider.dart';
import 'grpc_provider.dart';
import '../generated/clinical/v1/clinical.pb.dart' as grpc_clinical;

final patientsProvider = AsyncNotifierProvider<PatientsNotifier, List<Patient>>(() {
  return PatientsNotifier();
});

class PatientsNotifier extends AsyncNotifier<List<Patient>> {
  @override
  Future<List<Patient>> build() async {
    // Tie the patient list to the currently authenticated Firebase
    // user. When the user logs out + a different therapist logs in,
    // this watch sees the new uid and Riverpod rebuilds — the old
    // therapist's cached patients vanish. Without this, the home
    // screen showed stale data across login transitions.
    final user = await ref.watch(firebaseUserProvider.future);
    if (user == null) return const [];
    return _fetchPatients();
  }

  Future<List<Patient>> _fetchPatients() async {
    final client = ref.read(grpcClientsProvider).clinical;
    try {
      final req = grpc_clinical.ListPatientFilesRequest(therapistId: '', pageSize: 100);
      final res = await client.listPatientFiles(req);

      // Backend's PatientFile proto doesn't expose sessionCount, so we
      // fan out one ListSessions per patient in parallel. Cheap for the
      // tens-of-patients scale we expect; if this ever slows down we'll
      // add a count to the proto / a dedicated GetPatientStats RPC.
      final counts = await Future.wait(
        res.patientFiles.map((pf) async {
          try {
            final sessRes = await client.listSessions(
              grpc_clinical.ListSessionsRequest(patientFileId: pf.id),
            );
            return sessRes.sessions.length;
          } catch (e) {
            debugPrint('listSessions failed for ${pf.id}: $e');
            return 0;
          }
        }),
        eagerError: false,
      );

      return List.generate(res.patientFiles.length, (i) {
        final pf = res.patientFiles[i];
        
        String firstName = pf.patientFirstName;
        String lastName = pf.patientLastName;
        
        if (firstName.isEmpty && lastName.isEmpty && pf.workingAlias.isNotEmpty) {
          final names = pf.workingAlias.split(' ');
          firstName = names.isNotEmpty ? names.first : 'Nieznany';
          lastName = names.length > 1 ? names.sublist(1).join(' ') : '';
        } else if (firstName.isEmpty) {
          firstName = 'Nieznany';
        }

        return Patient(
          id: pf.id,
          firstName: firstName,
          lastName: lastName,
          modalityCode: pf.modalityCode,
          sessionCount: counts[i],
        );
      });
    } catch (e) {
      debugPrint('Error fetching patients: $e');
      return [];
    }
  }

  Future<void> addPatient({
    required String alias,
    required String firstName,
    String lastName = '',
    String modalityCode = 'UNIV',
    String languageCode = 'pl-PL',
  }) async {
    final client = ref.read(grpcClientsProvider).clinical;
    final req = grpc_clinical.CreatePatientFileRequest(
      therapistId: '', // zdekodowane na backendzie z tokenu
      workingAlias: alias,
      modalityCode: modalityCode,
      processType: grpc_clinical.ProcessType.PROCESS_TYPE_INDIVIDUAL,
      hasRecordingConsent: true,
      patientFirstName: firstName,
      patientLastName: lastName,
      patientLanguageCode: languageCode,
    );
    
    state = const AsyncValue.loading();
    try {
      await client.createPatientFile(req);
      state = AsyncValue.data(await _fetchPatients());
    } catch (e) {
      state = AsyncValue.data(await _fetchPatients());
      rethrow;
    }
  }

  Future<void> updatePatientUser(String patientFileId, String firstName, String lastName) async {
    final client = ref.read(grpcClientsProvider).clinical;
    try {
      await client.updatePatientUser(grpc_clinical.UpdatePatientUserRequest(
        patientFileId: patientFileId,
        firstName: firstName,
        lastName: lastName,
      ));
      state = AsyncValue.data(await _fetchPatients());
    } catch (e) {
      debugPrint('Error updating patient: $e');
      rethrow;
    }
  }

  Future<void> deletePatientUser(String patientFileId) async {
    final client = ref.read(grpcClientsProvider).clinical;
    try {
      await client.deletePatientUser(grpc_clinical.DeletePatientUserRequest(
        patientFileId: patientFileId,
      ));
      state = AsyncValue.data(await _fetchPatients());
    } catch (e) {
      debugPrint('Error deleting patient: $e');
      rethrow;
    }
  }

  void incrementSessionCount(String patientId) {
    final current = state.whenOrNull(data: (d) => d);
    if (current != null) {
      state = AsyncValue.data(current.map((p) {
        if (p.id == patientId) {
          return p.copyWith(sessionCount: p.sessionCount + 1);
        }
        return p;
      }).toList());
    }
  }
}

final sessionsProvider = AsyncNotifierProvider<SessionsNotifier, Map<String, List<Session>>>(() {
  return SessionsNotifier();
});

class SessionsNotifier extends AsyncNotifier<Map<String, List<Session>>> {
  @override
  Future<Map<String, List<Session>>> build() async {
    // Same auth-tie as PatientsNotifier — invalidate session cache
    // on therapist switch so we don't show ex-user's sessions.
    final user = await ref.watch(firebaseUserProvider.future);
    if (user == null) return const {};
    return const {};
  }

  Future<void> fetchSessions(String patientId) async {
    final client = ref.read(grpcClientsProvider).clinical;
    try {
      final req = grpc_clinical.ListSessionsRequest(patientFileId: patientId);
      final res = await client.listSessions(req);
      
      final fetched = res.sessions.map((s) {
        return Session(
          id: s.id,
          patientId: s.patientFileId,
          modality: s.name.isNotEmpty ? s.name : 'Rozmowa', // zaktualizowane z backendu
          date: s.createdAt.toDateTime().toLocal(),
          duration: Duration(seconds: s.durationSeconds),
          status: s.status == 'COMPLETED' ? SessionStatus.completed : SessionStatus.inProgress,
        );
      }).toList();

      final current = state.whenOrNull(data: (d) => d) ?? {};
      state = AsyncValue.data({...current, patientId: fetched});
    } catch (e) {
      debugPrint('Error fetching sessions: $e');
    }
  }

  Future<void> addSession(Session session) async {
    final current = state.whenOrNull(data: (d) => d) ?? {};
    final patientSessions = current[session.patientId] ?? [];
    state = AsyncValue.data({...current, session.patientId: [...patientSessions, session]});
  }

  Future<void> deleteSession(String patientId, String sessionId) async {
    final client = ref.read(grpcClientsProvider).clinical;
    try {
      await client.deleteSession(grpc_clinical.DeleteSessionRequest(sessionId: sessionId));
      
      final current = state.whenOrNull(data: (d) => d);
      if (current == null) return;
      
      final sessions = current[patientId] ?? [];
      final updatedSessions = sessions.where((s) => s.id != sessionId).toList();
      
      state = AsyncValue.data({...current, patientId: updatedSessions});
    } catch (e) {
      debugPrint('Error deleting session: $e');
      rethrow;
    }
  }

  Future<void> renameSession(String patientId, String sessionId, String newName) async {
    final client = ref.read(grpcClientsProvider).clinical;
    try {
      await client.updateSession(grpc_clinical.UpdateSessionRequest(
        sessionId: sessionId,
        name: newName,
      ));

      final current = state.whenOrNull(data: (d) => d);
      if (current == null) return;
      
      final sessions = current[patientId] ?? [];
      final updatedSessions = sessions.map((s) {
        if (s.id == sessionId) {
          return s.copyWith(modality: newName);
        }
        return s;
      }).toList();
      
      state = AsyncValue.data({...current, patientId: updatedSessions});
    } catch (e) {
      debugPrint('Error renaming session: $e');
      rethrow;
    }
  }
}
