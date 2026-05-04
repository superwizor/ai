import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/patient.dart';
import '../models/session.dart';
import 'grpc_provider.dart';
import '../generated/clinical/v1/clinical.pb.dart' as grpc_clinical;

final patientsProvider = AsyncNotifierProvider<PatientsNotifier, List<Patient>>(() {
  return PatientsNotifier();
});

class PatientsNotifier extends AsyncNotifier<List<Patient>> {
  @override
  Future<List<Patient>> build() async {
    return _fetchPatients();
  }

  Future<List<Patient>> _fetchPatients() async {
    final client = ref.read(grpcClientsProvider).clinical;
    try {
      final req = grpc_clinical.ListPatientFilesRequest(therapistId: '', pageSize: 100);
      final res = await client.listPatientFiles(req);
      
      return res.patientFiles.map((pf) {
        final names = pf.workingAlias.split(' ');
        final firstName = names.isNotEmpty ? names.first : 'Nieznany';
        final lastName = names.length > 1 ? names.sublist(1).join(' ') : '';
        
        return Patient(
          id: pf.id,
          firstName: firstName,
          lastName: lastName,
          sessionCount: 0,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error fetching patients: $e');
      return [];
    }
  }

  Future<void> addPatient(String firstName, String lastName) async {
    final client = ref.read(grpcClientsProvider).clinical;
    final req = grpc_clinical.CreatePatientFileRequest(
      therapistId: '', // zdekodowane na backendzie z tokenu
      workingAlias: '$firstName $lastName'.trim(),
      modalityCode: 'CBT', // default
      processType: grpc_clinical.ProcessType.PROCESS_TYPE_INDIVIDUAL,
      hasRecordingConsent: true,
    );
    
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await client.createPatientFile(req);
      return _fetchPatients();
    });
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
    return {};
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
          modality: 'Rozmowa', // tymczasowy fallback, póki backend tego nie wydzieli
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
}
