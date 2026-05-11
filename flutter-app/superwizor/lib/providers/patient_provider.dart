import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/modalities.dart';
import '../models/patient.dart';
import '../models/session.dart';
import 'current_user_provider.dart';
import 'grpc_provider.dart';
import 'services_provider.dart';
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

      // Look up the local UI-modality cache for all patients at once.
      // The cache fills in the user's original UI choice (one of 8
      // modalities) that the backend collapsed into UNIV/CBT/PSYCHO.
      final modalityCache = ref.read(patientModalityCacheProvider);
      final cachedUiCodes = await modalityCache.lookupMany(
        res.patientFiles.map((pf) => pf.id),
      );

      return List.generate(res.patientFiles.length, (i) {
        final pf = res.patientFiles[i];
        final names = pf.workingAlias.split(' ');
        final firstName = names.isNotEmpty ? names.first : 'Nieznany';
        final lastName = names.length > 1 ? names.sublist(1).join(' ') : '';
        // Priority: local UI cache > backend modality_code > UNIV.
        // The backend currently returns empty modality_code on
        // ListPatientFiles (TODO in clinical-svc/server.go); even
        // after that's fixed, the 6 collapsed UI modalities can't
        // be recovered server-side, so this cache remains the
        // authoritative source of the therapist's specific choice.
        final cached = cachedUiCodes[pf.id];
        final modalityCode = cached != null
            ? uiToBackendModalityCode(cached)
            : (pf.modalityCode.isNotEmpty ? pf.modalityCode : 'UNIV');
        return Patient(
          id: pf.id,
          firstName: firstName,
          lastName: lastName,
          sessionCount: counts[i],
          modalityCode: modalityCode,
          uiModalityCode: cached ?? backendToUiModalityCode(modalityCode),
        );
      });
    } catch (e) {
      debugPrint('Error fetching patients: $e');
      return [];
    }
  }

  /// Creates a new kartoteka. The [modalityUiCode] is the Flutter
  /// UI code (e.g. 'cbt', 'integrative') — mapped to the backend's
  /// system_code via [uiToBackendModalityCode] before the gRPC call.
  Future<void> addPatient(
    String firstName,
    String lastName, {
    required String modalityUiCode,
  }) async {
    final client = ref.read(grpcClientsProvider).clinical;
    final req = grpc_clinical.CreatePatientFileRequest(
      therapistId: '', // resolved server-side from JWT
      workingAlias: '$firstName $lastName'.trim(),
      modalityCode: uiToBackendModalityCode(modalityUiCode),
      processType: grpc_clinical.ProcessType.PROCESS_TYPE_INDIVIDUAL,
      hasRecordingConsent: true,
    );

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final created = await client.createPatientFile(req);
      // Persist the user's UI choice locally so subsequent fetches
      // can display the specific picked modality (e.g. "Schema")
      // rather than the backend-collapsed bucket ("Integratywne").
      await ref.read(patientModalityCacheProvider).remember(
            patientFileId: created.id,
            uiCode: modalityUiCode,
          );
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
