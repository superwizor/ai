import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/patient.dart';
import '../models/session.dart';
import '../repositories/patient_repository.dart';
import '../repositories/session_details_repository.dart';
import '../repositories/session_repository.dart';
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

      // Cascade-evict everything we cached for this patient: the
      // patient row, the session list, every session_details entry.
      // Done BEFORE refresh so the refresh writes a clean snapshot
      // and the UI never momentarily shows the deleted patient's
      // transcripts via a still-warm session_details cache.
      await _repo?.evictPatient(patientFileId);

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
  SessionRepository? _repo;
  SessionDetailsRepository? _detailsRepo;

  @override
  Future<Map<String, List<Session>>> build() async {
    // Same auth-tie as PatientsNotifier — invalidate session cache
    // on therapist switch so we don't show ex-user's sessions.
    final user = await ref.watch(firebaseUserProvider.future);
    if (user == null) return const {};
    _repo = await ref.watch(sessionRepositoryProvider.future);
    _detailsRepo = await ref.watch(sessionDetailsRepositoryProvider.future);
    return const {};
  }

  /// Loads sessions for a patient: returns a fresh cache hit immediately,
  /// or serves stale + refreshes in the background, or blocks on network
  /// when the cache is cold. The `Map<patientId, sessions>` shape is kept
  /// for backward compatibility with widgets that watch the whole map.
  Future<void> fetchSessions(String patientId) async {
    final repo = _repo;
    if (repo != null) {
      try {
        final cached = await repo.getCachedAsModels(patientId);

        // Serve cached (fresh or stale) immediately.
        if (cached.hasData) {
          _publish(patientId, cached.data!);

          // If stale, kick off a background refresh.
          if (cached.isStale) {
            _backgroundRefresh(patientId);
          }
          return;
        }

        // Cold cache — block on network, then publish.
        final fresh = await repo.refresh(patientId);
        _publish(patientId, fresh.map((d) => d.toModel()).toList());
        return;
      } catch (e) {
        debugPrint('[sessions] cache-aware fetch failed, '
            'falling back to direct gRPC: $e');
        // fall through to the legacy path
      }
    }

    // Fallback path — repo unavailable (cache still opening) or
    // refresh threw. Hits gRPC directly without caching.
    await _fetchDirectFallback(patientId);
  }

  void _backgroundRefresh(String patientId) async {
    final repo = _repo;
    if (repo == null) return;
    try {
      final fresh = await repo.refresh(patientId);
      _publish(patientId, fresh.map((d) => d.toModel()).toList());
    } catch (e) {
      debugPrint('[sessions] background refresh for $patientId failed: $e');
    }
  }

  /// Forces a network fetch (bypassing the SWR cached-read path) and
  /// republishes. Use this when correctness matters more than cache
  /// economy — typically on screen entry where a just-completed
  /// upload may not have survived the in-flight cache write.
  ///
  /// Context: `_refreshKartoteka` in upload_queue_provider.dart fires
  /// `onUploadComplete` to invalidate the Hive cache when a queued
  /// row transitions to `phase=completed`. That works when the user
  /// is on the screen at completion time. When the user is elsewhere
  /// (or the app is backgrounded) the cache write happens but the
  /// screen, on later entry, calls `fetchSessions` which serves
  /// whatever was in the cache — including the pre-completion list
  /// if the post-completion write got dropped (force-kill, race).
  ///
  /// Cost: one gRPC roundtrip per ClientDetailsScreen entry.
  /// Warm Cloud Run: ~50-100 ms. Cold: up to ~5s; UI shows cached
  /// stale data in the meantime so it's not user-visible latency.
  Future<void> forceRefresh(String patientId) async {
    final repo = _repo;
    if (repo != null) {
      try {
        final fresh = await repo.refresh(patientId);
        _publish(patientId, fresh.map((d) => d.toModel()).toList());
        return;
      } catch (e) {
        debugPrint(
            '[sessions] forceRefresh failed, falling back to direct gRPC: $e');
      }
    }
    await _fetchDirectFallback(patientId);
  }

  Future<void> _fetchDirectFallback(String patientId) async {
    final client = ref.read(grpcClientsProvider).clinical;
    try {
      final res = await client.listSessions(
        grpc_clinical.ListSessionsRequest(patientFileId: patientId),
      );
      final fetched = res.sessions.map((s) {
        return Session(
          id: s.id,
          patientId: s.patientFileId,
          modality: s.name.isNotEmpty ? s.name : 'Rozmowa',
          date: s.createdAt.toDateTime().toLocal(),
          duration: Duration(seconds: s.durationSeconds),
          status: s.status == 'PENDING_UPLOAD'
              ? SessionStatus.pendingUpload
              : s.status == 'COMPLETED'
              ? SessionStatus.completed
              : SessionStatus.inProgress,
        );
      }).toList();
      _publish(patientId, fetched);
    } catch (e) {
      debugPrint('[sessions] direct fetch fallback failed: $e');
    }
  }

  void _publish(String patientId, List<Session> sessions) {
    final current = state.whenOrNull(data: (d) => d) ?? {};
    state = AsyncValue.data({...current, patientId: sessions});
  }

  Future<void> addSession(Session session) async {
    final current = state.whenOrNull(data: (d) => d) ?? {};
    final patientSessions = current[session.patientId] ?? [];
    state = AsyncValue.data(
        {...current, session.patientId: [...patientSessions, session]});
    // Refresh from network in the background so the cache picks up
    // the server-canonical row (with proper session_number, status,
    // audio_upload_id, etc).
    _backgroundRefresh(session.patientId);
  }

  Future<void> deleteSession(String patientId, String sessionId) async {
    final client = ref.read(grpcClientsProvider).clinical;
    try {
      await client.deleteSession(
          grpc_clinical.DeleteSessionRequest(sessionId: sessionId));

      // Local optimistic update: drop the row from both the live
      // state and the cached DTO list. The cache mutation keeps
      // subsequent reads consistent without a refresh round-trip.
      await _repo?.removeSessionLocally(patientId, sessionId);

      // Also evict the cached session_details for this session — the
      // backend just CASCADE-deleted transcripts/reports/audio_uploads
      // (migration 000012); if we left the entry in cache, a stale
      // navigation back to it would render PHI for a session that no
      // longer exists server-side.
      await _detailsRepo?.invalidate(sessionId);

      final current = state.whenOrNull(data: (d) => d);
      if (current == null) return;
      final sessions = current[patientId] ?? [];
      final updatedSessions =
          sessions.where((s) => s.id != sessionId).toList();
      state = AsyncValue.data({...current, patientId: updatedSessions});
    } catch (e) {
      debugPrint('Error deleting session: $e');
      rethrow;
    }
  }

  /// User-initiated cancellation of an in-progress session
  /// (feat/tokens-exhausted). Used when the therapist cancels a
  /// quota-parked upload (or any pre-completion session) from the
  /// "Wgrywanie" / "Bezpieczna analiza w toku" screens. The server
  /// flips status to CANCELLED_BY_USER, releases the held token, and
  /// hides the row from ListSessions — so locally we just drop it,
  /// mirroring deleteSession. Unlike delete this is NOT a RODO erase:
  /// the row survives server-side for audit.
  Future<void> cancelSession(String patientId, String sessionId) async {
    final client = ref.read(grpcClientsProvider).clinical;
    try {
      await client.cancelSession(
          grpc_clinical.CancelSessionRequest(sessionId: sessionId));

      await _repo?.removeSessionLocally(patientId, sessionId);
      await _detailsRepo?.invalidate(sessionId);

      final current = state.whenOrNull(data: (d) => d);
      if (current == null) return;
      final sessions = current[patientId] ?? [];
      final updatedSessions =
          sessions.where((s) => s.id != sessionId).toList();
      state = AsyncValue.data({...current, patientId: updatedSessions});
    } catch (e) {
      debugPrint('Error cancelling session: $e');
      rethrow;
    }
  }

  Future<void> renameSession(
      String patientId, String sessionId, String newName) async {
    final client = ref.read(grpcClientsProvider).clinical;
    try {
      await client.updateSession(grpc_clinical.UpdateSessionRequest(
        sessionId: sessionId,
        name: newName,
      ));

      await _repo?.renameSessionLocally(patientId, sessionId, newName);

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
