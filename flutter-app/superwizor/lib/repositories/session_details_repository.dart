// SessionDetailsRepository — cache-aware layer for
// ClinicalService.GetSessionDetails. Stores the composite
// {session, transcript, reports} response per session_id.
//
// Box: CacheKeys.sessionDetailsBox(therapistId)
// Key per row: CacheKeys.sessionDetailsKey(therapistId, sessionId)
// Soft TTL: 1h    (reports can be re-rated; transcripts immutable
//                  but the wrapper Session.status mutates as the
//                  pipeline finishes — short TTL keeps it close to live)
// Hard TTL: 30d
//
// This is the heavy box — a 60-minute session typically lands at
// 50–300 KB after transcript + reports JSON encoding. Each refresh()
// calls cacheManager.enforceSizeCap() so growth stays bounded at 300 MB
// across all three domain boxes.
//
// Retires the legacy TranscriptCacheStore, which only cached the
// transcript half with a 1-hour staleness check. The new repo stores
// the full response (transcript + reports + session metadata) which
// is what the consumer screens actually need.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cache/cache_keys.dart';
import '../cache/cache_manager.dart';
import '../cache/cache_provider.dart';
import '../cache/dto/session_details_dto.dart';
import '../generated/clinical/v1/clinical.pb.dart' as clinical_pb;
import '../generated/clinical/v1/clinical.pbgrpc.dart' as clinical_grpc;
import '../providers/current_user_provider.dart';
import '../providers/grpc_provider.dart';
import 'patient_repository.dart' show CachedResult;

typedef SessionDetailsFetcher = Future<SessionDetailsDto> Function(
    String sessionId);

class SessionDetailsRepository {
  SessionDetailsRepository({
    required CacheManager cache,
    required String therapistId,
    required SessionDetailsFetcher fetcher,
  })  : _cache = cache,
        _therapistId = therapistId,
        _fetcher = fetcher;

  factory SessionDetailsRepository.fromGrpc({
    required CacheManager cache,
    required clinical_grpc.ClinicalServiceClient client,
    required String therapistId,
  }) {
    return SessionDetailsRepository(
      cache: cache,
      therapistId: therapistId,
      fetcher: (sessionId) => _grpcFetch(client, sessionId),
    );
  }

  final CacheManager _cache;
  final String _therapistId;
  final SessionDetailsFetcher _fetcher;

  Future<CachedResult<SessionDetailsDto>> getCached(String sessionId) async {
    final box = _cache.sessionDetailsBox();
    final hit = await box.get(
        CacheKeys.sessionDetailsKey(_therapistId, sessionId));
    if (hit == null) return const CachedResult.miss();
    return CachedResult(
      data: hit.data,
      cachedAt: hit.cachedAt,
      isStale: hit.isStale,
    );
  }

  Future<SessionDetailsDto> refresh(String sessionId) async {
    final dto = await _fetcher(sessionId);
    final box = _cache.sessionDetailsBox();
    await box.put(
        CacheKeys.sessionDetailsKey(_therapistId, sessionId), dto);
    // Session details are the bulk of cache usage (50–300 KB per
    // entry). Enforce the global 300 MB cap after every write so
    // long-running installs don't grow unbounded.
    await _cache.enforceSizeCap();
    return dto;
  }

  Future<void> invalidate(String sessionId) async {
    final box = _cache.sessionDetailsBox();
    await box.delete(
        CacheKeys.sessionDetailsKey(_therapistId, sessionId));
  }
}

// ── Default gRPC fetcher ─────────────────────────────────────────

Future<SessionDetailsDto> _grpcFetch(
  clinical_grpc.ClinicalServiceClient client,
  String sessionId,
) async {
  try {
    final res = await client.getSessionDetails(
      clinical_pb.GetSessionDetailsRequest(sessionId: sessionId),
    );
    return SessionDetailsDto.fromProto(res);
  } catch (e) {
    debugPrint('[session-details-repo] getSessionDetails failed '
        'for $sessionId: $e');
    rethrow;
  }
}

final sessionDetailsRepositoryProvider =
    FutureProvider<SessionDetailsRepository?>((ref) async {
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) return null;

  final mgr = await ref.watch(cacheManagerProvider.future);
  if (mgr == null) return null;

  final client = ref.watch(grpcClientsProvider).clinical;
  return SessionDetailsRepository.fromGrpc(
    cache: mgr,
    client: client,
    therapistId: user.id,
  );
});
