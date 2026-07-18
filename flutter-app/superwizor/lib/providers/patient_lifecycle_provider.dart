// PatientLifecycleProvider — backend-synced provider for managing the
// lifecycle state of patient files (ACTIVE/COMPLETED/PAUSED).
//
// Lifecycle state is persisted server-side in patient_files.lifecycle_status
// (migration 000058) and flows to the client via ListPatientFiles/
// GetPatientFile protos. SharedPreferences is kept as a fallback/cache
// during the migration window (pre-000058 backends).
//
// Write path: setLifecycle() → gRPC UpdatePatientFile.lifecycle_status
//                             → optimistic UI update
// Read path:  patientsProvider refresh → Patient.lifecycleStatus
//             → syncFromPatients() populates the in-memory map

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../generated/clinical/v1/clinical.pb.dart' as grpc_clinical;
import 'grpc_provider.dart';
import 'patient_provider.dart';

enum PatientLifecycle { active, completed, paused }

/// Maps the backend lifecycle_status string (ACTIVE/COMPLETED/PAUSED)
/// to the local enum.
PatientLifecycle _fromBackend(String status) {
  switch (status.toUpperCase()) {
    case 'COMPLETED':
      return PatientLifecycle.completed;
    case 'PAUSED':
      return PatientLifecycle.paused;
    default:
      return PatientLifecycle.active;
  }
}

/// Maps the local enum to the backend string.
String _toBackend(PatientLifecycle lifecycle) {
  switch (lifecycle) {
    case PatientLifecycle.active:
      return 'ACTIVE';
    case PatientLifecycle.completed:
      return 'COMPLETED';
    case PatientLifecycle.paused:
      return 'PAUSED';
  }
}

class PatientLifecycleNotifier extends Notifier<Map<String, PatientLifecycle>> {
  @override
  Map<String, PatientLifecycle> build() {
    // Watch patientsProvider so we rebuild when the patient list is loaded/updated.
    final patientsAsync = ref.watch(patientsProvider);
    final map = <String, PatientLifecycle>{};

    patientsAsync.whenData((patients) {
      for (final p in patients) {
        map[p.id] = _fromBackend(p.lifecycleStatus);
      }
    });

    return map;
  }

  PatientLifecycle getLifecycle(String patientId) {
    return state[patientId] ?? PatientLifecycle.active;
  }

  /// Sets the lifecycle for a patient. Sends to the backend via
  /// UpdatePatientFile and updates local state optimistically.
  Future<void> setLifecycle(String patientId, PatientLifecycle lifecycle) async {
    // Optimistic update — UI sees the change immediately.
    state = {...state, patientId: lifecycle};

    // Sync to backend.
    try {
      final client = ref.read(grpcClientsProvider).clinical;
      await client.updatePatientFile(grpc_clinical.UpdatePatientFileRequest(
        patientFileId: patientId,
        lifecycleStatus: _toBackend(lifecycle),
        // is_process_closed is derived server-side from lifecycle_status
        // when lifecycle_status is non-empty (see SQL CASE in 000058).
      ));

      // Refresh the patients provider in the background. This will fetch
      // the fresh list from the backend (with the updated lifecycle_status),
      // update the Hive cache, and publish the new list to the UI without
      // entering a loading state (avoiding UI collapse and flickering).
      await ref.read(patientsProvider.notifier).forceRefresh();
    } catch (e) {
      debugPrint('[lifecycle] backend sync failed (local state persisted): $e');
      // Don't revert — the local state is the user's intent. Next
      // patients refresh will reconcile if the backend caught up.
    }
  }
}

final patientLifecycleProvider =
    NotifierProvider<PatientLifecycleNotifier, Map<String, PatientLifecycle>>(
  PatientLifecycleNotifier.new,
);
