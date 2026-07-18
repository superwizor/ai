import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/debug_flags.dart';
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
        // docs/43 §4: working_alias is the only client identifier.
        // Deprecated name fields serve only as a last-resort fallback
        // for very old records that predate the alias requirement.
        final alias = pf.workingAlias.isNotEmpty
            ? pf.workingAlias
            : '${pf.patientFirstName} ${pf.patientLastName}'.trim();
        return Patient(
          id: pf.id,
          workingAlias: alias,
          modalityCode: pf.modalityCode,
          languageCode: pf.patientLanguageCode,
          sessionCount: 0, // skip the fan-out in the fallback path
          email: pf.patientEmail,
          lifecycleStatus: pf.lifecycleStatus.isNotEmpty ? pf.lifecycleStatus : 'ACTIVE',
        );
      }).toList();
    } catch (e) {
      debugPrint('[patients] direct fetch fallback failed: $e');
      return const [];
    }
  }

  Future<void> addPatient({
    required String alias,
    String modalityCode = 'UNIV',
    String languageCode = 'pl-PL',
  }) async {
    final client = ref.read(grpcClientsProvider).clinical;
    // docs/43 §4: the kartoteka is pseudonymous — no names, no e-mail.
    // The backend ignores the deprecated patient_first_name /
    // patient_last_name / patient_email fields, so we no longer send
    // them. The client e-mail lives exclusively in the invite flow
    // (client_invite_sheet → InviteClient).
    final req = grpc_clinical.CreatePatientFileRequest(
      therapistId: '', // zdekodowane na backendzie z tokenu
      workingAlias: alias,
      modalityCode: modalityCode,
      processType: grpc_clinical.ProcessType.PROCESS_TYPE_INDIVIDUAL,
      hasRecordingConsent: true,
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

  /// Renames the kartoteka's working alias (docs/43 §4 — the alias is
  /// the only editable client identifier). Goes through
  /// UpdatePatientFile; the server COALESCEs unset fields, so sending
  /// only working_alias leaves lifecycle_status etc. untouched.
  Future<void> updatePatientAlias(
    String patientFileId,
    String workingAlias,
  ) async {
    final client = ref.read(grpcClientsProvider).clinical;
    try {
      await client.updatePatientFile(grpc_clinical.UpdatePatientFileRequest(
        patientFileId: patientFileId,
        workingAlias: workingAlias,
      ));
      await _refreshAndPublish();
    } catch (e) {
      debugPrint('Error updating patient alias: $e');
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

  /// Network refresh + state publish, for callers OUTSIDE this notifier
  /// (upload-queue callbacks). A bare repository.refresh() updates the
  /// Hive cache but leaves this provider's in-memory state — the thing
  /// the home-list tiles actually watch (sessionCount!) — untouched
  /// until the next invalidate/app restart. That was the "ilość sesji
  /// nie jest zaktualizowana" bug (2026-07-18).
  Future<void> forceRefresh() => _refreshAndPublish();
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
          // modality is a patient_file attribute — don't derive from
          // session.name (which is either NULL or a user-set rename).
          modality: 'Rozmowa',
          // Read the server name into Session.name so renames persist on
          // refresh (mirrors SessionDto.toModel — keep in sync).
          name: s.name.isNotEmpty ? s.name : null,
          date: s.createdAt.toDateTime().toLocal(),
          duration: Duration(seconds: s.durationSeconds),
          sessionNumber: s.sessionNumber,
          status: s.status == 'PENDING_UPLOAD'
              ? SessionStatus.pendingUpload
              : s.status == 'COMPLETED'
              ? SessionStatus.completed
              : (s.status == 'FAILED' || s.status == 'ERROR')
              ? SessionStatus.error
              : SessionStatus.inProgress,
          // report_viewed_at (migration 000059): carry the backend-synced
          // timestamp so home_screen can determine badge state without
          // relying on local SharedPreferences.
          reportViewedAt: s.hasReportViewedAt()
              ? s.reportViewedAt.toDateTime().toLocal()
              : null,
          sharedWithClientAt: s.hasSharedWithClientAt()
              ? s.sharedWithClientAt.toDateTime().toLocal()
              : null,
        );
      }).toList();
      _publish(patientId, fetched);
    } catch (e) {
      debugPrint('[sessions] direct fetch fallback failed: $e');
    }
  }

  void _publish(String patientId, List<Session> sessions) {
    final current = state.whenOrNull(data: (d) => d) ?? {};

    // In debug mode, preserve any injected debug sessions so that
    // background SWR refreshes don't clobber the simulation.
    List<Session> merged = sessions;
    if (kDebugMode || DebugFlags.simulationsEnabled) {
      final oldSessions = current[patientId] ?? [];
      final debugSessions =
          oldSessions.where((s) => s.id.startsWith('debug-')).toList();
      if (debugSessions.isNotEmpty) {
        // Prepend debug sessions (they appear at the top)
        merged = [...debugSessions, ...sessions];
      }
    }

    state = AsyncValue.data({...current, patientId: merged});
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
    // Debug sessions exist only in local state — skip server call.
    if ((kDebugMode || DebugFlags.simulationsEnabled) && sessionId.startsWith('debug-')) {
      debugRemoveSession(patientId, sessionId);
      return;
    }
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
    // Debug sessions exist only in local state — skip server call.
    if ((kDebugMode || DebugFlags.simulationsEnabled) && sessionId.startsWith('debug-')) {
      debugRemoveSession(patientId, sessionId);
      return;
    }
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
      // The local rename (optimistic state + cache) is already applied, so
      // the new title still shows and survives restart — but the SERVER
      // didn't accept it, so it won't survive a reinstall / other device.
      // Rethrow so the caller can surface that instead of silently
      // pretending the rename was saved.
      debugPrint('[rename] Server sync failed (local rename persisted): $e');
      rethrow;
    }
  }

  // ─── Debug-only state manipulation (tree-shaken in release) ──────

  /// Injects a fake session into the local state (no network call).
  /// Used by the debug panel to test badge rendering and status
  /// transitions without a real recording flow.
  void debugInjectSession({
    required String patientId,
    required String sessionId,
    required SessionStatus status,
    DateTime? date,
  }) {
    if (!kDebugMode && !DebugFlags.simulationsEnabled) return;
    final fake = Session(
      id: sessionId,
      patientId: patientId,
      modality: 'DEBUG',
      name: 'Debug session',
      date: date ?? DateTime.now(),
      duration: const Duration(minutes: 45),
      status: status,
    );
    final current = state.whenOrNull(data: (d) => d) ?? {};
    final sessions = current[patientId] ?? [];
    // Don't duplicate if same ID exists
    final filtered = sessions.where((s) => s.id != sessionId).toList();
    state = AsyncValue.data({
      ...current,
      patientId: [fake, ...filtered],
    });
    debugPrint('[debug] injected session $sessionId '
        'status=${status.name} for patient $patientId '
        '(total sessions now: ${filtered.length + 1})');
  }

  /// Transitions a debug session's status (e.g. inProgress → completed).
  void debugTransitionSession(String patientId, String sessionId,
      SessionStatus newStatus) {
    if (!kDebugMode && !DebugFlags.simulationsEnabled) return;
    final current = state.whenOrNull(data: (d) => d) ?? {};
    final sessions = current[patientId] ?? [];
    final updated = sessions.map((s) {
      if (s.id == sessionId) return s.copyWith(status: newStatus);
      return s;
    }).toList();
    state = AsyncValue.data({...current, patientId: updated});
    debugPrint('[debug] transitioned session $sessionId → ${newStatus.name}');
  }

  /// Removes a debug session from local state.
  void debugRemoveSession(String patientId, String sessionId) {
    if (!kDebugMode && !DebugFlags.simulationsEnabled) return;
    final current = state.whenOrNull(data: (d) => d) ?? {};
    final sessions = current[patientId] ?? [];
    state = AsyncValue.data({
      ...current,
      patientId: sessions.where((s) => s.id != sessionId).toList(),
    });
    debugPrint('[debug] removed session $sessionId');
  }
}
