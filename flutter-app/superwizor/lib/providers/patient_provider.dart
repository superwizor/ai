import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/patient.dart';
import '../models/session.dart';
import '../repositories/patient_repository.dart';
import 'current_user_provider.dart';
import 'grpc_provider.dart';
import '../generated/clinical/v1/clinical.pb.dart' as grpc_clinical;

final patientsProvider = AsyncNotifierProvider<PatientsNotifier, List<Patient>>(() {
  return PatientsNotifier();
});

class PatientsNotifier extends AsyncNotifier<List<Patient>> {
  PatientRepository? _repo;

  @override
  Future<List<Patient>> build() async {
    // Tie the patient list to the currently authenticated Firebase
    // user. When the user logs out + a different therapist logs in,
    // this watch sees the new uid and Riverpod rebuilds — the old
    // therapist's cached patients vanish. Without this, the home
    // screen showed stale data across login transitions.
    final user = await ref.watch(firebaseUserProvider.future);
    if (user == null) return const [];

    // Repository wraps the cache + gRPC client. Null while the cache
    // is still opening — fall back to a direct network fetch in that
    // window (rare; <100ms on a warm Hive).
    final repo = await ref.watch(patientRepositoryProvider.future);
    _repo = repo;
    if (repo == null) {
      return _fetchDirectFallback();
    }

    final cached = await repo.getCachedAsModels();

    // Fresh cache hit — return immediately, no network.
    if (cached.isFresh) {
      return cached.data!;
    }

    // Stale cache hit — serve cached for instant UI, kick off a
    // background refresh that updates state once it lands.
    if (cached.hasData) {
      _backgroundRefresh();
      return cached.data!;
    }

    // Cold cache — block on network.
    final fresh = await repo.refresh();
    return fresh.map((d) => d.toModel()).toList();
  }

  void _backgroundRefresh() async {
    final repo = _repo;
    if (repo == null) return;
    try {
      final fresh = await repo.refresh();
      state = AsyncValue.data(fresh.map((d) => d.toModel()).toList());
    } catch (e) {
      debugPrint('[patients] background refresh failed: $e');
      // Keep showing the stale cached data — don't surface this as
      // an error to the UI. Network will retry on next provider rebuild.
    }
  }

  // Used only during the cache-warming window or if the repository
  // is unavailable for any reason. Skips the cache write — next
  // rebuild will populate it.
  Future<List<Patient>> _fetchDirectFallback() async {
    final client = ref.read(grpcClientsProvider).clinical;
    try {
      final res = await client.listPatientFiles(
        grpc_clinical.ListPatientFilesRequest(therapistId: '', pageSize: 100),
      );
      return res.patientFiles.map((pf) {
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
          languageCode: pf.patientLanguageCode,
          sessionCount: 0, // skip the fan-out in the fallback path
        );
      }).toList();
    } catch (e) {
      debugPrint('[patients] direct fetch fallback failed: $e');
      return const [];
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
      await _refreshAndPublish();
    } catch (e) {
      await _refreshAndPublish();
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
      await _refreshAndPublish();
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
      await _refreshAndPublish();
    } catch (e) {
      debugPrint('Error deleting patient: $e');
      rethrow;
    }
  }

  /// Re-fetches via the repository (which writes the fresh list to
  /// cache) and publishes the result. Used by every mutation path so
  /// the cache never diverges from the canonical server view.
  Future<void> _refreshAndPublish() async {
    final repo = _repo;
    if (repo == null) {
      state = AsyncValue.data(await _fetchDirectFallback());
      return;
    }
    final fresh = await repo.refresh();
    state = AsyncValue.data(fresh.map((d) => d.toModel()).toList());
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
