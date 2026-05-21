// Cache-aware sessionDetails provider.
//
// Returns SessionDetailsDto instead of the raw GetSessionDetailsResponse
// proto so consumers don't depend on generated proto types — the DTO
// has the same field shape and round-trips cleanly through Hive.
//
// Stale-while-revalidate:
//   • fresh cache hit  → emit immediately, no network
//   • stale cache hit  → emit cached value; consumers see latest data
//                         on the next ref.invalidate() (after a mutation)
//                         or when Riverpod rebuilds the family entry
//   • cold cache       → block on network, write through
//
// Note: this provider is only consumed by SessionDetailsScreen. The
// other screens that need session details (transcript_screen,
// report_screen, session_status_screen) hit the repository directly
// — session_status_screen specifically must not cache because it
// polls for status transitions.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cache/dto/session_details_dto.dart';
import '../generated/clinical/v1/clinical.pb.dart' as clinical_pb;
import '../repositories/session_details_repository.dart';
import 'grpc_provider.dart';

final sessionDetailsProvider =
    FutureProvider.family<SessionDetailsDto, String>((ref, sessionId) async {
  final repo = await ref.watch(sessionDetailsRepositoryProvider.future);

  if (repo != null) {
    final cached = await repo.getCached(sessionId);
    if (cached.isFresh) return cached.data!;
    if (cached.hasData) {
      // Serve cached now; schedule a background refresh that will
      // re-invalidate this provider once the network round-trip
      // completes. Riverpod's family rebuilds the entry on
      // invalidate, picking up the freshly written cache.
      Future.microtask(() async {
        try {
          await repo.refresh(sessionId);
          ref.invalidateSelf();
        } catch (e) {
          debugPrint('[session-details] background refresh failed: $e');
        }
      });
      return cached.data!;
    }
    return repo.refresh(sessionId);
  }

  // Fallback: repo unavailable (cache still opening or user signed
  // out mid-rebuild). Hit gRPC directly and convert to DTO so the
  // return type is stable.
  final res = await ref.watch(grpcClientsProvider).clinical.getSessionDetails(
        clinical_pb.GetSessionDetailsRequest(sessionId: sessionId),
      );
  return SessionDetailsDto.fromProto(res);
});
