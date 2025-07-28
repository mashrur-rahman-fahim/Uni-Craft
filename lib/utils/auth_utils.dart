import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthUtils {
  // Safe Google Sign In wrapper to prevent PigeonUserDetails errors
  static Future<UserCredential?> safeGoogleSignIn() async {
    try {
      // Clear any existing state that might cause pigeon issues
      final GoogleSignIn googleSignIn = GoogleSignIn();
      await googleSignIn.signOut();

      // Force a fresh sign-in process
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn().timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException('Google sign-in timed out'),
      );

      if (googleUser == null) {
        return null; // User cancelled
      }

      // Safely get authentication with proper error handling
      GoogleSignInAuthentication? googleAuth;
      try {
        googleAuth = await googleUser.authentication.timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw TimeoutException('Authentication timed out'),
        );
      } catch (e) {
        // Handle specific pigeon-related errors
        if (e.toString().contains('PigeonUserDetails') ||
            e.toString().contains('List<Object?>')) {
          // Clear the Google Sign In cache and retry once
          await googleSignIn.disconnect();
          await Future.delayed(const Duration(milliseconds: 500));

          final retryUser = await googleSignIn.signIn();
          if (retryUser == null) return null;

          googleAuth = await retryUser.authentication;
        } else {
          rethrow;
        }
      }

      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        throw Exception('Failed to get authentication tokens');
      }

      // Create credential and sign in
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await FirebaseAuth.instance.signInWithCredential(credential);
    } catch (e) {
      print('SafeGoogleSignIn error: $e');
      rethrow;
    }
  }

  // Safe user profile creation with type checking
  static Future<void> safeCreateUserProfile(User user, {String? displayName}) async {
    try {
      // Check if profile exists first
      final existingProfile = await FirebaseFirestore.instance
          .collection('userProfile')
          .where('uid', isEqualTo: user.uid)
          .get()
          .timeout(const Duration(seconds: 10));

      if (existingProfile.docs.isNotEmpty) {
        print('User profile already exists');
        return;
      }

      // Create new profile with safe data handling
      final profileData = <String, dynamic>{
        'uid': user.uid,
        'email': user.email ?? '',
        'name': displayName ?? user.displayName ?? '',
        'photoURL': user.photoURL ?? '',
        'role': '', // Empty initially, will be set during profile setup
        'age': '',
        'rollNumber': '',
        'joinCode': '',
        'createdAt': FieldValue.serverTimestamp(),
        'isProfileComplete': false,
      };

      await FirebaseFirestore.instance
          .collection('userProfile')
          .add(profileData)
          .timeout(const Duration(seconds: 10));

      print('User profile created successfully');
    } catch (e) {
      print('Error creating user profile: $e');
      // Don't throw - allow user to continue even if profile creation fails
    }
  }

  // Update profile completion status
  static Future<void> markProfileComplete(String uid) async {
    try {
      final userProfileQuery = await FirebaseFirestore.instance
          .collection('userProfile')
          .where('uid', isEqualTo: uid)
          .get();

      if (userProfileQuery.docs.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('userProfile')
            .doc(userProfileQuery.docs.first.id)
            .update({
          'isProfileComplete': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error marking profile complete: $e');
    }
  }

  // Safe profile existence check
  static Future<bool> safeCheckProfileExists(String uid) async {
    try {
      final profileDoc = await FirebaseFirestore.instance
          .collection('userProfile')
          .where('uid', isEqualTo: uid)
          .get()
          .timeout(const Duration(seconds: 10));

      return profileDoc.docs.isNotEmpty;
    } catch (e) {
      print('Error checking profile existence: $e');
      return false; // Assume profile doesn't exist on error
    }
  }

  // Handle authentication errors with user-friendly messages
  static String getAuthErrorMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
          return 'No user found for that email.';
        case 'wrong-password':
          return 'Wrong password provided.';
        case 'invalid-email':
          return 'The email address is not valid.';
        case 'user-disabled':
          return 'This user account has been disabled.';
        case 'too-many-requests':
          return 'Too many attempts. Please try again later.';
        case 'invalid-credential':
          return 'Invalid email or password.';
        case 'email-already-in-use':
          return 'An account already exists for that email.';
        case 'weak-password':
          return 'The password provided is too weak.';
        case 'account-exists-with-different-credential':
          return 'An account already exists with this email using a different sign-in method.';
        case 'operation-not-allowed':
          return 'This sign-in method is not enabled.';
        case 'network-request-failed':
          return 'Network error. Please check your connection and try again.';
        default:
          return error.message ?? 'An authentication error occurred.';
      }
    } else if (error.toString().contains('PigeonUserDetails') ||
               error.toString().contains('List<Object?>')) {
      return 'There was a platform communication error. Please restart the app and try again.';
    } else if (error.toString().contains('timeout') ||
               error.toString().contains('TimeoutException')) {
      return 'The request timed out. Please check your connection and try again.';
    } else {
      return 'An unexpected error occurred. Please try again.';
    }
  }

  // Show error dialog
  static void showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);

  @override
  String toString() => message;
}
