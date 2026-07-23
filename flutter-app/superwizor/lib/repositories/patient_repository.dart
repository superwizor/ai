// PatientRepository — the cache-aware layer between PatientsNotifier
// (Riverpod) and the gRPC ClinicalService. Translates the proto
// PatientFile list into UI-facing Patient models and persists the
// intermediate PatientDto representation in the cache box keyed by
// therapist.
//
// Stale-while-revalidate contract:
//   getCached()         — pure cache read; returns CachedResult with
//                         a freshness flag. No network.
//   refresh()           — forces a network fetch, writes the result
//                         to cache, returns the fresh DTO list.
//   invalidate()        — drops the cache entry (used after deletes
//                         and on schema-version bumps).
//
// The sessionCount fan-out (one ListSessions RPC per patient) is
// preserved from the legacy provider behaviour — if this becomes a
// hot path we can either thread it through SessionRepository's
// cache or add a dedicated GetPatientStats RPC.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cache/cache_keys.dart';
import '../cache/cache_manager.dart';
import '../cache/cache_provider.dart';
import '../cache/dto/patient_dto.dart';
import '../generated/clinical/v1/clinical.pb.dart' as clinical_pb;
import '../generated/clinical/v1/clinical.pbgrpc.dart' as clinical_grpc;
import '../models/patient.dart';
import '../providers/current_user_provider.dart';
import '../providers/grpc_provider.dart';

/// Result envelope for cache reads. `data == null` means a complete
/// miss; `data != null && isStale` means cached-but-due-for-refresh.
class CachedResult<T> {
  final T? data;
  final DateTime? cachedAt;
  final bool isStale;

  const CachedResult({this.data, this.cachedAt, this.isStale = true});

  const CachedResult.miss()
      : data = null,
        cachedAt = null,
        isStale = true;

  bool get hasData => data != null;
  bool get isFresh => hasData && !isStale;
}

/// Function signature for the network-fetching half of the repository.
/// Extracted so tests can inject a fake without mocking the entire
/// gRPC ResponseFuture surface.
typedef PatientFetcher = Future<List<PatientDto>> Function();

class PatientRepository {
  PatientRepository({
    required CacheManager cache,
    required String therapistId,
    required PatientFetcher fetcher,
  })  : _cache = cache,
        _therapistId = therapistId,
        _fetcher = fetcher;

  /// Convenience constructor that wires the default gRPC-backed
  /// fetcher (with the legacy session-count fan-out).
  factory PatientRepository.fromGrpc({
    required CacheManager cache,
    required clinical_grpc.ClinicalServiceClient client,
    required String therapistId,
  }) {
    return PatientRepository(
      cache: cache,
      therapistId: therapistId,
      fetcher: () => _grpcFetch(client),
    );
  }

  final CacheManager _cache;
  final String _therapistId;
  final PatientFetcher _fetcher;

  /// Pure cache read. Never touches the network.
  Future<CachedResult<List<PatientDto>>> getCached() async {
    final box = _cache.patientsBox();
    final hit = await box.get(CacheKeys.patientsKey(_therapistId));
    if (hit == null) return const CachedResult.miss();
    return CachedResult(
      data: hit.data,
      cachedAt: hit.cachedAt,
      isStale: hit.isStale,
    );
  }

  /// Convenience for callers that just want UI models. Maps DTO → Patient
  /// in one pass. Returns null on cache miss.
  Future<CachedResult<List<Patient>>> getCachedAsModels() async {
    final r = await getCached();
    if (r.data == null) return const CachedResult.miss();
    return CachedResult(
      data: r.data!.map((d) => d.toModel()).toList(),
      cachedAt: r.cachedAt,
      isStale: r.isStale,
    );
  }

  /// Forces a network fetch, writes the result to cache, returns the
  /// fresh DTO list. Caller maps to UI models if needed.
  Future<List<PatientDto>> refresh() async {
    final dtos = await _fetcher();
    final box = _cache.patientsBox();
    await box.put(CacheKeys.patientsKey(_therapistId), dtos);
    // Patient list is small (~10s of KB). Skip enforceSizeCap here —
    // the heavier session_details writes are where the cap matters.
    return dtos;
  }

  Future<void> invalidate() async {
    final box = _cache.patientsBox();
    await box.delete(CacheKeys.patientsKey(_therapistId));
  }

  /// Hard-evict cascade for a deleted patient: drops the patient from
  /// the cached list, drops their session list, and drops every cached
  /// session_details entry whose Session.patientFileId matches. Use
  /// when the server confirms a DeletePatientUser/DeletePatientFile —
  /// the backend has cascaded the delete (sessions, transcripts,
  /// reports, audio_uploads), and the device must follow suit so we
  /// never serve cached PHI for a record the server says is gone.
  Future<void> evictPatient(String patientFileId) =>
      _cache.evictPatient(patientFileId);
}

// ── Default gRPC fetcher ─────────────────────────────────────────

Future<List<PatientDto>> _grpcFetch(
    clinical_grpc.ClinicalServiceClient client) async {
  // therapistId is decoded server-side from the JWT, so we send '' —
  // same as the legacy provider. The server still scopes by
  // authenticated user; the empty arg is just a placeholder.
  final res = await client.listPatientFiles(
    clinical_pb.ListPatientFilesRequest(therapistId: '', pageSize: 100),
  );

  // Fan out one ListSessions call per patient to compute session
  // counts. Same shape as the legacy code path; eagerError: false
  // so a single failing patient doesn't break the whole list.
  final counts = await Future.wait(
    res.patientFiles.map((pf) async {
      try {
        final sessRes = await client.listSessions(
          clinical_pb.ListSessionsRequest(patientFileId: pf.id),
        );
        return sessRes.sessions.length;
      } catch (e) {
        debugPrint('[patient-repo] listSessions failed for ${pf.id}: $e');
        return 0;
      }
    }),
    eagerError: false,
  );

  // docs/43 §4: working_alias is the only client identifier the app
  // consumes — the deprecated name fields are handled (as a last-resort
  // fallback for very old records) inside PatientDto.fromProto.
  return List<PatientDto>.generate(
    res.patientFiles.length,
    (i) => PatientDto.fromProto(res.patientFiles[i], sessionCount: counts[i]),
  );
}

/// Riverpod-wrapped repository. Returns null while the user is
/// unauthenticated or the cache is still opening — consumers should
/// fall back to a "loading" state during that brief window.
final patientRepositoryProvider =
    FutureProvider<PatientRepository?>((ref) async {
  final therapistId = await ref.watch(backendUserIdProvider.future);
  if (therapistId == null) return null;

  final mgr = await ref.watch(cacheManagerProvider.future);
  if (mgr == null) return null;

  final client = ref.watch(grpcClientsProvider).clinical;
  return PatientRepository.fromGrpc(
    cache: mgr,
    client: client,
    therapistId: therapistId,
  );
});
