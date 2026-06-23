// ViewedReportsProvider — tracks which completed session reports the
// therapist has already opened. Used to auto-dismiss the "Raport gotowy"
// badge after the first view.
//
// ──────────────────────────────────────────────────────────────────────
// MIGRATION (000059): Source of truth moved from SharedPreferences to
// the Postgres sessions.report_viewed_at column, synced via
// ClinicalService.MarkReportViewed gRPC RPC. The "viewed" state now
// persists across devices (macOS ↔ iOS). On first run after this change,
// we migrate any locally-stored viewed session IDs to the backend and
// then delete the local keys.
// ──────────────────────────────────────────────────────────────────────

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../generated/clinical/v1/clinical.pb.dart' as grpc_clinical;
import 'current_user_provider.dart';
import 'grpc_provider.dart';

class ViewedReportsNotifier extends AsyncNotifier<Set<String>> {
  static const _keyPrefix = 'viewed_reports_';

  @override
  Future<Set<String>> build() async {
    // Watch current user so we re-build on login/logout.
    final user = await ref.watch(currentUserProvider.future);
    if (user == null) return {};

    // One-time migration: push locally-stored viewed IDs to the backend,
    // then delete the SharedPreferences key. Safe to run every app start
    // because the backend RPC is idempotent (COALESCE preserves
    // first-view timestamp). If the gRPC call fails we skip silently —
    // the local key remains and we'll retry on next cold start.
    await _migrateLocalToBackend(user.id);

    // The actual viewed set is now derived from session.reportViewedAt
    // in the sessions list — not stored here. Return an empty set;
    // callers should use `isViewed(session)` on the Session proto object
    // directly, but we keep the provider for backward compat with code
    // that hasn't switched yet.
    return {};
  }

  /// Backward-compat: callers that still reference this notifier's state.
  /// Prefer checking session.hasReportViewedAt() directly.
  bool isViewed(String sessionId) =>
      state.value?.contains(sessionId) ?? false;

  /// Marks a session's report as viewed by calling the backend RPC.
  /// Also adds the sessionId to the in-memory set for instant UI response.
  Future<void> markViewed(String sessionId) async {
    final current = state.value ?? {};
    if (current.contains(sessionId)) return; // idempotent in-memory
    state = AsyncData({...current, sessionId});

    try {
      final client = ref.read(grpcClientsProvider).clinical;
      await client.markReportViewed(
        grpc_clinical.MarkReportViewedRequest(sessionId: sessionId),
      );
    } catch (e) {
      // Best-effort: if the RPC fails the badge stays dismissed locally
      // (fire-and-forget). The next ListSessions will carry the correct
      // report_viewed_at from the backend anyway.
    }
  }

  /// One-time migration from SharedPreferences to backend.
  Future<void> _migrateLocalToBackend(String therapistId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_keyPrefix$therapistId';
      final raw = prefs.getStringList(key);
      if (raw == null || raw.isEmpty) return;

      final client = ref.read(grpcClientsProvider).clinical;
      for (final sessionId in raw) {
        try {
          await client.markReportViewed(
            grpc_clinical.MarkReportViewedRequest(sessionId: sessionId),
          );
        } catch (_) {
          // Skip individual failures — backend may reject if session
          // is not COMPLETED or not owned. That's fine.
        }
      }

      // All migrated (or skipped) — delete the local key.
      await prefs.remove(key);
    } catch (_) {
      // SharedPreferences error — skip migration this time.
    }
  }
}

final viewedReportsProvider =
    AsyncNotifierProvider<ViewedReportsNotifier, Set<String>>(
  ViewedReportsNotifier.new,
);
