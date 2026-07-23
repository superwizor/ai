// CurrentUserProvider — single source of truth for the authenticated
// therapist's PostgreSQL `users.id` (UUID), as returned by identity-svc.
//
// Why this exists:
//   - Firebase Auth gives us a Firebase UID (string)
//   - Backend tables (audio_uploads.therapist_id, etc.) reference
//     users.id (UUID) via foreign keys
//   - Without resolving Firebase UID → users.id, every backend RPC
//     that takes therapist_id fails with FK violation
//
// This provider:
//   1. Watches FirebaseAuth state
//   2. On any logged-in change, calls identity-svc.GetUserByFirebaseUID
//   3. Caches the resulting User (incl. id, email, role, organization_id)
//   4. Exposes it as AsyncValue<User?> for UI to consume

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grpc/grpc.dart' as grpc;
import 'package:shared_preferences/shared_preferences.dart';

import '../generated/identity/v1/identity.pb.dart' as identity_pb;
import 'grpc_provider.dart';
import 'patient_provider.dart' show patientsLoadStage;
import 'services_provider.dart';

/// Streams Firebase Auth state changes (logged-in user or null on logout).
final firebaseUserProvider = StreamProvider<fb_auth.User?>(
  (ref) => ref.watch(firebaseAuthProvider).authStateChanges(),
);

/// The backend `users` row for the currently logged-in Firebase user.
/// Returns `null` when there's no Firebase session.
/// Throws on identity-svc network errors so UI can show retry.
final currentUserProvider = FutureProvider<identity_pb.User?>((ref) async {
  final firebaseUser = await ref.watch(firebaseUserProvider.future);
  if (firebaseUser == null) return null;

  final identityClient = ref.watch(grpcClientsProvider).identity;
  try {
    // Fast-fail on dead networks (airplane mode): without the timeout a
    // connecting gRPC channel can hold this future for minutes and every
    // consumer (auth gate, cache) hangs with it.
    final user = await identityClient
        .getUserByFirebaseUID(
          identity_pb.GetUserByFirebaseUIDRequest(firebaseUid: firebaseUser.uid),
        )
        .timeout(const Duration(seconds: 8));
    // Persist the firebase-uid → backend-id mapping so the encrypted
    // cache can open OFFLINE on the next cold start (the boxes are
    // keyed by users.id, which normally only this network call knows —
    // see cacheManagerProvider's offline fast path).
    unawaited(SharedPreferences.getInstance().then(
      (p) => p.setString('backend_user_id_${firebaseUser.uid}', user.id),
    ));
    return user;
  } on grpc.GrpcError catch (e) {
    // Firebase session without an identity-svc row. The old "self-heal"
    // silently auto-registered a THERAPIST here — which minted GHOST
    // therapist accounts (trial org included!) for ANYONE who signed
    // into the app with an unknown Google/Apple identity: would-be
    // managers and clients then couldn't accept their real invitations
    // (unique e-mail/uid already taken — live-tested 2026-07-04,
    // d.piotrak@lisa.care). Registration belongs to the explicit flows
    // (superwizor.ai wizard, invitation accept pages); the app now
    // surfaces a clear "account not found" state instead of creating
    // anything.
    if (e.code == grpc.StatusCode.notFound) {
      debugPrint(
          'currentUserProvider: user ${firebaseUser.uid} has no '
          'identity-svc row — NOT auto-registering (docs/39 live-fix)');
      throw const AccountNotRegisteredException();
    }
    debugPrint('currentUserProvider failed: $e');
    rethrow;
  } catch (e) {
    debugPrint('currentUserProvider failed: $e');
    rethrow;
  }
});

/// Offline-safe backend users.id for the signed-in Firebase account.
///
/// Every cache box, repository and the upload queue are keyed by the
/// BACKEND id — which historically arrived only from the network lookup
/// above, so a cold start in airplane mode hung every one of them
/// (live-fix 2026-07-23: kartoteka spinner-forever). This provider
/// prefers the locally persisted firebaseUid→users.id mapping (written
/// on every successful currentUserProvider fetch) and touches the
/// network only on the first-ever login on a device, when no cache
/// exists to serve anyway. Null = signed out.
final backendUserIdProvider = FutureProvider<String?>((ref) async {
  final fbUser = await ref.watch(firebaseUserProvider.future);
  if (fbUser == null) return null;

  final prefs = await SharedPreferences.getInstance();
  final known = prefs.getString('backend_user_id_${fbUser.uid}');
  patientsLoadStage.value = '2a mapping=${known != null ? "HIT" : "MISS"}';
  debugPrint('[backendId] mapping ${known != null ? "HIT" : "MISS"} '
      'for uid=${fbUser.uid.substring(0, 6)}…');
  if (known != null) return known;

  final user = await ref.watch(currentUserProvider.future);
  return user?.id;
});

/// A Firebase session exists but identity-svc has no users row for it —
/// the person signed into the app without ever registering (or their
/// account was hard-deleted). _AuthGate maps this to the
/// AccountNotFoundScreen instead of letting RPCs fail one by one.
class AccountNotRegisteredException implements Exception {
  const AccountNotRegisteredException();
  @override
  String toString() => 'ACCOUNT_NOT_REGISTERED';
}

/// Convenience: just the therapist UUID (users.id) as a String, or null
/// if not logged in / not yet resolved. UI code reads this to populate
/// `therapist_id` fields in CreatePatientFile / CreateAudioUpload.
final therapistIdProvider = Provider<String?>((ref) {
  final asyncUser = ref.watch(currentUserProvider);
  // Offline fallback (2026-07-23): recording/session creation must work
  // in airplane mode — the persisted mapping serves the same users.id
  // when the network lookup can't.
  return asyncUser.whenOrNull(data: (u) => u?.id) ??
      ref.watch(backendUserIdProvider).value;
});
