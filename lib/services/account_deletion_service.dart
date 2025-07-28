import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

class AccountDeletionService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Completely delete user account and all associated data
  static Future<Map<String, dynamic>> deleteAccountCompletely({
    required String password, // Required for reauthentication
    String? providerId, // 'google.com' for Google users, null for email/password
  }) async {
    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        return {
          'success': false,
          'message': 'No user is currently signed in',
        };
      }

      final String uid = currentUser.uid;
      final String? email = currentUser.email;

      // Step 1: Reauthenticate user (required for account deletion)
      await _reauthenticateUser(currentUser, password, providerId);

      // Step 2: Delete all user-related data from Firestore
      await _deleteUserDataFromFirestore(uid);

      // Step 3: Delete user files from Firebase Storage
      await _deleteUserFilesFromStorage(uid);

      // Step 4: Remove user from all groups and chats
      await _removeUserFromGroupsAndChats(uid);

      // Step 5: Delete notices created by user
      await _deleteUserNotices(uid);

      // Step 6: Clean up any other user-specific data
      await _cleanupMiscellaneousData(uid);

      // Step 7: Finally, delete the Firebase Authentication account
      await currentUser.delete();

      return {
        'success': true,
        'message': 'Account deleted successfully',
        'deletedEmail': email,
      };
    } catch (e) {
      debugPrint('Error deleting account: $e');
      return {
        'success': false,
        'message': _getErrorMessage(e),
      };
    }
  }

  /// Reauthenticate user before deletion (required by Firebase)
  static Future<void> _reauthenticateUser(User user, String password, String? providerId) async {
    try {
      AuthCredential credential;

      if (providerId == 'google.com') {
        // For Google users, we need to get fresh credentials
        throw FirebaseAuthException(
          code: 'google-reauthentication-required',
          message: 'Please sign out and sign back in with Google to delete your account',
        );
      } else {
        // For email/password users
        if (user.email == null) {
          throw FirebaseAuthException(
            code: 'no-email',
            message: 'Unable to reauthenticate: no email found',
          );
        }
        credential = EmailAuthProvider.credential(
          email: user.email!,
          password: password,
        );
      }

      await user.reauthenticateWithCredential(credential);
    } catch (e) {
      debugPrint('Reauthentication failed: $e');
      rethrow;
    }
  }

  /// Delete all user data from Firestore collections
  static Future<void> _deleteUserDataFromFirestore(String uid) async {
    final WriteBatch batch = _firestore.batch();

    try {
      // Delete from Profile collection
      final profileDoc = _firestore.collection('Profile').doc(uid);
      batch.delete(profileDoc);

      // Delete from users collection (if exists)
      final userDoc = _firestore.collection('users').doc(uid);
      batch.delete(userDoc);

      // Delete user's personal settings/preferences
      final settingsQuery = await _firestore
          .collection('userSettings')
          .where('userId', isEqualTo: uid)
          .get();
      
      for (final doc in settingsQuery.docs) {
        batch.delete(doc.reference);
      }

      // Delete user's study materials
      final studyMaterialsQuery = await _firestore
          .collection('studyMaterials')
          .where('uploadedBy', isEqualTo: uid)
          .get();
      
      for (final doc in studyMaterialsQuery.docs) {
        batch.delete(doc.reference);
      }

      // Delete user's calendar events
      final eventsQuery = await _firestore
          .collection('events')
          .where('createdBy', isEqualTo: uid)
          .get();
      
      for (final doc in eventsQuery.docs) {
        batch.delete(doc.reference);
      }

      // Delete user's polls
      final pollsQuery = await _firestore
          .collection('polls')
          .where('createdBy', isEqualTo: uid)
          .get();
      
      for (final doc in pollsQuery.docs) {
        batch.delete(doc.reference);
      }

      // Commit all deletions
      await batch.commit();
      debugPrint('Successfully deleted user data from Firestore');
    } catch (e) {
      debugPrint('Error deleting user data from Firestore: $e');
      rethrow;
    }
  }

  /// Delete user files from Firebase Storage
  static Future<void> _deleteUserFilesFromStorage(String uid) async {
    try {
      // Delete user's profile picture
      try {
        await _storage.ref('profile_pictures/$uid').delete();
      } catch (e) {
        debugPrint('Profile picture not found or already deleted: $e');
      }

      // Delete user's uploaded files
      try {
        final ListResult result = await _storage.ref('user_uploads/$uid').listAll();
        for (final Reference fileRef in result.items) {
          await fileRef.delete();
        }
        
        // Delete the folder itself
        for (final Reference folderRef in result.prefixes) {
          await _deleteStorageFolder(folderRef);
        }
      } catch (e) {
        debugPrint('User uploads folder not found or already deleted: $e');
      }

      // Delete study materials uploaded by user
      try {
        final ListResult materialResult = await _storage.ref('study_materials').listAll();
        for (final Reference fileRef in materialResult.items) {
          final metadata = await fileRef.getMetadata();
          if (metadata.customMetadata?['uploadedBy'] == uid) {
            await fileRef.delete();
          }
        }
      } catch (e) {
        debugPrint('Error deleting study materials: $e');
      }

      debugPrint('Successfully deleted user files from Storage');
    } catch (e) {
      debugPrint('Error deleting user files from Storage: $e');
      rethrow;
    }
  }

  /// Helper method to recursively delete storage folders
  static Future<void> _deleteStorageFolder(Reference folderRef) async {
    final ListResult result = await folderRef.listAll();
    
    for (final Reference fileRef in result.items) {
      await fileRef.delete();
    }
    
    for (final Reference subFolderRef in result.prefixes) {
      await _deleteStorageFolder(subFolderRef);
    }
  }

  /// Remove user from all groups and chats
  static Future<void> _removeUserFromGroupsAndChats(String uid) async {
    try {
      // Remove from groups where user is a member
      final groupMembersQuery = await _firestore
          .collection('groups')
          .where('members', arrayContains: uid)
          .get();

      final WriteBatch batch = _firestore.batch();

      for (final doc in groupMembersQuery.docs) {
        batch.update(doc.reference, {
          'members': FieldValue.arrayRemove([uid]),
          'memberCount': FieldValue.increment(-1),
        });
      }

      // Remove from admin groups (transfer ownership or delete group)
      final adminGroupsQuery = await _firestore
          .collection('groups')
          .where('adminId', isEqualTo: uid)
          .get();

      for (final doc in adminGroupsQuery.docs) {
        final data = doc.data();
        final List<dynamic> members = data['members'] ?? [];
        
        if (members.length > 1) {
          // Transfer ownership to another member
          final newAdmin = members.firstWhere((member) => member != uid);
          batch.update(doc.reference, {
            'adminId': newAdmin,
            'members': FieldValue.arrayRemove([uid]),
            'memberCount': FieldValue.increment(-1),
          });
        } else {
          // Delete the group if no other members
          batch.delete(doc.reference);
        }
      }

      // Delete user's chat messages
      final messagesQuery = await _firestore
          .collection('messages')
          .where('senderId', isEqualTo: uid)
          .get();

      for (final doc in messagesQuery.docs) {
        batch.delete(doc.reference);
      }

      // Remove from chat participants
      final chatsQuery = await _firestore
          .collection('chats')
          .where('participants', arrayContains: uid)
          .get();

      for (final doc in chatsQuery.docs) {
        batch.update(doc.reference, {
          'participants': FieldValue.arrayRemove([uid]),
        });
      }

      await batch.commit();
      debugPrint('Successfully removed user from groups and chats');
    } catch (e) {
      debugPrint('Error removing user from groups and chats: $e');
      rethrow;
    }
  }

  /// Delete notices created by the user
  static Future<void> _deleteUserNotices(String uid) async {
    try {
      final noticesQuery = await _firestore
          .collection('notices')
          .where('authorId', isEqualTo: uid)
          .get();

      final WriteBatch batch = _firestore.batch();

      for (final doc in noticesQuery.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      debugPrint('Successfully deleted user notices');
    } catch (e) {
      debugPrint('Error deleting user notices: $e');
      rethrow;
    }
  }

  /// Clean up any other user-specific data
  static Future<void> _cleanupMiscellaneousData(String uid) async {
    try {
      final WriteBatch batch = _firestore.batch();

      // Remove user from any attendance records
      final attendanceQuery = await _firestore
          .collection('attendance')
          .where('userId', isEqualTo: uid)
          .get();
      
      for (final doc in attendanceQuery.docs) {
        batch.delete(doc.reference);
      }

      // Remove user's device tokens
      final tokensQuery = await _firestore
          .collection('deviceTokens')
          .where('userId', isEqualTo: uid)
          .get();
      
      for (final doc in tokensQuery.docs) {
        batch.delete(doc.reference);
      }

      // Remove user's notification preferences
      final notificationPrefsQuery = await _firestore
          .collection('notificationPreferences')
          .where('userId', isEqualTo: uid)
          .get();
      
      for (final doc in notificationPrefsQuery.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      debugPrint('Successfully cleaned up miscellaneous user data');
    } catch (e) {
      debugPrint('Error cleaning up miscellaneous data: $e');
      rethrow;
    }
  }

  /// Get user-friendly error message
  static String _getErrorMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'wrong-password':
          return 'Incorrect password. Please try again.';
        case 'user-not-found':
          return 'User account not found.';
        case 'requires-recent-login':
          return 'Please sign out and sign back in before deleting your account.';
        case 'google-reauthentication-required':
          return 'For Google accounts, please sign out and sign back in before deleting your account.';
        case 'too-many-requests':
          return 'Too many failed attempts. Please try again later.';
        case 'network-request-failed':
          return 'Network error. Please check your connection and try again.';
        default:
          return 'Authentication error: ${error.message}';
      }
    }
    return 'An unexpected error occurred: ${error.toString()}';
  }

  /// Check if account can be deleted (optional validation)
  static Future<Map<String, dynamic>> canDeleteAccount() async {
    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        return {
          'canDelete': false,
          'reason': 'No user is currently signed in',
        };
      }

      // Check if user is admin of any groups
      final adminGroupsQuery = await _firestore
          .collection('groups')
          .where('adminId', isEqualTo: currentUser.uid)
          .get();

      if (adminGroupsQuery.docs.isNotEmpty) {
        return {
          'canDelete': true,
          'hasAdminGroups': true,
          'groupCount': adminGroupsQuery.docs.length,
          'warning': 'You are an admin of ${adminGroupsQuery.docs.length} group(s). Group ownership will be transferred to another member or the group will be deleted if you are the only member.',
        };
      }

      return {
        'canDelete': true,
        'hasAdminGroups': false,
      };
    } catch (e) {
      return {
        'canDelete': false,
        'reason': 'Error checking account status: ${e.toString()}',
      };
    }
  }
}
