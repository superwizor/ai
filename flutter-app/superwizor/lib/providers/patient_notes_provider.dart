// PatientNotesProvider — local-only notes per patient, backed by the
// CacheManager meta box.
//
// Notes are tiny free-text entries a therapist jots down about a
// client between sessions. They never leave the device (no gRPC, no
// server storage). The meta box is already opened per-therapist by
// CacheManager.openForUser so no new Hive box is needed.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cache/cache_provider.dart';

// ── Model ──────────────────────────────────────────────────────────

class PatientNote {
  final String id;
  final String patientFileId;
  final String title;
  final String text;
  final DateTime createdAt;

  const PatientNote({
    required this.id,
    required this.patientFileId,
    required this.title,
    required this.text,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'patientFileId': patientFileId,
        'title': title,
        'text': text,
        'createdAt': createdAt.toUtc().toIso8601String(),
      };

  factory PatientNote.fromJson(Map<String, dynamic> json) => PatientNote(
        id: json['id'] as String? ?? '',
        patientFileId: json['patientFileId'] as String? ?? '',
        title: json['title'] as String? ?? '',
        text: json['text'] as String? ?? '',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '')
                ?.toLocal() ??
            DateTime.now(),
      );

  PatientNote copyWith({String? title, String? text}) => PatientNote(
        id: id,
        patientFileId: patientFileId,
        title: title ?? this.title,
        text: text ?? this.text,
        createdAt: createdAt,
      );
}

// ── Notifier (holds all notes keyed by patientFileId) ─────────────

class PatientNotesMapNotifier
    extends Notifier<Map<String, List<PatientNote>>> {
  static const _metaKey = 'patient_notes';

  @override
  Map<String, List<PatientNote>> build() {
    _load();
    return const {};
  }

  void _load() {
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
      debugPrint('[patient-notes] load failed: $e');
      state = const {};
    }
  }

  Future<void> addNote(String patientFileId, String title, String text) async {
    final note = PatientNote(
      id: DateTime.now().microsecondsSinceEpoch.toRadixString(36),
      patientFileId: patientFileId,
      title: title.trim(),
      text: text.trim(),
      createdAt: DateTime.now(),
    );
    final existing = state[patientFileId] ?? [];
    state = {
      ...state,
      patientFileId: [note, ...existing],
    };
    await _persist();
  }

  Future<void> updateNote(
      String patientFileId, String noteId, String title, String text) async {
    final existing = state[patientFileId];
    if (existing == null) return;
    state = {
      ...state,
      patientFileId: existing
          .map((n) =>
              n.id == noteId ? n.copyWith(title: title, text: text) : n)
          .toList(),
    };
    await _persist();
  }

  Future<void> deleteNote(String patientFileId, String noteId) async {
    final existing = state[patientFileId];
    if (existing == null) return;
    state = {
      ...state,
      patientFileId: existing.where((n) => n.id != noteId).toList(),
    };
    await _persist();
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

/// Per-patient notes view — returns the list for a single patient.
final patientNotesProvider =
    Provider.family<List<PatientNote>, String>((ref, patientFileId) {
  final allNotes = ref.watch(patientNotesMapProvider);
  return allNotes[patientFileId] ?? const [];
});
