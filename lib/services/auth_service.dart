import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Enhanced Google Sign In configuration
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId: '932823267060-arbbasq58hd9gctpd3mjt33ff2n2l3eu.apps.googleusercontent.com',
  );

  // Email/Password Sign In method
  static Future<UserCredential> signInWithEmail(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        await _storeUserData(userCredential.user!, 'email');
      }

      return userCredential;
    } catch (e) {
      debugPrint('Email sign in error: $e');
      rethrow;
    }
  }

  // Email/Password Registration method
  static Future<UserCredential> registerWithEmail(String email, String password, String displayName) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        // Update display name
        await userCredential.user!.updateDisplayName(displayName);
        await userCredential.user!.reload();

        await _storeUserData(userCredential.user!, 'email');
      }

      return userCredential;
    } catch (e) {
      debugPrint('Email registration error: $e');
      rethrow;
    }
  }

  // Enhanced Google Sign In with authentication method linking
  static Future<UserCredential?> signInWithGoogle() async {
    try {
      debugPrint('Starting Google Sign In process...');

      // Clear any cached sign-in state
      await _googleSignIn.signOut();
      debugPrint('Cleared cached Google Sign In state');

      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      debugPrint('Google Sign In account result: ${googleUser?.email ?? 'null'}');

      if (googleUser == null) {
        debugPrint('User cancelled Google Sign In');
        return null;
      }

      // Obtain the auth details from the request
      GoogleSignInAuthentication googleAuth;
      try {
        googleAuth = await googleUser.authentication;
        debugPrint('Successfully obtained Google authentication');
      } catch (e) {
        debugPrint('Error getting Google authentication: $e');
        await _googleSignIn.disconnect();
        await Future.delayed(const Duration(milliseconds: 500));

        final retryUser = await _googleSignIn.signIn();
        if (retryUser == null) {
          throw FirebaseAuthException(
            code: 'sign_in_failed',
            message: 'Failed to complete Google sign in',
          );
        }
        googleAuth = await retryUser.authentication;
      }

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Check if current user exists and try to link accounts
      User? currentUser = _auth.currentUser;
      if (currentUser != null && currentUser.email == googleUser.email) {
        try {
          // Try to link the Google credential to existing account
          await currentUser.linkWithCredential(credential);
          debugPrint('Successfully linked Google account to existing email/password account');

          await _storeUserData(currentUser, 'google');
          return await _handleLinkedAccountResponse(currentUser);
        } catch (e) {
          if (e is FirebaseAuthException && e.code == 'credential-already-in-use') {
            // Credential is already linked, just sign in
            return await _auth.signInWithCredential(credential);
          }
          debugPrint('Error linking accounts: $e');
        }
      }

      // Sign in with Google credential
      UserCredential result = await _auth.signInWithCredential(credential);
      debugPrint('Successfully signed in with Google');

      // Store additional user data
      if (result.user != null) {
        await _storeUserData(result.user!, 'google');
      }

      return result;
    } catch (e) {
      debugPrint('Google Sign In error: $e');

      if (e is FirebaseAuthException) {
        if (e.code == 'account-exists-with-different-credential') {
          throw FirebaseAuthException(
            code: 'account-exists-with-different-credential',
            message: 'An account already exists with this email. Please sign in with your email and password first, then you can link your Google account from the profile settings.',
          );
        }
      }

      rethrow;
    }
  }

  // Helper method to handle linked account response
  static Future<UserCredential?> _handleLinkedAccountResponse(User user) async {
    // Since we can't create UserCredential directly, we'll return null
    // and handle the navigation in the calling method
    // The user is already signed in, so we don't need to return a UserCredential
    await _storeUserData(user, 'google');
    return null; // Caller should check if user is signed in via FirebaseAuth.instance.currentUser
  }

  // Method to link Google account to existing email/password account
  static Future<bool> linkGoogleAccount() async {
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return false;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await currentUser.linkWithCredential(credential);

      // Update user data to reflect linked account
      await _firestore.collection('users').doc(currentUser.uid).update({
        'linkedAccounts': FieldValue.arrayUnion(['google.com']),
        'googleEmail': googleUser.email,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      debugPrint('Error linking Google account: $e');
      return false;
    }
  }

  // Method to unlink Google account
  static Future<bool> unlinkGoogleAccount() async {
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      await currentUser.unlink('google.com');

      // Update user data
      await _firestore.collection('users').doc(currentUser.uid).update({
        'linkedAccounts': FieldValue.arrayRemove(['google.com']),
        'googleEmail': FieldValue.delete(),
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      debugPrint('Error unlinking Google account: $e');
      return false;
    }
  }

  // Enhanced user data storage
  static Future<void> _storeUserData(User user, String signInMethod) async {
    try {
      DocumentReference userRef = _firestore.collection('users').doc(user.uid);

      // Check if user document exists
      DocumentSnapshot userDoc = await userRef.get();

      Map<String, dynamic> userData = {
        'uid': user.uid,
        'email': user.email,
        'displayName': user.displayName ?? '',
        'photoURL': user.photoURL,
        'lastSignIn': FieldValue.serverTimestamp(),
        'signInMethod': signInMethod,
      };

      if (userDoc.exists) {
        // Update existing user
        userData['lastUpdated'] = FieldValue.serverTimestamp();

        // Add to linked accounts if not already present
        List<dynamic> linkedAccounts = userDoc.get('linkedAccounts') ?? [];
        if (!linkedAccounts.contains('$signInMethod.com')) {
          userData['linkedAccounts'] = FieldValue.arrayUnion(['$signInMethod.com']);
        }

        await userRef.update(userData);
      } else {
        // Create new user document
        userData.addAll({
          'createdAt': FieldValue.serverTimestamp(),
          'linkedAccounts': ['$signInMethod.com'],
          'isActive': true,
        });
        await userRef.set(userData);
      }
    } catch (e) {
      debugPrint('Error storing user data: $e');
    }
  }

  // Check linked accounts for current user
  static Future<List<String>> getLinkedAccounts() async {
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser == null) return [];

      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (userDoc.exists) {
        List<dynamic> linkedAccounts = userDoc.get('linkedAccounts') ?? [];
        return linkedAccounts.cast<String>();
      }
      return [];
    } catch (e) {
      debugPrint('Error getting linked accounts: $e');
      return [];
    }
  }

  // Password reset
  static Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      debugPrint('Error sending password reset email: $e');
      rethrow;
    }
  }

  // Get current user
  static User? getCurrentUser() {
    return _auth.currentUser;
  }

  // Sign out from all providers
  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      debugPrint('Error signing out: $e');
    }
  }
}
