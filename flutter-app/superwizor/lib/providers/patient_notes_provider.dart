// PatientNotesProvider — server-backed patient notes per kartoteka,
// migrated from the local-only Hive prototype to clinical-svc
// (CreatePatientNote / ListPatientNotes / UpdatePatientNote /
// DeletePatientNote / SavePatientNote, docs/22).
//
// Stale-while-revalidate: the CacheManager meta box is kept as a READ
// cache. On first read for a patient the cached list is returned
// immediately, then ListPatientNotes is fetched in the background and
// the cache + state are updated. Writes go straight to the repository
// RPC, then we refresh from the server and update the cache. On RPC
// failure we keep the cached view (and log) rather than dropping notes.
//
// The local [PatientNote] model is a thin projection of the proto
// PatientNote — id, patientFileId, title, text, createdAt plus the
// fields the UI surfaces (kind, sentToPatientAt).

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cache/cache_provider.dart';
import '../generated/clinical/v1/clinical.pb.dart' as clinical_pb;
import '../repositories/clinical_notes_repository.dart';
import 'grpc_provider.dart';

// ── Model ──────────────────────────────────────────────────────────

class PatientNote {
  final String id;
  final String patientFileId;
  final String title;
  final String text;
  final DateTime createdAt;

  /// Server note kind: FREE_NOTE | ACTION_PLAN. Empty for legacy local
  /// entries (treated as a free note).
  final String kind;

  /// When the note was last e-mailed to the patient, or null if never.
  final DateTime? sentToPatientAt;

  const PatientNote({
    required this.id,
    required this.patientFileId,
    required this.title,
    required this.text,
    required this.createdAt,
    this.kind = '',
    this.sentToPatientAt,
  });

  bool get sentToPatient => sentToPatientAt != null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'patientFileId': patientFileId,
        'title': title,
        'text': text,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'kind': kind,
        if (sentToPatientAt != null)
          'sentToPatientAt': sentToPatientAt!.toUtc().toIso8601String(),
      };

  factory PatientNote.fromJson(Map<String, dynamic> json) => PatientNote(
        id: json['id'] as String? ?? '',
        patientFileId: json['patientFileId'] as String? ?? '',
        title: json['title'] as String? ?? '',
        text: json['text'] as String? ?? '',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '')
                ?.toLocal() ??
            DateTime.now(),
        kind: json['kind'] as String? ?? '',
        sentToPatientAt:
            DateTime.tryParse(json['sentToPatientAt'] as String? ?? '')
                ?.toLocal(),
      );

  /// Maps the proto PatientNote → the local model. Timestamps come over
  /// as protobuf Timestamps; a zero/unset Timestamp maps to null
  /// (sent_to_patient_at) or `now` (created_at, defensive).
  factory PatientNote.fromProto(clinical_pb.PatientNote p) {
    DateTime? sentAt;
    if (p.hasSentToPatientAt()) {
      sentAt = p.sentToPatientAt.toDateTime().toLocal();
    }
    final created = p.hasCreatedAt()
        ? p.createdAt.toDateTime().toLocal()
        : DateTime.now();
    return PatientNote(
      id: p.id,
      patientFileId: p.patientFileId,
      title: p.title,
      text: p.text,
      createdAt: created,
      kind: p.kind,
      sentToPatientAt: sentAt,
    );
  }

  PatientNote copyWith({
    String? title,
    String? text,
    DateTime? sentToPatientAt,
  }) =>
      PatientNote(
        id: id,
        patientFileId: patientFileId,
        title: title ?? this.title,
        text: text ?? this.text,
        createdAt: createdAt,
        kind: kind,
        sentToPatientAt: sentToPatientAt ?? this.sentToPatientAt,
      );
}

// ── Notifier (holds all notes keyed by patientFileId) ─────────────

