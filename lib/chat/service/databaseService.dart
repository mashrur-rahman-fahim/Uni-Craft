import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../model/user.dart';
import '../../services/account_deletion_service.dart';

class DatabaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CollectionReference _userCollection = FirebaseFirestore.instance.collection('Profile');

  // Create a new document for the user with the uid
  Future<void> createUserDoc(String uid, String name, String email, String role) async {
    try {
      final docUser = _userCollection.doc(uid);
      final CustomUser customUser = CustomUser(uid, name, email, role);
      final jsonUser = customUser.toJson();
      await docUser.set(jsonUser, SetOptions(merge: true));
    } catch (e) {
      print("Error creating user document: $e");
      throw e;
    }
  }

  // Register user with proper error handling
  Future<dynamic> registerUser(String name, String email, String password, String role) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password
      );
      User? user = userCredential.user;

      if (user != null) {
        await createUserDoc(user.uid, name, email, role);
        return CustomUser(user.uid, name, email, role);
      }
      return "User creation failed";
    } catch (e) {
      print("Register Error: ${e.toString()}");
      return e.toString();
    }
  }

  // Login user with proper error handling
  Future<dynamic> loginUser(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password
      );
      return result;
    } catch (e) {
      print("Login Error: ${e.toString()}");
      return e.toString();
    }
  }

  // Sign out user
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      print("Sign out error: $e");
      throw e;
    }
  }

  // Map snapshot into CustomUser object
  CustomUser userObjectFromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>?;
    return CustomUser(
      snapshot.id,
      data?['name'] ?? data?['name1'] ?? '',
      data?['email'] ?? '',
      data?['role'] ?? 'General member'
    );
  }

  // Get user by user ID
  Stream<CustomUser> getUserByUserID(String uid) {
    return _userCollection.doc(uid).snapshots().map(userObjectFromSnapshot);
  }

  // Get all users
  Future<List<CustomUser>> getAllUsers() async {
    try {
      QuerySnapshot snapshot = await _userCollection.get();
      return snapshot.docs.map((doc) => userObjectFromSnapshot(doc)).toList();
    } catch (e) {
      print("Error getting all users: $e");
      return [];
    }
  }

  // Get users by join code
  Future<List<CustomUser>> getUsersByCode(String code) async {
    try {
      QuerySnapshot snapshot = await _userCollection
          .where('code', isEqualTo: code)
          .where('isActive', isEqualTo: true)
          .get();
      return snapshot.docs.map((doc) => userObjectFromSnapshot(doc)).toList();
    } catch (e) {
      print("Error getting users by code: $e");
      return [];
    }
  }

  // Get users by role
  Future<List<CustomUser>> getUsersByRole(String role) async {
    try {
      QuerySnapshot snapshot = await _userCollection
          .where('role', isEqualTo: role)
          .where('isActive', isEqualTo: true)
          .get();
      return snapshot.docs.map((doc) => userObjectFromSnapshot(doc)).toList();
    } catch (e) {
      print("Error getting users by role: $e");
      return [];
    }
  }

  // Update user data
  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    try {
      data['updatedAt'] = FieldValue.serverTimestamp();
      await _userCollection.doc(uid).update(data);
    } catch (e) {
      print("Error updating user: $e");
      throw e;
    }
  }

  // Delete user (complete deletion)
  Future<void> deleteUser(String uid) async {
    try {
      // Use the comprehensive account deletion service
      final result = await AccountDeletionService.deleteAccountCompletely(
        password: '', // This will need to be provided by the UI
        providerId: null, // Will be determined by the service
      );
      
      if (!result['success']) {
        throw Exception(result['message']);
      }
    } catch (e) {
      print("Error deleting user: $e");
      throw e;
    }
  }

  // Search users by name or email
  Future<List<CustomUser>> searchUsers(String query) async {
    try {
      // Firebase doesn't support full-text search, so we'll get all users and filter locally
      final allUsers = await getAllUsers();
      return allUsers.where((user) =>
          user.name.toLowerCase().contains(query.toLowerCase()) ||
          user.email.toLowerCase().contains(query.toLowerCase())
      ).toList();
    } catch (e) {
      print("Error searching users: $e");
      return [];
    }
  }

  // Get current user data
  Future<CustomUser?> getCurrentUser() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return null;

      DocumentSnapshot doc = await _userCollection.doc(currentUser.uid).get();
      if (doc.exists) {
        return userObjectFromSnapshot(doc);
      }
      return null;
    } catch (e) {
      print("Error getting current user: $e");
      return null;
    }
  }
}
