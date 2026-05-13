import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:labirynt_premium/src/models/user_profile.dart';
import 'package:labirynt_premium/src/models/favorite_item.dart';

// Provider for Firestore instance
final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

// Provider for UserRepository
final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(ref.watch(firestoreProvider));
});

class UserRepository {
  final FirebaseFirestore _firestore;

  UserRepository(this._firestore);

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  /// Fetches a user profile by UID. Returns null if not found.
  Future<UserProfile?> getUser(String uid) async {
    try {
      final doc = await _usersCollection.doc(uid).get();
      if (doc.exists) {
        return UserProfile.fromDocument(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Error fetching user: $e');
    }
  }

  /// Creates a new user profile document.
  Future<void> createUser(UserProfile user) async {
    try {
      await _usersCollection.doc(user.uid).set(user.toMap());
    } catch (e) {
      throw Exception('Error creating user: $e');
    }
  }

  /// Updates specific fields in the user profile.
  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    try {
      await _usersCollection.doc(uid).set(data, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Error updating user: $e');
    }
  }

  DateTime? _lastUpdate;

  /// Updates the last seen timestamp for the user.
  /// Throttled to once every 4 minutes by default to save Firestore writes.
  Future<void> updateLastSeen(String uid, {bool force = false}) async {
    final now = DateTime.now();
    if (!force &&
        _lastUpdate != null &&
        now.difference(_lastUpdate!) < const Duration(minutes: 4)) {
      return;
    }

    try {
      _lastUpdate = now;
      await _usersCollection.doc(uid).update({
        'lastSeenAt': FieldValue.serverTimestamp(),
        'isOnline': true,
      });
    } catch (e) {
      // Fail silently for activity tracking to not disrupt user experience
      debugPrint('Error updating lastSeen: $e');
    }
  }

  /// Explicitly sets the user as offline.
  Future<void> setOffline(String uid) async {
    try {
      // Set to real current time but mark as offline boolean.
      // This allows the UI to say "seen seconds ago" while showing offline status immediately.
      _lastUpdate = null;
      await _usersCollection.doc(uid).update({
        'lastSeenAt': FieldValue.serverTimestamp(),
        'isOnline': false,
      });
    } catch (e) {
      debugPrint('Error setting offline: $e');
    }
  }

  /// Synchronizes the user login with Firestore.
  Future<void> syncUser(auth.User firebaseUser) async {
    final uid = firebaseUser.uid;
    final docRef = _usersCollection.doc(uid);

    final doc = await docRef.get();

    if (!doc.exists) {
      // New User
      final newUser = UserProfile(
        uid: uid,
        email: firebaseUser.email ?? '',
        displayName: firebaseUser.displayName,
        photoUrl: firebaseUser.photoURL,
        createdAt: DateTime.now(),
        lastLoginAt: DateTime.now(),
      );
      await docRef.set(newUser.toMap());
    } else {
      // Existing User - Update Last Login
      final data = doc.data() as Map<String, dynamic>;

      final updates = <String, dynamic>{
        'lastLoginAt': Timestamp.fromDate(DateTime.now()),
      };

      // Sync photoUrl and displayName if they are missing in Firestore but exist in Auth
      if ((data['photoUrl'] == null || (data['photoUrl'] as String).isEmpty) &&
          firebaseUser.photoURL != null &&
          firebaseUser.photoURL!.isNotEmpty) {
        updates['photoUrl'] = firebaseUser.photoURL;
      }

      if ((data['displayName'] == null ||
              (data['displayName'] as String).isEmpty) &&
          firebaseUser.displayName != null &&
          firebaseUser.displayName!.isNotEmpty) {
        updates['displayName'] = firebaseUser.displayName;
      }

      await docRef.update(updates);
    }
  }

  /// Toggles a question in the user's favorites list (Full Sync).
  Future<void> toggleFavorite(String uid, FavoriteItem item) async {
    final docRef = _usersCollection.doc(uid);
    final doc = await docRef.get();
    if (!doc.exists) return;

    final user = UserProfile.fromDocument(doc);
    final existingIndex = user.favoritesRaw.indexWhere(
      (f) => f['questionId'] == item.questionId,
    );

    if (existingIndex != -1) {
      await docRef.update({
        'favorites': FieldValue.arrayRemove([user.favoritesRaw[existingIndex]]),
      });
    } else {
      await docRef.update({
        'favorites': FieldValue.arrayUnion([item.toJson()]),
      });
    }
  }

  /// Marks a question as seen (Persistence).
  Future<void> markQuestionAsSeen(String uid, int questionId) async {
    try {
      await _usersCollection.doc(uid).update({
        'seenQuestions': FieldValue.arrayUnion([questionId]),
      });
    } catch (e) {
      debugPrint('Error marking question as seen: $e');
    }
  }

  /// Resets seen questions history for the user.
  Future<void> resetSeenQuestions(String uid) async {
    try {
      await _usersCollection.doc(uid).update({'seenQuestions': []});
    } catch (e) {
      debugPrint('Error resetting seen questions: $e');
    }
  }

  Future<void> updateFavorite(String uid, FavoriteItem item) async {
    final docRef = _usersCollection.doc(uid);
    final doc = await docRef.get();
    if (!doc.exists) return;

    final user = UserProfile.fromDocument(doc);
    final updatedFavorites = user.favoritesRaw.map((f) {
      if (f['questionId'] == item.questionId) {
        return item.toJson();
      }
      return f;
    }).toList();

    await docRef.update({'favorites': updatedFavorites});
  }

  /// Writes the full favorites list to Firestore (atomic full-state sync).
  Future<void> setFavorites(String uid, List<FavoriteItem> items) async {
    try {
      await _usersCollection.doc(uid).update({
        'favorites': items.map((e) => e.toJson()).toList(),
      });
    } catch (e) {
      debugPrint('UserRepository: Error setting favorites: $e');
    }
  }

  /// Deletes the user document from Firestore.
  Future<void> deleteUser(String uid) async {
    try {
      await _usersCollection.doc(uid).delete();
    } catch (e) {
      throw Exception('Error deleting user: $e');
    }
  }

  /// Resets user data to a fresh state, as if the account was just created.
  /// Preserves identity (uid, email, displayName, photoUrl) and session tokens.
  Future<void> resetUser(String uid) async {
    try {
      await _usersCollection.doc(uid).update({
        // Game data
        'favorites': [],
        'seenQuestions': [],
        'freeQuizTokens': 0,

        // Duo / Pair data
        'pairIds': [],
        'activePairId': null,
        'partnerId': null,
        'pairId': null, // legacy field
        // Premium pair sharing
        'premiumPairId': null,
        'premiumPairChangedAt': null,

        // Onboarding & preferences
        'onboardingComplete': false,
        'goals': [],
        'relationshipStatus': null,
        'attributionSource': null,
        'partnerIsNearby': false,

        // Reset timestamp
        'resetAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw Exception('Error resetting user: $e');
    }
  }

  /// Stream of user profile for real-time updates.
  Stream<UserProfile?> userProfileStream(String uid) {
    return _usersCollection.doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserProfile.fromDocument(doc);
    });
  }

  /// Updates the session token for multi-device login protection.
  Future<void> updateSessionToken(String uid, String token) async {
    try {
      await _usersCollection.doc(uid).update({'currentSessionToken': token});
    } catch (e) {
      debugPrint('Error updating session token: $e');
    }
  }

  /// Consumes a free quiz token for the user.
  Future<bool> consumeFreeQuizToken(String uid) async {
    try {
      final doc = await _usersCollection.doc(uid).get();
      if (!doc.exists) return false;

      final currentTokens = doc.data()?['freeQuizTokens'] ?? 0;
      if (currentTokens > 0) {
        await _usersCollection.doc(uid).update({
          'freeQuizTokens': FieldValue.increment(-1),
        });
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error consuming quiz token: $e');
      return false;
    }
  }
}
