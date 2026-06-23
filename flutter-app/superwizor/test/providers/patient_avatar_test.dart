// Tests for PatientAvatarConfig JSON round-trip and AvatarColors palette
// used by patient_avatar_provider.dart (migration 000059).

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superwizor/providers/patient_avatar_provider.dart';

void main() {
  group('PatientAvatarConfig', () {
    test('JSON round-trip preserves all fields', () {
      const original = PatientAvatarConfig(customLabel: 'AK', colorIndex: 3);
      final json = original.toJson();
      final decoded = PatientAvatarConfig.fromJson(json);
      expect(decoded.customLabel, 'AK');
      expect(decoded.colorIndex, 3);
    });

    test('JSON round-trip with null label', () {
      const original = PatientAvatarConfig(colorIndex: 5);
      final json = original.toJson();
      expect(json.containsKey('label'), isFalse);
      final decoded = PatientAvatarConfig.fromJson(json);
      expect(decoded.customLabel, isNull);
      expect(decoded.colorIndex, 5);
    });

    test('default config has null label and colorIndex 0', () {
      const config = PatientAvatarConfig();
      expect(config.customLabel, isNull);
      expect(config.colorIndex, 0);
    });

    test('fromJson handles missing color key with default 0', () {
      final decoded = PatientAvatarConfig.fromJson({'label': 'XY'});
      expect(decoded.customLabel, 'XY');
      expect(decoded.colorIndex, 0);
    });

    test('toJson produces valid JSON string for gRPC', () {
      const config = PatientAvatarConfig(customLabel: 'MK', colorIndex: 2);
      final jsonString = jsonEncode(config.toJson());
      final reparsed = jsonDecode(jsonString) as Map<String, dynamic>;
      expect(reparsed['label'], 'MK');
      expect(reparsed['color'], 2);
    });

    test('color getter returns palette color clamped to range', () {
      const config0 = PatientAvatarConfig(colorIndex: 0);
      expect(config0.color, AvatarColors.palette[0]);

      const configMax = PatientAvatarConfig(colorIndex: 999);
      expect(configMax.color, AvatarColors.palette.last);

      const configNeg = PatientAvatarConfig(colorIndex: -1);
      expect(configNeg.color, AvatarColors.palette.first);
    });
  });

  group('AvatarColors', () {
    test('palette has 8 entries', () {
      expect(AvatarColors.palette.length, 8);
    });

    test('fromIndex clamps out-of-range indices', () {
      expect(AvatarColors.fromIndex(-1), AvatarColors.palette[0]);
      expect(AvatarColors.fromIndex(100), AvatarColors.palette[7]);
    });

    test('all palette entries are opaque', () {
      for (final c in AvatarColors.palette) {
        expect(c.a, 1.0, reason: 'Avatar color should be fully opaque');
      }
    });
  });
}
