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

import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grpc/grpc.dart' as grpc;

import '../generated/identity/v1/identity.pb.dart' as identity_pb;
import 'grpc_provider.dart';
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
    return await identityClient.getUserByFirebaseUID(
      identity_pb.GetUserByFirebaseUIDRequest(firebaseUid: firebaseUser.uid),
    );
  } on grpc.GrpcError catch (e) {
    // Self-heal for orphan users: Firebase Auth has them, but the
    // identity-svc PG row is missing. This happens if a previous
    // CreateUser silently failed (network, auth, etc.) — login still
    // appeared to succeed at the time but no PG row was written.
    // We auto-register here so subsequent calls just work.
    if (e.code == grpc.StatusCode.notFound) {
      debugPrint(
          'currentUserProvider: user ${firebaseUser.uid} not found in '
          'identity-svc, attempting auto-register');
      // Split Firebase displayName into first/last so identity-svc's
      // auto-org-provisioning gets a real "First Last Org" instead of
      // the email-local fallback ("dar Org"). Falls back to empty if
      // Firebase has no displayName (email/password signup w/o a name).
      final displayName = (firebaseUser.displayName ?? '').trim();
      String firstName = '';
      String lastName = '';
      if (displayName.isNotEmpty) {
        final parts = displayName.split(RegExp(r'\s+'));
        firstName = parts.first;
        if (parts.length > 1) {
          lastName = parts.sublist(1).join(' ');
        }
      }
      try {
        return await identityClient.createUser(identity_pb.CreateUserRequest(
          firebaseUid: firebaseUser.uid,
          email: firebaseUser.email ?? '',
          role: identity_pb.UserRole.USER_ROLE_THERAPIST,
          firstName: firstName,
          lastName: lastName,
          uiLanguage: 'pl',
          timezone: 'Europe/Warsaw',
          hasAcceptedTos: true,
        ));
      } catch (regErr) {
        debugPrint('currentUserProvider: auto-register failed: $regErr');
        rethrow;
      }
    }
    debugPrint('currentUserProvider failed: $e');
    rethrow;
  } catch (e) {
    debugPrint('currentUserProvider failed: $e');
    rethrow;
  }
});

/// Convenience: just the therapist UUID (users.id) as a String, or null
/// if not logged in / not yet resolved. UI code reads this to populate
/// `therapist_id` fields in CreatePatientFile / CreateAudioUpload.
final therapistIdProvider = Provider<String?>((ref) {
  final asyncUser = ref.watch(currentUserProvider);
  return asyncUser.whenOrNull(data: (u) => u?.id);
});
