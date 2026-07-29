// Kartoteka timeline filters (therapist side) — the mirror of the
// Companion app's ClientFilter set (lib/client/client_theme.dart):
// same semantics (empty set = show everything, chips toggle categories
// in/out), same three categories seen from the therapist's seat:
//   sessions     — recorded sessions (incl. pending uploads / active
//                  recording placeholders),
//   clientNotes  — notes the client sent from their panel
//                  (PatientNote.authorRole == 'PATIENT'),
//   ownNotes     — the therapist's own notes + action plans.
//
// Keyed per kartoteka and autoDispose so every visit starts unfiltered —
// a filter left on days ago would silently hide sessions and read as
// "my data disappeared".

import 'package:flutter_riverpod/flutter_riverpod.dart';

enum KartotekaFilter { sessions, clientNotes, ownNotes }

class KartotekaFiltersNotifier extends Notifier<Set<KartotekaFilter>> {
  KartotekaFiltersNotifier(this.patientFileId);

  /// Riverpod 3 family idiom: the family argument arrives via the
  /// constructor, not build().
  final String patientFileId;

  @override
  Set<KartotekaFilter> build() => KartotekaFilter.values.toSet();

  /// Toggle a category in/out of the active set.
  void toggle(KartotekaFilter f) {
    final next = Set<KartotekaFilter>.from(state);
    if (!next.add(f)) next.remove(f);
    state = next;
  }
}

final kartotekaFiltersProvider = NotifierProvider.autoDispose
    .family<KartotekaFiltersNotifier, Set<KartotekaFilter>, String>(
        KartotekaFiltersNotifier.new);
