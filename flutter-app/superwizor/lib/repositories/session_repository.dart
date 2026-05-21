// SessionRepository — the cache-aware layer for per-patient session
// lists (ClinicalService.ListSessions). Same shape as
// PatientRepository but sharded by patient_file_id instead of a
// single therapist-wide entry.
//
// Box: CacheKeys.sessionsBox(therapistId)
// Key per row: CacheKeys.sessionsKey(therapistId, patientFileId)
// Soft TTL: 1h (sessions list changes when a new session lands or a
//           rename happens — short TTL so it stays close to live)
// Hard TTL: 30d
//
// The DTO list is small (~200 bytes per session × ~10 sessions per
// patient → ~2 KB per patient). Skipping size-cap enforcement here
// for the same reason as PatientRepository — these aren't the LRU
// hot path; session_details is.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cache/cache_keys.dart';
import '../cache/cache_manager.dart';
import '../cache/cache_provider.dart';
import '../cache/dto/session_dto.dart';
import '../generated/clinical/v1/clinical.pb.dart' as clinical_pb;
import '../generated/clinical/v1/clinical.pbgrpc.dart' as clinical_grpc;
import '../models/session.dart';
import '../providers/current_user_provider.dart';
import '../providers/grpc_provider.dart';
import 'patient_repository.dart' show CachedResult;

/// Function signature for the network half — `(patientFileId) → DTO list`.
/// Tests inject a fake; production wires the real gRPC client.
typedef SessionFetcher = Future<List<SessionDto>> Function(String patientFileId);

class SessionRepository {
  SessionRepository({
    required CacheManager cache,
    required String therapistId,
    required SessionFetcher fetcher,
  })  : _cache = cache,
        _therapistId = therapistId,
        _fetcher = fetcher;

  factory SessionRepository.fromGrpc({
    required CacheManager cache,
    required clinical_grpc.ClinicalServiceClient client,
    required String therapistId,
  }) {
    return SessionRepository(
      cache: cache,
      therapistId: therapistId,
      fetcher: (patientFileId) => _grpcFetch(client, patientFileId),
    );
  }

  final CacheManager _cache;
  final String _therapistId;
  final SessionFetcher _fetcher;

  /// Pure cache read for a patient's session list. Never touches
  /// the network.
  Future<CachedResult<List<SessionDto>>> getCached(String patientFileId) async {
    final box = _cache.sessionsBox();
    final hit = await box.get(CacheKeys.sessionsKey(_therapistId, patientFileId));
    if (hit == null) return const CachedResult.miss();
    return CachedResult(
      data: hit.data,
      cachedAt: hit.cachedAt,
      isStale: hit.isStale,
    );
  }

  /// Convenience: returns UI-facing Session models. Maps DTO → model
  /// using the same status-string-to-enum translation that the legacy
  /// provider used.
  Future<CachedResult<List<Session>>> getCachedAsModels(
      String patientFileId) async {
    final r = await getCached(patientFileId);
    if (r.data == null) return const CachedResult.miss();
    return CachedResult(
      data: r.data!.map((d) => d.toModel()).toList(),
      cachedAt: r.cachedAt,
      isStale: r.isStale,
    );
  }

  /// Forces a network fetch for the given patient, writes the result
  /// to cache, and returns the fresh DTO list.
  Future<List<SessionDto>> refresh(String patientFileId) async {
    final dtos = await _fetcher(patientFileId);
    final box = _cache.sessionsBox();
    await box.put(CacheKeys.sessionsKey(_therapistId, patientFileId), dtos);
    return dtos;
  }

  Future<void> invalidate(String patientFileId) async {
    final box = _cache.sessionsBox();
    await box.delete(CacheKeys.sessionsKey(_therapistId, patientFileId));
  }

  /// Local mutation: drop a session from the cached list without
  /// going through the network. Used after a successful DeleteSession
  /// RPC so the UI updates immediately and the next refresh confirms.
  Future<void> removeSessionLocally(
      String patientFileId, String sessionId) async {
    final box = _cache.sessionsBox();
    final key = CacheKeys.sessionsKey(_therapistId, patientFileId);
    final hit = await box.get(key);
    if (hit == null) return;
    final remaining = hit.data.where((s) => s.id != sessionId).toList();
    await box.put(key, remaining);
  }

  /// Local mutation: rename a session in the cached list. Same
  /// rationale as removeSessionLocally — keep UI tight, let the next
  /// background refresh confirm.
  Future<void> renameSessionLocally(
      String patientFileId, String sessionId, String newName) async {
    final box = _cache.sessionsBox();
    final key = CacheKeys.sessionsKey(_therapistId, patientFileId);
    final hit = await box.get(key);
    if (hit == null) return;
    final updated = hit.data
        .map((s) => s.id == sessionId
            ? SessionDto(
                id: s.id,
                patientFileId: s.patientFileId,
                name: newName,
                contactForm: s.contactForm,
                durationSeconds: s.durationSeconds,
                createdAt: s.createdAt,
                status: s.status,
                sessionNumber: s.sessionNumber,
                audioUploadId: s.audioUploadId,
                speakerLabelMapping: s.speakerLabelMapping,
              )
            : s)
        .toList();
    await box.put(key, updated);
  }
}

// ── Default gRPC fetcher ─────────────────────────────────────────

Future<List<SessionDto>> _grpcFetch(
  clinical_grpc.ClinicalServiceClient client,
  String patientFileId,
) async {
  try {
    final res = await client.listSessions(
      clinical_pb.ListSessionsRequest(patientFileId: patientFileId),
    );
    return res.sessions.map(SessionDto.fromProto).toList();
  } catch (e) {
    debugPrint('[session-repo] listSessions failed for $patientFileId: $e');
    rethrow;
  }
}

/// Riverpod-wrapped repository. Returns null while the user is
/// unauthenticated or the cache is still opening.
final sessionRepositoryProvider =
    FutureProvider<SessionRepository?>((ref) async {
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) return null;

  final mgr = await ref.watch(cacheManagerProvider.future);
  if (mgr == null) return null;

  final client = ref.watch(grpcClientsProvider).clinical;
  return SessionRepository.fromGrpc(
    cache: mgr,
    client: client,
    therapistId: user.id,
  );
});
