import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/member.dart';

class MembersService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user's join code
  static Future<String?> getCurrentUserJoinCode() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return null;

    try {
      final querySnapshot = await _firestore
          .collection('Profile')
          .where('uid', isEqualTo: currentUser.uid)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.data()['code'];
      }
    } catch (e) {
      print('Error getting current user join code: $e');
    }
    return null;
  }

  // Get all members by join code
  static Stream<List<Member>> getMembersByJoinCode(String joinCode) {
    return _firestore
        .collection('Profile')
        .where('code', isEqualTo: joinCode)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Member.fromFirestore(doc.data(), doc.id))
          .where((member) => member.isActive) // Filter active members on client side
          .toList();
    });
  }

  // Get current user's member data
  static Future<Member?> getCurrentMember() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return null;

    try {
      final querySnapshot = await _firestore
          .collection('Profile')
          .where('uid', isEqualTo: currentUser.uid)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        return Member.fromFirestore(doc.data(), doc.id);
      }
    } catch (e) {
      print('Error getting current member: $e');
    }
    return null;
  }

  // Get member by UID
  static Future<Member?> getMemberByUid(String memberUid) async {
    try {
      final querySnapshot = await _firestore
          .collection('Profile')
          .where('uid', isEqualTo: memberUid)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        return Member.fromFirestore(doc.data(), doc.id);
      }
    } catch (e) {
      print('Error getting member by UID: $e');
    }
    return null;
  }

  // Delete a member (with proper hierarchy permissions)
  static Future<bool> deleteMember(String memberUid) async {
    try {
      final currentMember = await getCurrentMember();
      if (currentMember == null) {
        throw Exception('Unable to verify current user permissions');
      }

      // Get the target member to check if current user can remove them
      final targetMember = await getMemberByUid(memberUid);
      if (targetMember == null) {
        throw Exception('Target member not found');
      }

      // Check if current user has permission to remove the target member
      if (!currentMember.canRemove(targetMember)) {
        throw Exception('Insufficient permissions to remove this member');
      }

      final querySnapshot = await _firestore
          .collection('Profile')
          .where('uid', isEqualTo: memberUid)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        await querySnapshot.docs.first.reference.delete();
        return true;
      }
    } catch (e) {
      print('Error deleting member: $e');
    }
    return false;
  }

  // Update member role (only for administrators)
  static Future<bool> updateMemberRole(String memberUid, MemberRole newRole) async {
    try {
      final currentMember = await getCurrentMember();
      if (currentMember == null || !currentMember.isAdmin) {
        throw Exception('Only administrators can update member roles');
      }

      final querySnapshot = await _firestore
          .collection('Profile')
          .where('uid', isEqualTo: memberUid)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        await querySnapshot.docs.first.reference.update({
          'role': Member.roleToString(newRole),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return true;
      }
    } catch (e) {
      print('Error updating member role: $e');
    }
    return false;
  }

  // Update member's last active timestamp
  static Future<void> updateLastActive() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      final querySnapshot = await _firestore
          .collection('Profile')
          .where('uid', isEqualTo: currentUser.uid)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        await querySnapshot.docs.first.reference.update({
          'lastActive': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error updating last active: $e');
    }
  }

  // Get member statistics
  static Future<Map<String, int>> getMemberStatistics(String joinCode) async {
    try {
      final querySnapshot = await _firestore
          .collection('Profile')
          .where('code', isEqualTo: joinCode)
          .where('isActive', isEqualTo: true)
          .get();

      int totalMembers = querySnapshot.docs.length;
      int administrators = 0;
      int coAdministrators = 0;
      int generalMembers = 0;

      for (var doc in querySnapshot.docs) {
        final role = doc.data()['role'] ?? '';
        switch (role.toLowerCase()) {
          case 'administrator':
            administrators++;
            break;
          case 'co-administrator':
            coAdministrators++;
            break;
          default:
            generalMembers++;
            break;
        }
      }

      return {
        'total': totalMembers,
        'administrators': administrators,
        'coAdministrators': coAdministrators,
        'generalMembers': generalMembers,
      };
    } catch (e) {
      print('Error getting member statistics: $e');
      return {
        'total': 0,
        'administrators': 0,
        'coAdministrators': 0,
        'generalMembers': 0,
      };
    }
  }

  // Search members by name or roll number
  static Future<List<Member>> searchMembers(String joinCode, String query) async {
    try {
      final querySnapshot = await _firestore
          .collection('Profile')
          .where('code', isEqualTo: joinCode)
          .where('isActive', isEqualTo: true)
          .get();

      final members = querySnapshot.docs
          .map((doc) => Member.fromFirestore(doc.data(), doc.id))
          .where((member) {
        final searchQuery = query.toLowerCase();
        return member.name.toLowerCase().contains(searchQuery) ||
               member.rollNumber.toLowerCase().contains(searchQuery) ||
               member.email.toLowerCase().contains(searchQuery);
      }).toList();

      return members;
    } catch (e) {
      print('Error searching members: $e');
      return [];
    }
  }
}
