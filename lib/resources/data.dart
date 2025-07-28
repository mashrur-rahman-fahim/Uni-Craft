import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import '../services/account_deletion_service.dart'; // Import the account deletion service

final FirebaseStorage _storage = FirebaseStorage.instance;
final FirebaseFirestore _firestore = FirebaseFirestore.instance;

class StoreData {
  // Upload image to Firebase Storage with better error handling
  Future<String> uploadImagetoStorage(String childName, Uint8List file) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("User not authenticated");
      }

      // Create unique filename with user ID and timestamp
      String fileName = '${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Use a simpler path structure
      Reference ref = _storage.ref().child('profileImages/$fileName');

      // Set metadata for better organization
      SettableMetadata metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'uploaded_by': user.uid,
          'upload_time': DateTime.now().toIso8601String(),
        },
      );

      print('Uploading image to path: profileImages/$fileName');
      print('User UID: ${user.uid}');

      // Upload with timeout and retry logic
      UploadTask uploadTask = ref.putData(file, metadata);

      // Monitor upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        double progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        print('Upload progress: ${progress.toStringAsFixed(2)}%');
      });

      TaskSnapshot snapshot = await uploadTask.timeout(
        const Duration(minutes: 2),
        onTimeout: () {
          throw Exception('Upload timeout after 2 minutes');
        },
      );

      String downloadUrl = await snapshot.ref.getDownloadURL();
      print('Image uploaded successfully. URL: $downloadUrl');
      return downloadUrl;
    } on FirebaseException catch (e) {
      print("Firebase Storage Error: ${e.code} - ${e.message}");

      // Handle specific Firebase Storage errors
      switch (e.code) {
        case 'storage/unauthorized':
          throw Exception("Storage access denied. Please check Firebase Storage rules.");
        case 'storage/quota-exceeded':
          throw Exception("Storage quota exceeded. Please try again later.");
        case 'storage/invalid-format':
          throw Exception("Invalid image format. Please select a valid image.");
        case 'storage/canceled':
          throw Exception("Upload was canceled. Please try again.");
        default:
          throw Exception("Upload failed: ${e.message}");
      }
    } catch (e) {
      print("General upload error: $e");
      throw Exception("Failed to upload image: $e");
    }
  }

  // Save user profile data
  Future<String> savedData({
    required String token,
    required String name,
    required String roll,
    required String email,
    required String age,
    required Uint8List file,
    required String role,
    required dynamic code,
  }) async {
    try {
      final auth = FirebaseAuth.instance;
      final currentUser = auth.currentUser;

      if (currentUser == null) {
        return "User not authenticated";
      }

      // Validate input data
      if (name.isEmpty || age.isEmpty || roll.isEmpty || email.isEmpty) {
        return "All fields are required";
      }

      // Validate email format
      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
        return "Invalid email format";
      }

      // Upload profile image
      String imageUrl = await uploadImagetoStorage('profileImage_${currentUser.uid}', file);

      // Prepare user data
      Map<String, dynamic> userData = {
        'name': name,
        'age': age,
        'roll': roll,
        'email': email,
        'uid': currentUser.uid,
        'imageLink': imageUrl,
        'role': role,
        'code': code.toString(),
        'token': token,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isActive': true,
      };

      // Save to Profile collection
      await _firestore.collection("Profile").doc(currentUser.uid).set(userData);

      // Also update userProfile collection for consistency
      await _firestore.collection("userProfile").doc(currentUser.uid).set({
        'uid': currentUser.uid,
        'email': email,
        'name': name,
        'photoURL': imageUrl,
        'role': role,
        'isProfileComplete': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return 'Success';
    } catch (err) {
      print("Error saving data: $err");
      return "Error: ${err.toString()}";
    }
  }

  // Get user profile data
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection("Profile").doc(uid).get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      print("Error getting user profile: $e");
      return null;
    }
  }

  // Update user profile
  Future<String> updateUserProfile({
    required String uid,
    required Map<String, dynamic> updates,
  }) async {
    try {
      updates['updatedAt'] = FieldValue.serverTimestamp();
      await _firestore.collection("Profile").doc(uid).update(updates);
      return 'Success';
    } catch (e) {
      print("Error updating profile: $e");
      return "Error: ${e.toString()}";
    }
  }

  // Delete user profile (complete deletion)
  Future<String> deleteUserProfile(String uid) async {
    try {
      // Use the comprehensive account deletion service
      final result = await AccountDeletionService.deleteAccountCompletely(
        password: '', // This will need to be provided by the UI
        providerId: null, // Will be determined by the service
      );
      
      if (result['success']) {
        return 'Success';
      } else {
        return result['message'];
      }
    } catch (e) {
      print("Error deleting profile: $e");
      return "Error: ${e.toString()}";
    }
  }

  // Get users by role
  Future<List<Map<String, dynamic>>> getUsersByRole(String role) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection("Profile")
          .where('role', isEqualTo: role)
          .where('isActive', isEqualTo: true)
          .get();

      return snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data() as Map<String, dynamic>
      }).toList();
    } catch (e) {
      print("Error getting users by role: $e");
      return [];
    }
  }

  // Get users by join code
  Future<List<Map<String, dynamic>>> getUsersByCode(String code) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection("Profile")
          .where('code', isEqualTo: code)
          .where('isActive', isEqualTo: true)
          .get();

      return snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data() as Map<String, dynamic>
      }).toList();
    } catch (e) {
      print("Error getting users by code: $e");
      return [];
    }
  }
}
