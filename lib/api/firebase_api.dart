import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseApi {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Upload file with progress tracking
  static UploadTask? uploadFile(String destination, File file) {
    try {
      final ref = _storage.ref(destination);

      // Add metadata
      final metadata = SettableMetadata(
        contentType: _getContentType(file.path),
        customMetadata: {
          'uploaded_by': _auth.currentUser?.uid ?? 'unknown',
          'upload_time': DateTime.now().toIso8601String(),
        },
      );

      return ref.putFile(file, metadata);
    } on FirebaseException catch (e) {
      print('Firebase upload error: ${e.message}');
      return null;
    } catch (e) {
      print('Upload error: $e');
      return null;
    }
  }

  // Upload bytes with progress tracking
  static UploadTask? uploadBytes(String destination, Uint8List data, {String? contentType}) {
    try {
      final ref = _storage.ref(destination);

      final metadata = SettableMetadata(
        contentType: contentType ?? 'application/octet-stream',
        customMetadata: {
          'uploaded_by': _auth.currentUser?.uid ?? 'unknown',
          'upload_time': DateTime.now().toIso8601String(),
        },
      );

      return ref.putData(data, metadata);
    } on FirebaseException catch (e) {
      print('Firebase upload error: ${e.message}');
      return null;
    } catch (e) {
      print('Upload error: $e');
      return null;
    }
  }

  // Download file URL
  static Future<String?> getDownloadUrl(String path) async {
    try {
      final ref = _storage.ref(path);
      return await ref.getDownloadURL();
    } catch (e) {
      print('Error getting download URL: $e');
      return null;
    }
  }

  // Delete file
  static Future<bool> deleteFile(String path) async {
    try {
      final ref = _storage.ref(path);
      await ref.delete();
      return true;
    } catch (e) {
      print('Error deleting file: $e');
      return false;
    }
  }

  // Get file metadata
  static Future<FullMetadata?> getFileMetadata(String path) async {
    try {
      final ref = _storage.ref(path);
      return await ref.getMetadata();
    } catch (e) {
      print('Error getting metadata: $e');
      return null;
    }
  }

  // List files in directory
  static Future<List<Reference>> listFiles(String path) async {
    try {
      final ref = _storage.ref(path);
      final result = await ref.listAll();
      return result.items;
    } catch (e) {
      print('Error listing files: $e');
      return [];
    }
  }

  // Helper method to determine content type
  static String _getContentType(String filePath) {
    final extension = filePath.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'txt':
        return 'text/plain';
      case 'mp4':
        return 'video/mp4';
      case 'mp3':
        return 'audio/mpeg';
      default:
        return 'application/octet-stream';
    }
  }

  // Firestore operations
  static Future<void> addDocument(String collection, Map<String, dynamic> data) async {
    try {
      await _firestore.collection(collection).add(data);
    } catch (e) {
      print('Error adding document: $e');
      throw e;
    }
  }

  static Future<void> updateDocument(String collection, String docId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection(collection).doc(docId).update(data);
    } catch (e) {
      print('Error updating document: $e');
      throw e;
    }
  }

  static Future<DocumentSnapshot?> getDocument(String collection, String docId) async {
    try {
      return await _firestore.collection(collection).doc(docId).get();
    } catch (e) {
      print('Error getting document: $e');
      return null;
    }
  }

  static Stream<QuerySnapshot> getCollection(String collection) {
    return _firestore.collection(collection).snapshots();
  }
}
