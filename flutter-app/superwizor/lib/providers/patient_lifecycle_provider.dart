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

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../generated/clinical/v1/clinical.pb.dart' as grpc_clinical;
import 'current_user_provider.dart';
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
  static const _keyPrefix = 'patient_lifecycle_';

  @override
  Map<String, PatientLifecycle> build() {
    _loadFromPrefs();
    // Also sync from backend data if patients are already loaded.
    _syncFromPatientsProvider();
    return {};
  }

  /// Loads the lifecycle map from SharedPreferences (legacy/fallback).
  Future<void> _loadFromPrefs() async {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_keyPrefix${user.id}');
    if (raw == null) return;
    try {
      final map = (jsonDecode(raw) as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, PatientLifecycle.values.byName(v as String)),
      );
      state = map;
    } catch (_) {}
  }

  /// Persists the lifecycle map to SharedPreferences (local backup).
  Future<void> _saveToPrefs() async {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;
    final prefs = await SharedPreferences.getInstance();
    final map = state.map((k, v) => MapEntry(k, v.name));
    await prefs.setString('$_keyPrefix${user.id}', jsonEncode(map));
  }

  /// Reads the lifecycle status from already-loaded patients and
  /// populates the in-memory map. This is the primary read path —
  /// backend data wins over local SharedPreferences.
  void _syncFromPatientsProvider() {
    final patientsAsync = ref.read(patientsProvider);
    patientsAsync.whenData((patients) {
      final backendMap = <String, PatientLifecycle>{};
      for (final p in patients) {
        backendMap[p.id] = _fromBackend(p.lifecycleStatus);
      }
      if (backendMap.isNotEmpty) {
        state = {...state, ...backendMap};
        _saveToPrefs(); // Sync local cache with backend truth
      }
    });
  }

  /// Called by the patients provider after a refresh to update the
  /// lifecycle map from fresh backend data. This ensures the map
  /// stays in sync when patients are reloaded.
  void syncFromBackendData(Map<String, String> lifecycleMap) {
    final mapped = lifecycleMap.map(
      (id, status) => MapEntry(id, _fromBackend(status)),
    );
    state = {...state, ...mapped};
    _saveToPrefs();
  }

  PatientLifecycle getLifecycle(String patientId) {
    return state[patientId] ?? PatientLifecycle.active;
  }

  /// Sets the lifecycle for a patient. Sends to the backend via
  /// UpdatePatientFile and updates local state optimistically.
  Future<void> setLifecycle(String patientId, PatientLifecycle lifecycle) async {
    // Optimistic update — UI sees the change immediately.
    state = {...state, patientId: lifecycle};
    await _saveToPrefs();

    // Sync to backend.
    try {
      final client = ref.read(grpcClientsProvider).clinical;
      await client.updatePatientFile(grpc_clinical.UpdatePatientFileRequest(
        patientFileId: patientId,
        lifecycleStatus: _toBackend(lifecycle),
        // is_process_closed is derived server-side from lifecycle_status
        // when lifecycle_status is non-empty (see SQL CASE in 000058).
      ));
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
