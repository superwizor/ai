import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:labirynt_premium/src/features/auth/data/auth_repository.dart';
import 'package:labirynt_premium/src/features/auth/data/user_repository.dart';
import 'package:labirynt_premium/src/models/user_profile.dart';

/// Provides the current user's profile from Firestore.
/// Returns [null] if the user is not logged in.
final userProfileProvider = StreamProvider<UserProfile?>((ref) async* {
  final authState = ref.watch(authStateProvider);

  // If auth state is loading or error, we can't fetch profile yet.
  if (authState.isLoading || authState.hasError) {
    return;
  }

  final user = authState.value;

  if (user == null) {
    yield null;
  } else {
    // If logged in, watch the user document from Firestore (real-time updates)
    final firestore = ref.watch(firestoreProvider);
    final userDocStream = firestore
        .collection('users')
        .doc(user.uid)
        .snapshots();

    await for (final snapshot in userDocStream) {
      if (snapshot.exists) {
        yield UserProfile.fromDocument(snapshot);
      } else {
        // Document doesn't exist yet (might be syncing), yield null or potentially trigger sync
        // Ideally sync happens at login, but for safety:
        yield null;
      }
    }
  }
});

/// Provides another user's profile from Firestore by their UID.
final otherUserProfileProvider = StreamProvider.family<UserProfile?, String>((
  ref,
  userId,
) async* {
  final firestore = ref.watch(firestoreProvider);
  final userDocStream = firestore.collection('users').doc(userId).snapshots();

  await for (final snapshot in userDocStream) {
    if (snapshot.exists) {
      yield UserProfile.fromDocument(snapshot);
    } else {
      yield null;
    }
  }
});
