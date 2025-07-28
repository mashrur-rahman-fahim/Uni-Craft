import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/study_material.dart';

class StudyMaterialService {
  static const String _collection = 'study_materials';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get study materials for a specific group code (simplified query)
  Stream<List<StudyMaterial>> getStudyMaterials(String groupCode) {
    return _firestore
        .collection(_collection)
        .where('groupCode', isEqualTo: groupCode)
        .snapshots()
        .map((snapshot) {
      final materials = snapshot.docs
          .map((doc) => StudyMaterial.fromFirestore(doc.data(), doc.id))
          .toList();
      
      // Sort by upload date in memory to avoid index requirement
      materials.sort((a, b) {
        final dateA = DateTime.tryParse(a.uploadDate) ?? DateTime.now();
        final dateB = DateTime.tryParse(b.uploadDate) ?? DateTime.now();
        return dateB.compareTo(dateA); // Descending order (newest first)
      });
      
      return materials;
    });
  }

  // Get materials by type (simplified to avoid composite index)
  Stream<List<StudyMaterial>> getMaterialsByType(String groupCode, String type) {
    return getStudyMaterials(groupCode).map((materials) {
      return materials.where((material) => material.type == type).toList();
    });
  }

  // Add new study material
  Future<bool> addStudyMaterial({
    required String groupCode,
    required String name,
    required String url,
    required String type,
    String? description,
    int? fileSize,
    String? subject,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      // Get uploader's name (removed notification code)
      String uploaderName = 'Unknown User';
      try {
        final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          uploaderName = userData['displayName'] ?? userData['name'] ?? userData['email'] ?? 'Unknown User';
        }
      } catch (e) {
        print('Error getting uploader name: $e');
      }

      final material = StudyMaterial(
        id: '',
        name: name,
        url: url,
        type: type,
        uploaderUid: currentUser.uid,
        uploadDate: DateTime.now().toIso8601String(),
        description: description,
        fileSize: fileSize,
        groupCode: groupCode,
        subject: subject,
        uploaderName: uploaderName,
      );

      // Add material to Firestore
      await _firestore.collection(_collection).add(material.toFirestore());

      // Material uploaded successfully (notification system removed)
      print('Study material uploaded successfully');
      return true;
    } catch (e) {
      print('Error uploading study material: $e');
      return false;
    }
  }

  // Delete study material
  Future<bool> deleteMaterial(String materialId) async {
    try {
      await _firestore.collection(_collection).doc(materialId).delete();
      return true;
    } catch (e) {
      print('Error deleting material: $e');
      return false;
    }
  }

  // Get user role in group
  Future<String?> getUserRole(String groupCode) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return null;

      final querySnapshot = await _firestore
          .collection('Profile')
          .where('uid', isEqualTo: currentUser.uid)
          .where('code', isEqualTo: groupCode)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.data()['role'] as String?;
      }
      return null;
    } catch (e) {
      print('Error getting user role: $e');
      return null;
    }
  }

  // Determine file type from extension
  static String getFileType(String fileName) {
    final extension = fileName.toLowerCase().split('.').last;
    
    const imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg', 'raw', 'jfif', 'pjpeg', 'pjp'];
    
    if (imageExtensions.contains(extension)) {
      return 'image';
    } else if (fileName.startsWith('http')) {
      return 'link';
    } else {
      return 'file';
    }
  }

  // Alternative method using the old Profile collection structure as fallback
  // This ensures backward compatibility if needed
  Future<void> migrateOldData(String groupCode) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      // Check if there are any materials in the new collection
      final existingMaterials = await _firestore
          .collection(_collection)
          .where('groupCode', isEqualTo: groupCode)
          .limit(1)
          .get();

      if (existingMaterials.docs.isNotEmpty) {
        // Already have data in new structure, no need to migrate
        return;
      }

      // Try to get data from old Profile structure
      final profileDocs = await _firestore
          .collection('Profile')
          .where('code', isEqualTo: groupCode)
          .where('role', isEqualTo: 'Administrator')
          .get();

      for (var doc in profileDocs.docs) {
        final data = doc.data();
        int index = 0;
        
        // Extract materials from the old numeric structure
        while (true) {
          final urlKey = '${index * 3}';
          final nameKey = '${index * 3 + 1}';
          final dateKey = '${index * 3 + 2}';
          
          if (!data.containsKey(urlKey) || data[urlKey] == '') {
            break;
          }
          
          final url = data[urlKey] as String?;
          final name = data[nameKey] as String?;
          final date = data[dateKey] as String?;
          
          if (url != null && name != null && url.isNotEmpty && name.isNotEmpty) {
            final type = getFileType(name);
            
            await addStudyMaterial(
              groupCode: groupCode,
              name: name,
              url: url,
              type: type,
              description: 'Migrated from old system',
            );
          }
          
          index++;
        }
      }
    } catch (e) {
      print('Error migrating old data: $e');
    }
  }
}
