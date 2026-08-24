import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../client/client_home_screen.dart';
import '../providers/patient_notes_provider.dart';
import '../providers/session_details_provider.dart';
import '../repositories/session_details_repository.dart';
import 'session_state_listener.dart';

/// docs/39 PR12 — live client-panel refresh via the existing Firestore
/// inbox (`user_notifications/{uid}/inbox`), the same channel session
/// status already rides on.
///
/// Why this and not FCM: an iOS foreground push does not surface a banner
/// or run app code reliably, and the web client panel has no web-push at
/// all. The Firestore listener, by contrast, delivers to a foregrounded
/// app on iOS AND web identically. notification-svc now mirrors the two
/// client-panel events into the recipient's inbox; this listener turns a
/// freshly-arrived doc into the right provider refresh:
///
///   client_note_received → therapist's cached notes for that kartoteka
///   item_shared          → client's web-panel timeline
///
/// Both refreshes are idempotent and cheap, so an occasional double-fire
/// is harmless. We still de-dupe against notification ids so a cold-start
/// snapshot (up to 50 existing docs) doesn't trigger a refresh storm.
class InboxRefreshListener {
  InboxRefreshListener(this._container, {SessionStateListener? listener})
      : _listener = listener ?? SessionStateListener();

  final ProviderContainer _container;
  final SessionStateListener _listener;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<List<InboxNotification>>? _inboxSub;
  String? _uid;

  /// Records the ids we've already reacted to (or seeded from the first
  /// snapshot) so redeliveries and the initial backlog are ignored.
  final Set<String> _seen = <String>{};
  bool _primed = false;

  /// Begins watching auth state; (re)subscribes the inbox stream to the
  /// currently signed-in user and tears it down on logout / user switch.
  void start() {
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      final uid = user?.uid;
      if (uid == _uid) return; // no change
      _uid = uid;
      _resubscribe(uid);
    });
  }

  void _resubscribe(String? uid) {
    _inboxSub?.cancel();
    _inboxSub = null;
    _seen.clear();
    _primed = false;
    if (uid == null || uid.isEmpty) return;

    _inboxSub = _listener.inboxFor(uid).listen(
      _onInbox,
      onError: (Object e) => debugPrint('inbox listener error: $e'),
    );
  }

  void _onInbox(List<InboxNotification> items) {
    // First emission = existing backlog; seed `_seen`, don't react.
    if (!_primed) {
      for (final n in items) {
        _seen.add(n.notificationId);
      }
      _primed = true;
      return;
    }
    for (final n in items) {
      if (n.notificationId.isEmpty || _seen.contains(n.notificationId)) {
        continue;
      }
      _seen.add(n.notificationId);
      _handle(n);
    }
  }

  void _handle(InboxNotification n) {
    switch (n.notificationType) {
      case 'client_note_received':
        // Therapist app: a client sent/delivered a note. Refresh the
        // cached notes for that kartoteka so it appears live.
        if (n.patientFileId.isNotEmpty) {
          _container
              .read(patientNotesMapProvider.notifier)
              .refreshNotes(n.patientFileId)
              .catchError((_) {});
        }
        break;
      case 'experimental_report_ready':
      case 'experimental_report_skipped':
        // Raport eksperymentalny (albo powód jego braku) dociera parę
        // minut po produkcyjnym. Szczegóły sesji siedzą wtedy w cache z
        // miękkim TTL 1 h — bez unieważnienia drugi raport był
        // niewidoczny do godziny od pierwszego otwarcia. Podbicie
        // rewizji odświeża także AKTUALNIE otwarty ekran raportu.
        if (n.sessionId.isNotEmpty) {
          unawaited(_invalidateSessionDetails(n.sessionId));
          _container
              .read(sessionDetailsRevisionProvider(n.sessionId).notifier)
              .bump();
        }
        break;
      case 'item_shared':
        // Client web panel: the therapist shared a session/note. The
        // timeline provider is a FutureProvider.autoDispose — invalidating
        // it re-fetches when the panel is on screen, and is a no-op
        // otherwise.
        _container.invalidate(clientHomeProvider);
        break;
    }
  }

  Future<void> _invalidateSessionDetails(String sessionId) async {
    try {
      final repo =
          await _container.read(sessionDetailsRepositoryProvider.future);
      await repo?.invalidate(sessionId);
    } catch (e) {
      debugPrint('inbox: invalidate session details: $e');
    }
  }

  Future<void> dispose() async {
    await _inboxSub?.cancel();
    await _authSub?.cancel();
  }
}