class PatientNotesMapNotifier
    extends Notifier<Map<String, List<PatientNote>>> {
  static const _metaKey = 'patient_notes';

  /// patientFileIds we've already kicked a server refresh for this
  /// session, so the lazy load in [ensureLoaded] fires only once per
  /// patient (subsequent mutations refresh explicitly).
  final Set<String> _refreshed = {};

  ClinicalNotesRepository get _repo =>
      ClinicalNotesRepository(ref.read(grpcClientsProvider).clinical);

  @override
  Map<String, List<PatientNote>> build() {
    _loadCache();
    return const {};
  }

  // ── Read cache (Hive meta box) ──

  void _loadCache() {
    try {
      final mgr = cacheManagerInstance();
      final metaBox = mgr.rawMetaBox();
      final raw = metaBox.get(_metaKey);
      if (raw == null) return;
      final result = <String, List<PatientNote>>{};
      for (final entry in raw.entries) {
        final key = entry.key.toString();
        if (key == 'v') continue;
        final items = (entry.value as List?) ?? [];
        result[key] = items
            .map((e) => PatientNote.fromJson(
                (e as Map).map((k, v) => MapEntry(k.toString(), v))))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }
      state = result;
    } catch (e) {
      debugPrint('[patient-notes] cache load failed: $e');
      state = const {};
    }
  }

  /// Lazy SWR entry point: serve whatever is cached (already in state),
  /// then fetch the server list once per patient per session.
  void ensureLoaded(String patientFileId) {
    if (_refreshed.contains(patientFileId)) return;
    _refreshed.add(patientFileId);
    // Fire-and-forget; refreshNotes handles its own errors.
    refreshNotes(patientFileId);
  }

  /// Forces a ListPatientNotes fetch, updates state + cache. Keeps the
  /// cached view on failure.
  Future<void> refreshNotes(String patientFileId) async {
    try {
      final notes = await _repo.listNotes(patientFileId);
      final mapped = notes.map(PatientNote.fromProto).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      state = {...state, patientFileId: mapped};
      await _persist();
    } catch (e) {
      debugPrint('[patient-notes] refresh failed for $patientFileId: $e');
      // Keep cached state.
    }
  }

  // ── Writes (server RPC → refresh) ──

  Future<void> addNote(String patientFileId, String title, String text) async {
    try {
      await _repo.createNote(patientFileId, title.trim(), text.trim());
      await refreshNotes(patientFileId);
    } catch (e) {
      debugPrint('[patient-notes] addNote failed: $e');
      rethrow;
    }
  }

  Future<void> updateNote(
      String patientFileId, String noteId, String title, String text) async {
    try {
      await _repo.updateNote(noteId, title.trim(), text.trim());
      await refreshNotes(patientFileId);
    } catch (e) {
      debugPrint('[patient-notes] updateNote failed: $e');
      rethrow;
    }
  }

  Future<void> deleteNote(String patientFileId, String noteId) async {
    // Optimistic removal so the swipe-to-dismiss UI stays responsive;
    // the server refresh reconciles afterwards.
    final existing = state[patientFileId];
    if (existing != null) {
      state = {
        ...state,
        patientFileId: existing.where((n) => n.id != noteId).toList(),
      };
      await _persist();
    }
    try {
      await _repo.deleteNote(noteId);
      await refreshNotes(patientFileId);
    } catch (e) {
      debugPrint('[patient-notes] deleteNote failed: $e');
      // Re-fetch to undo the optimistic removal if the server still
      // has the note.
      await refreshNotes(patientFileId);
    }
  }

  Future<void> _persist() async {
    try {
      final mgr = cacheManagerInstance();
      final metaBox = mgr.rawMetaBox();
      final map = <String, dynamic>{};
      for (final entry in state.entries) {
        map[entry.key] = entry.value.map((n) => n.toJson()).toList();
      }
      await metaBox.put(_metaKey, map);
    } catch (e) {
      debugPrint('[patient-notes] persist failed: $e');
    }
  }
}

// ── Providers ─────────────────────────────────────────────────────

final patientNotesMapProvider = NotifierProvider<PatientNotesMapNotifier,
    Map<String, List<PatientNote>>>(
  PatientNotesMapNotifier.new,
);

/// Per-patient notes view — returns the list for a single patient and
/// triggers a one-time server refresh (SWR) on first read.
final patientNotesProvider =
    Provider.family<List<PatientNote>, String>((ref, patientFileId) {
  // Kick the lazy server load. Reading the notifier doesn't subscribe
  // to it, so this won't loop; state updates flow via the watch below.
  ref.read(patientNotesMapProvider.notifier).ensureLoaded(patientFileId);
  final allNotes = ref.watch(patientNotesMapProvider);
  return allNotes[patientFileId] ?? const [];
});
