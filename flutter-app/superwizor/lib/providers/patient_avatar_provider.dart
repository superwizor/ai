// PatientAvatarProvider — per-kartoteka avatar customization (label + color).
//
// ──────────────────────────────────────────────────────────────────────
// MIGRATION (000059): Source of truth moved from SharedPreferences to
// patient_files.avatar_config (JSONB), synced via ClinicalService.SetAvatarConfig
// gRPC RPC. The avatar config now persists across devices. On first run
// after this change, we migrate locally-stored configs to the backend.
// ──────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../generated/clinical/v1/clinical.pb.dart' as grpc_clinical;
import 'current_user_provider.dart';
import 'grpc_provider.dart';

/// Euphire-harmonious avatar colors — tested for WCAG contrast
/// on dark background (#0A2326) with white text.
class AvatarColors {
  AvatarColors._();

  static const List<Color> palette = [
    Color(0xFF2D6068), // Deep Teal (default)
    Color(0xFF004D54), // Evergreen
    Color(0xFF4A8B6E), // Sage
    Color(0xFF8B5E3C), // Ember Warm
    Color(0xFF885553), // Dusk Rose
    Color(0xFF6E4E6A), // Plum
    Color(0xFF3B5998), // Aurora Blue
    Color(0xFF5C6B7A), // Slate
  ];

  static Color fromIndex(int index) =>
      palette[index.clamp(0, palette.length - 1)];
}

/// Data class for a patient's custom avatar config.
class PatientAvatarConfig {
  final String? customLabel; // null = use auto-initials
  final int colorIndex;      // index into AvatarColors.palette

  const PatientAvatarConfig({this.customLabel, this.colorIndex = 0});

  Map<String, dynamic> toJson() => {
        if (customLabel != null) 'label': customLabel,
        'color': colorIndex,
      };

  factory PatientAvatarConfig.fromJson(Map<String, dynamic> json) =>
      PatientAvatarConfig(
        customLabel: json['label'] as String?,
        colorIndex: (json['color'] as int?) ?? 0,
      );

  Color get color => AvatarColors.fromIndex(colorIndex);
}

class PatientAvatarNotifier extends Notifier<Map<String, PatientAvatarConfig>> {
  static const _keyPrefix = 'patient_avatar_';

  @override
  Map<String, PatientAvatarConfig> build() {
    _loadFromBackend();
    return {};
  }

  /// Load avatar configs from the backend patient files data.
  /// Each PatientFile now carries avatar_config as a JSON string.
  Future<void> _loadFromBackend() async {
    try {
      final user = ref.read(currentUserProvider).value;
      if (user == null) return;

      // Migrate local SharedPreferences configs to backend first.
      await _migrateLocalToBackend(user.id);

      // Avatar configs are now embedded in PatientFile responses —
      // they come back automatically from ListPatientFiles. The patient
      // provider parses them. We just need to populate our local map
      // from what the patient provider already fetched.
      final client = ref.read(grpcClientsProvider).clinical;
      final res = await client.listPatientFiles(
        grpc_clinical.ListPatientFilesRequest(
          therapistId: user.id,
          pageSize: 500,
        ),
      );

      final map = <String, PatientAvatarConfig>{};
      for (final pf in res.patientFiles) {
        if (pf.avatarConfig.isNotEmpty) {
          try {
            final json = jsonDecode(pf.avatarConfig) as Map<String, dynamic>;
            map[pf.id] = PatientAvatarConfig.fromJson(json);
          } catch (_) {
            // Malformed JSON — skip.
          }
        }
      }
      if (map.isNotEmpty) {
        state = map;
      }
    } catch (_) {
      // Network error — use empty defaults.
    }
  }

  PatientAvatarConfig getConfig(String patientId) {
    return state[patientId] ?? const PatientAvatarConfig();
  }

  Future<void> setConfig(String patientFileId, PatientAvatarConfig config) async {
    // Optimistic local update.
    state = {...state, patientFileId: config};

    try {
      final client = ref.read(grpcClientsProvider).clinical;
      await client.setAvatarConfig(
        grpc_clinical.SetAvatarConfigRequest(
          patientFileId: patientFileId,
          avatarConfig: jsonEncode(config.toJson()),
        ),
      );
    } catch (e) {
      // Best-effort: if the RPC fails, the local state is still
      // updated. Next ListPatientFiles will overwrite.
    }
  }

  /// One-time migration from SharedPreferences to backend.
  Future<void> _migrateLocalToBackend(String therapistId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_keyPrefix$therapistId';
      final raw = prefs.getString(key);
      if (raw == null) return;

      final Map<String, dynamic> localMap;
      try {
        localMap = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        // Corrupt local data — delete and move on.
        await prefs.remove(key);
        return;
      }

      if (localMap.isEmpty) {
        await prefs.remove(key);
        return;
      }

      final client = ref.read(grpcClientsProvider).clinical;
      for (final entry in localMap.entries) {
        try {
          final configJson = jsonEncode(entry.value);
          await client.setAvatarConfig(
            grpc_clinical.SetAvatarConfigRequest(
              patientFileId: entry.key,
              avatarConfig: configJson,
            ),
          );
        } catch (_) {
          // Skip individual failures — patient file may have been deleted.
        }
      }

      // All migrated — delete the local key.
      await prefs.remove(key);
    } catch (_) {
      // SharedPreferences error — skip migration.
    }
  }
}

final patientAvatarProvider =
    NotifierProvider<PatientAvatarNotifier, Map<String, PatientAvatarConfig>>(
  PatientAvatarNotifier.new,
);
