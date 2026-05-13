import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:labirynt_premium/src/features/auth/data/user_repository.dart';

class AuthRepository {
  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  final UserRepository _userRepository;

  AuthRepository(this._firebaseAuth, this._googleSignIn, this._userRepository);

  Stream<User?> authStateChanges() => _firebaseAuth.authStateChanges();
  Stream<User?> userChanges() => _firebaseAuth.userChanges();

  User? get currentUser => _firebaseAuth.currentUser;

  Future<UserCredential?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        final userCredential = await _firebaseAuth.signInWithPopup(
          googleProvider,
        );
        if (userCredential.user != null) {
          await _userRepository.syncUser(userCredential.user!);
        }
        return userCredential;
      } else {
        await _googleSignIn.initialize();
        final GoogleSignInAccount googleUser = await _googleSignIn
            .authenticate();

        final GoogleSignInAuthentication googleAuth = googleUser.authentication;
        final AuthCredential credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );

        final userCredential = await _firebaseAuth.signInWithCredential(
          credential,
        );
        if (userCredential.user != null) {
          await _userRepository.syncUser(userCredential.user!);
        }
        return userCredential;
      }
    } catch (e) {
      debugPrint("Error signing in with Google: $e");
      rethrow;
    }
  }

  Future<UserCredential?> signInWithApple() async {
    try {
      final AuthorizationCredentialAppleID appleCredential =
          await SignInWithApple.getAppleIDCredential(
            scopes: [
              AppleIDAuthorizationScopes.email,
              AppleIDAuthorizationScopes.fullName,
            ],
          );

      final OAuthCredential credential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      final userCredential = await _firebaseAuth.signInWithCredential(
        credential,
      );
      if (userCredential.user != null) {
        await _userRepository.syncUser(userCredential.user!);
      }
      return userCredential;
    } catch (e) {
      debugPrint("Error signing in with Apple: $e");
      rethrow;
    }
  }

  Future<void> signInWithEmailAndPassword(String email, String password) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (credential.user != null) {
        await _userRepository.syncUser(credential.user!);
      }
    } catch (e) {
      debugPrint("Error signing in with Email: $e");
      rethrow;
    }
  }

  Future<void> registerWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (credential.user != null) {
        await _userRepository.syncUser(credential.user!);
      }
    } catch (e) {
      debugPrint("Error registering with Email: $e");
      rethrow;
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } catch (e) {
      debugPrint("Error sending password reset email: $e");
      rethrow;
    }
  }

  Future<UserCredential?> signInAnonymously() async {
    try {
      final userCredential = await _firebaseAuth.signInAnonymously();
      if (userCredential.user != null) {
        await _userRepository.syncUser(userCredential.user!);
      }
      return userCredential;
    } catch (e) {
      debugPrint("Error signing in anonymously: $e");
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user != null) {
        await _userRepository.setOffline(user.uid);
      }
      await Future.wait([_firebaseAuth.signOut(), _googleSignIn.signOut()]);
    } catch (e) {
      debugPrint("Error signing out: $e");
    }
  }

  Future<void> updateDisplayName(String name) async {
    final user = _firebaseAuth.currentUser;
    if (user != null) {
      await user.updateDisplayName(name);
      await _userRepository.updateUser(user.uid, {'displayName': name});
    }
  }

  /// Updates the user's email address.
  /// Firebase sends a verification email to the new address before switching.
  Future<void> updateEmail(String newEmail) async {
    final user = _firebaseAuth.currentUser;
    if (user != null) {
      await user.verifyBeforeUpdateEmail(newEmail);
      // Firestore update happens after the user verifies the new email
    }
  }

  /// Deletes an old Storage file by its download URL.
  /// Silently ignores failures (file may already be deleted or be an external URL).
  Future<void> _deleteOldStorageFile(String? oldUrl) async {
    if (oldUrl == null || !oldUrl.contains('firebasestorage.googleapis.com')) {
      return;
    }
    try {
      await FirebaseStorage.instance.refFromURL(oldUrl).delete();
      debugPrint('[UPLOAD] Deleted old storage file: $oldUrl');
    } catch (e) {
      debugPrint('[UPLOAD] Could not delete old file (may not exist): $e');
    }
  }

  /// Upload profile image - EXACTLY per Firebase official docs
  /// https://firebase.google.com/docs/storage/flutter/upload-files
  Future<String> uploadProfileImage(XFile image) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw FirebaseException(
        plugin: 'auth',
        message: 'User not logged in',
        code: 'no-user',
      );
    }

    // Capture old URL before upload so we can delete it after success
    final oldPhotoUrl = user.photoURL;

    // 1. Create a reference to Firebase Storage bucket
    final storageRef = FirebaseStorage.instance.ref();

    // 2. Create a reference to the file path (unique with timestamp)
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileRef = storageRef.child(
      'user_uploads/${user.uid}/profile_$timestamp.jpg',
    );

    debugPrint('[UPLOAD] Starting upload to: ${fileRef.fullPath}');

    // 3. Create the file metadata
    final metadata = SettableMetadata(contentType: 'image/jpeg');

    try {
      TaskSnapshot snapshot;

      if (kIsWeb) {
        // WEB: Upload raw data using putData()
        final Uint8List data = await image.readAsBytes();
        debugPrint('[UPLOAD] Web: uploading ${data.length} bytes');
        snapshot = await fileRef.putData(data, metadata);
      } else {
        // MOBILE: Upload file using putFile()
        final File file = File(image.path);
        debugPrint('[UPLOAD] Mobile: uploading file from ${file.path}');
        snapshot = await fileRef.putFile(file, metadata);
      }

      // 4. Check upload state
      if (snapshot.state != TaskState.success) {
        throw FirebaseException(
          plugin: 'storage',
          message: 'Upload failed with state: ${snapshot.state}',
          code: 'upload-failed',
        );
      }

      // 5. Get download URL
      final downloadUrl = await fileRef.getDownloadURL();
      debugPrint('[UPLOAD] Success! Download URL: $downloadUrl');

      // 6. Update Firebase Auth user profile
      await user.updatePhotoURL(downloadUrl);
      debugPrint('[UPLOAD] Updated Firebase Auth photoURL');

      // 7. Update Firestore user document
      await _userRepository.updateUser(user.uid, {'photoUrl': downloadUrl});
      debugPrint('[UPLOAD] Updated Firestore photoUrl');

      // 8. Reload user to refresh cache
      await user.reload();
      debugPrint(
        '[UPLOAD] User reloaded. Current photoURL: ${_firebaseAuth.currentUser?.photoURL}',
      );

      // 9. Delete the old profile photo from Storage (after successful upload)
      await _deleteOldStorageFile(oldPhotoUrl);

      return downloadUrl;
    } on FirebaseException catch (e) {
      debugPrint('[UPLOAD] FirebaseException: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('[UPLOAD] Unknown error: $e');
      throw FirebaseException(
        plugin: 'storage',
        message: 'Upload failed: $e',
        code: 'unknown',
      );
    }
  }

  /// GDPR Art. 17 - Right to Erasure.
  /// Deletes ALL user data: Storage files, Firestore document, Firebase Auth account.
  Future<void> deleteAccount() async {
    final user = _firebaseAuth.currentUser;
    if (user != null) {
      final uid = user.uid;

      // 1. Delete all files in user's Storage folder (profile photos, etc.)
      try {
        final storageRef = FirebaseStorage.instance.ref('user_uploads/$uid');
        final listResult = await storageRef.listAll();
        for (final item in listResult.items) {
          await item.delete();
        }
        debugPrint(
          '[DELETE] Deleted ${listResult.items.length} Storage files for user $uid',
        );
      } catch (e) {
        // Storage folder may not exist - don't block account deletion
        debugPrint('[DELETE] Could not clean Storage for user $uid: $e');
      }

      // 2. Delete Firestore user document (all personal data)
      await _userRepository.deleteUser(uid);

      // 3. Delete Firebase Auth account (last step - irreversible)
      await user.delete();
    }
  }
}

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final googleSignInProvider = Provider<GoogleSignIn>((ref) {
  return GoogleSignIn.instance;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(firebaseAuthProvider),
    ref.watch(googleSignInProvider),
    ref.watch(userRepositoryProvider),
  );
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).userChanges();
});
