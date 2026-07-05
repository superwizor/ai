// Client-panel theme (docs/39 PR13). The client surface now matches the
// Superwizor design language — Montserrat, Ember accent — and offers a
// light/dark toggle. Dark reuses the therapist app's Evergreen/Nocturne
// green palette (Euphire); light is a calm paper-white variant. Colors
// flow through a ThemeExtension so every client widget reads them via
// `context.cp` with no threading.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

@immutable
class ClientPalette extends ThemeExtension<ClientPalette> {
  final Color bg;
  final Color card;
  final Color border;
  final Color ink;
  final Color muted;
  final Color accent; // Ember — CTA, active states, own-note tint
  final Color onAccent; // text/icon on an accent fill
  final Color accentSoft;
  final Color green; // session / therapist-content tint
  final Color greenSoft;

  const ClientPalette({
    required this.bg,
    required this.card,
    required this.border,
    required this.ink,
    required this.muted,
    required this.accent,
    required this.onAccent,
    required this.accentSoft,
    required this.green,
    required this.greenSoft,
  });

  // Paper-white, editorial — near-black ink, deep-amber accent for
  // legible text-on-fill.
  static const light = ClientPalette(
    bg: Color(0xFFF4F3EF),
    card: Colors.white,
    border: Color(0xFFEDEBE4),
    ink: Color(0xFF1B1C1E),
    muted: Color(0xFF8A8D91),
    accent: Color(0xFFE08A0F),
    onAccent: Colors.white,
    accentSoft: Color(0xFFFBEDD3),
    green: Color(0xFF2E7D57),
    greenSoft: Color(0xFFE8F1EC),
  );

  // Euphire green — the therapist app's surfaces (Nocturne bg, teal
  // cards, Ember accent, frost/mist text).
  static const dark = ClientPalette(
    bg: Color(0xFF142428), // deepTealBackground
    card: Color(0xFF1F353A), // surfaceTeal
    border: Color(0xFF3A5055), // glassBorder
    ink: Color(0xFFFAFAFA), // frostWhite
    muted: Color(0xFFB2CACC), // mist
    accent: Color(0xFFFCAE2F), // ember
    onAccent: Color(0xFF1F1F1F), // obsidian — dark label on Ember CTA
    accentSoft: Color(0x33FCAE2F),
    green: Color(0xFF6FC7A0),
    greenSoft: Color(0x1F6FC7A0),
  );

  @override
  ClientPalette copyWith({
    Color? bg,
    Color? card,
    Color? border,
    Color? ink,
    Color? muted,
    Color? accent,
    Color? onAccent,
    Color? accentSoft,
    Color? green,
    Color? greenSoft,
  }) {
    return ClientPalette(
      bg: bg ?? this.bg,
      card: card ?? this.card,
      border: border ?? this.border,
      ink: ink ?? this.ink,
      muted: muted ?? this.muted,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      accentSoft: accentSoft ?? this.accentSoft,
      green: green ?? this.green,
      greenSoft: greenSoft ?? this.greenSoft,
    );
  }

  @override
  ClientPalette lerp(ThemeExtension<ClientPalette>? other, double t) {
    if (other is! ClientPalette) return this;
    return ClientPalette(
      bg: Color.lerp(bg, other.bg, t)!,
      card: Color.lerp(card, other.card, t)!,
      border: Color.lerp(border, other.border, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      green: Color.lerp(green, other.green, t)!,
      greenSoft: Color.lerp(greenSoft, other.greenSoft, t)!,
    );
  }
}

/// Read the active client palette anywhere under the client [Theme].
extension ClientPaletteX on BuildContext {
  ClientPalette get cp =>
      Theme.of(this).extension<ClientPalette>() ?? ClientPalette.dark;
}

/// Full ThemeData for the client surface — wraps the client screens so
/// Material widgets (dialogs, fields, snackbars) pick up the palette too.
ThemeData clientThemeData(bool dark) {
  final p = dark ? ClientPalette.dark : ClientPalette.light;
  final base = ThemeData(
    brightness: dark ? Brightness.dark : Brightness.light,
    useMaterial3: true,
  );
  return base.copyWith(
    scaffoldBackgroundColor: p.bg,
    extensions: [p],
    colorScheme: base.colorScheme.copyWith(
      primary: p.accent,
      onPrimary: p.onAccent,
      surface: p.card,
      onSurface: p.ink,
    ),
    textTheme: base.textTheme.apply(
      fontFamily: 'Montserrat',
      bodyColor: p.ink,
      displayColor: p.ink,
    ),
    dialogTheme: DialogThemeData(backgroundColor: p.card),
    inputDecorationTheme: InputDecorationTheme(
      hintStyle: TextStyle(color: p.muted, fontFamily: 'Montserrat'),
    ),
  );
}

// ── Persisted light/dark toggle ──────────────────────────────────────
// Default: dark (green, matching the rest of Superwizor AI). Stored in
// the 'client_prefs' Hive box (opened in main before runApp).

class ClientDarkNotifier extends Notifier<bool> {
  static const boxName = 'client_prefs';
  static const _key = 'dark_mode';

  @override
  bool build() {
    try {
      return Hive.box(boxName).get(_key, defaultValue: true) as bool;
    } catch (_) {
      return true;
    }
  }

  Future<void> toggle() async {
    final next = !state;
    state = next;
    try {
      await Hive.box(boxName).put(_key, next);
    } catch (_) {
      // Non-fatal: the choice just won't persist across restarts.
    }
  }
}

final clientDarkProvider =
    NotifierProvider<ClientDarkNotifier, bool>(ClientDarkNotifier.new);

// ── Timeline filter ──────────────────────────────────────────────────

enum ClientFilter { all, sessions, therapist, own }

class ClientFilterNotifier extends Notifier<ClientFilter> {
  @override
  ClientFilter build() => ClientFilter.all;
  void select(ClientFilter f) => state = f;
}

final clientFilterProvider =
    NotifierProvider<ClientFilterNotifier, ClientFilter>(
        ClientFilterNotifier.new);
