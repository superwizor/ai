// PatientContactProvider — local-only patient contact details (e-mail)
// per patientFileId, backed by the CacheManager meta box.
//
// This mirrors patient_notes_provider.dart: a tiny Hive-backed store that
// never leaves the device. It exists so the action-plan / note send-gate
// can reflect a real e-mail captured in the UI, instead of always falling
// back to a simulated address.
//
// NOTE (local-only prototype): this moves to clinical-svc
// UpdatePatientUser (patient_email field) per docs/22 once the backend
// accepts the e-mail. Until then it's stored client-side only.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cache/cache_provider.dart';

// ── Notifier (holds e-mail keyed by patientFileId) ─────────────────

class PatientContactsNotifier extends Notifier<Map<String, String>> {
  static const _metaKey = 'patient_contacts';

  @override
  Map<String, String> build() {
    _load();
    return const {};
  }

  void _load() {
    try {
      final mgr = cacheManagerInstance();
      final metaBox = mgr.rawMetaBox();
      final raw = metaBox.get(_metaKey);
      if (raw == null) return;
      final result = <String, String>{};
      for (final entry in raw.entries) {
        final key = entry.key.toString();
        if (key == 'v') continue;
        final value = entry.value?.toString().trim() ?? '';
        if (value.isNotEmpty) result[key] = value;
      }
      state = result;
    } catch (e) {
      debugPrint('[patient-contacts] load failed: $e');
      state = const {};
    }
  }

  /// Persists [email] for [patientFileId]. An empty / whitespace e-mail
  /// removes any stored value (e-mail is an optional field).
  Future<void> setEmail(String patientFileId, String email) async {
    final trimmed = email.trim();
    final next = {...state};
    if (trimmed.isEmpty) {
      next.remove(patientFileId);
    } else {
      next[patientFileId] = trimmed;
    }
    state = next;
    await _persist();
  }

  Future<void> _persist() async {
    try {
      final mgr = cacheManagerInstance();
      final metaBox = mgr.rawMetaBox();
      final map = <String, dynamic>{};
      for (final entry in state.entries) {
        map[entry.key] = entry.value;
      }
      await metaBox.put(_metaKey, map);
    } catch (e) {
      debugPrint('[patient-contacts] persist failed: $e');
    }
  }
}

// ── Providers ─────────────────────────────────────────────────────

final patientContactsProvider =
    NotifierProvider<PatientContactsNotifier, Map<String, String>>(
  PatientContactsNotifier.new,
);

/// Per-patient e-mail view — returns the stored e-mail for a single
/// patient, or null when none has been captured.
final patientEmailProvider =
    Provider.family<String?, String>((ref, patientFileId) {
  final all = ref.watch(patientContactsProvider);
  final email = all[patientFileId];
  return (email != null && email.isNotEmpty) ? email : null;
});
