// Typed builders for cache box names and entry keys.
//
// Box names are therapist-scoped (`<entity>_v1__<therapistId>`) so a
// fresh therapist physically cannot open a previous therapist's box —
// belt-and-suspenders to the per-therapist AES key in cache_cipher.dart.
//
// Entry keys are therapist-scoped too (defense in depth — a bug that
// opens the wrong box still wouldn't return another therapist's row
// because keys won't match either).
//
// Schema version (`_v1`) is bumped when the DTO shape changes in a
// non-back-compat way; cache_manager wipes the old boxes on bump.

class CacheKeys {
  CacheKeys._();

  // Bumped 1 -> 2 (2026-06-01): patient e-mail + session custom-name read
  // mapping were added/fixed. Old cached PatientDto/SessionDto entries were
  // written before those fields were mapped, so they hold a stale empty
  // e-mail / default session name. Bumping the version abandons the v1 boxes
  // (cache_manager wipes them) so the first load after upgrade re-fetches
  // fresh rows that carry the e-mail and custom session titles.
  static const schemaVersion = 2;

  // ── Box names ──────────────────────────────────────────────────
  static String patientsBox(String therapistId) =>
      'patients_v$schemaVersion$_sep${_safe(therapistId)}';

  static String sessionsBox(String therapistId) =>
      'sessions_v$schemaVersion$_sep${_safe(therapistId)}';

  static String sessionDetailsBox(String therapistId) =>
      'session_details_v$schemaVersion$_sep${_safe(therapistId)}';

  static String metaBox(String therapistId) =>
      'cache_meta_v$schemaVersion$_sep${_safe(therapistId)}';

  /// All box names for a given therapist. cache_manager iterates this
  /// for open/close/clear operations.
  static List<String> allBoxesFor(String therapistId) => [
        patientsBox(therapistId),
        sessionsBox(therapistId),
        sessionDetailsBox(therapistId),
        metaBox(therapistId),
      ];

  // ── Entry keys ─────────────────────────────────────────────────
  /// PatientsBox holds a single entry — the full list for the therapist.
  /// We don't shard by patient because ListPatientFiles returns the
  /// whole set in one RPC and the UI binds to the list, not individual
  /// rows.
  static String patientsKey(String therapistId) => _safe(therapistId);

  /// SessionsBox: one entry per patient_file_id (the patient's session
  /// list). therapistId in the key is redundant with the box name but
  /// keeps the key human-readable in dev tooling.
  static String sessionsKey(String therapistId, String patientFileId) =>
      '${_safe(therapistId)}#${_safe(patientFileId)}';

  /// SessionDetailsBox: one entry per session_id.
  static String sessionDetailsKey(String therapistId, String sessionId) =>
      '${_safe(therapistId)}#${_safe(sessionId)}';

  // ── Helpers ────────────────────────────────────────────────────
  // Hive box names must be 1..255 chars and only certain ASCII; we
  // strip anything outside [A-Za-z0-9_-]. Firebase UIDs and UUIDs are
  // already safe, but defend against future identifier changes.
  static String _safe(String s) =>
      s.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');

  static const _sep = '__';
}
