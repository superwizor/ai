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
          email: pf.patientEmail,
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
    String email = '',
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
      // Persist the contact e-mail at create time (was previously dropped).
      patientEmail: email,
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

  Future<void> updatePatientUser(
    String patientFileId,
    String firstName,
    String lastName, {
    String? email,
  }) async {
    final client = ref.read(grpcClientsProvider).clinical;
    try {
      await client.updatePatientUser(grpc_clinical.UpdatePatientUserRequest(
        patientFileId: patientFileId,
        firstName: firstName,
        lastName: lastName,
        // Only set patient_email when the caller provided one. An empty
        // string clears it server-side (intentional when the field was
        // emptied); a null caller means "leave the e-mail alone".
        patientEmail: email,
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

    // Only the server delete can legitimately fail (auth, not-found,
    // backend error) — let that propagate so the UI surfaces it.
    try {
      await client.deleteSession(
          grpc_clinical.DeleteSessionRequest(sessionId: sessionId));
    } catch (e) {
      debugPrint('Error deleting session (server): $e');
      rethrow;
    }

    // Server delete succeeded. Evict the cached session_details — the
    // backend CASCADE-deleted transcripts/reports/audio_uploads
    // (migration 000012); a stale entry would render PHI for a session
    // that no longer exists.
    try {
      await _detailsRepo?.invalidate(sessionId);
    } catch (e) {
      debugPrint('deleteSession: details invalidate failed (ignored): $e');
    }

    // Reconcile the list from the SERVER (authoritative). This is the fix
    // for "delete does nothing": optimistic local removal could be undone
    // by a stale SWR cache re-read, leaving the row on screen. forceRefresh
    // bypasses the cached-read path and rewrites the cache from the server,
    // where the session is now gone.
    try {
      await forceRefresh(patientId);
    } catch (e) {
      debugPrint('deleteSession: post-delete refresh failed, '
          'falling back to optimistic removal: $e');
      final current = state.whenOrNull(data: (d) => d);
      if (current != null) {
        final sessions = current[patientId] ?? [];
        state = AsyncValue.data({
          ...current,
          patientId: sessions.where((s) => s.id != sessionId).toList(),
        });
      }
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
    // 1. Optimistic UI update — instant feedback
    void applyOptimistic() {
      final current = state.whenOrNull(data: (d) => d);
      if (current != null) {
        final sessions = current[patientId] ?? [];
        final updatedSessions = sessions.map((s) {
          if (s.id == sessionId) {
            return s.copyWith(name: newName);
          }
          return s;
        }).toList();
        state = AsyncValue.data({...current, patientId: updatedSessions});
      }
    }

    applyOptimistic();

    // 2. Persist in local cache (survives app restart)
    await _repo?.renameSessionLocally(patientId, sessionId, newName);

    // 3. Best-effort server sync (don't block UI or revert on failure)
    try {
      final client = ref.read(grpcClientsProvider).clinical;
      await client.updateSession(grpc_clinical.UpdateSessionRequest(
        sessionId: sessionId,
        name: newName,
      ));
      // 4. Re-apply after server round-trip: a concurrent forceRefresh
      //    may have overwritten the optimistic state with stale data
      //    from ListSessions (server eventual-consistency lag between
      //    UpdateSession and ListSessions). Re-stamp both cache and
      //    in-memory state so the correct name sticks.
      await _repo?.renameSessionLocally(patientId, sessionId, newName);
      applyOptimistic();
    } catch (e) {
      debugPrint('[rename] Server sync failed (local rename persisted): $e');
    }
  }
}
