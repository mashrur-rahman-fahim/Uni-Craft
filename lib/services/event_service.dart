import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class EventService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Add a single event for an administrator (notification system removed)
  static Future<String?> addEvent({
    required String title,
    required String description,
    required DateTime date,
    required String groupCode,
    String? location,
    String? category,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        print('No authenticated user');
        return null;
      }

      // Verify user is admin for this group
      final isAdmin = await _verifyAdminAccess(currentUser.uid, groupCode);
      if (!isAdmin) {
        print('User is not admin for this group');
        return null;
      }

      // Get creator's name
      String creatorName = 'Unknown User';
      try {
        final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          creatorName = userData['displayName'] ?? userData['name'] ?? userData['email'] ?? 'Unknown User';
        }
      } catch (e) {
        print('Error getting creator name: $e');
      }

      // Create event document
      final eventDoc = await _firestore.collection('events').add({
        'title': title,
        'description': description,
        'date': Timestamp.fromDate(date),
        'location': location ?? '',
        'category': category ?? 'General',
        'groupCode': groupCode,
        'creatorUid': currentUser.uid,
        'creatorName': creatorName,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'attendees': <String>[],
        'maxAttendees': null,
      });

      // Event created successfully
      print('Event added successfully');
      return eventDoc.id;
    } catch (e) {
      print('Error adding event: $e');
      return null;
    }
  }

  /// Verify if user has admin access for the given group
  static Future<bool> _verifyAdminAccess(String userId, String groupCode) async {
    try {
      final profileQuery = await _firestore
          .collection('Profile')
          .where('uid', isEqualTo: userId)
          .where('code', isEqualTo: groupCode)
          .where('role', isEqualTo: 'Administrator')
          .limit(1)
          .get();

      return profileQuery.docs.isNotEmpty;
    } catch (e) {
      print('Error verifying admin access: $e');
      return false;
    }
  }

  /// Get events for a specific group
  static Stream<List<Map<String, dynamic>>> getEventsForGroup(String groupCode) {
    return _firestore
        .collection('events')
        .where('groupCode', isEqualTo: groupCode)
        .where('isActive', isEqualTo: true)
        .orderBy('date', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// Update an event
  static Future<bool> updateEvent({
    required String eventId,
    required String title,
    required String description,
    required DateTime date,
    String? location,
    String? category,
  }) async {
    try {
      await _firestore.collection('events').doc(eventId).update({
        'title': title,
        'description': description,
        'date': Timestamp.fromDate(date),
        'location': location ?? '',
        'category': category ?? 'General',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error updating event: $e');
      return false;
    }
  }

  /// Delete an event
  static Future<bool> deleteEvent(String eventId) async {
    try {
      await _firestore.collection('events').doc(eventId).update({
        'isActive': false,
        'deletedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error deleting event: $e');
      return false;
    }
  }

  /// Add attendee to event
  static Future<bool> addAttendee(String eventId, String userId) async {
    try {
      await _firestore.collection('events').doc(eventId).update({
        'attendees': FieldValue.arrayUnion([userId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error adding attendee: $e');
      return false;
    }
  }

  /// Remove attendee from event
  static Future<bool> removeAttendee(String eventId, String userId) async {
    try {
      await _firestore.collection('events').doc(eventId).update({
        'attendees': FieldValue.arrayRemove([userId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error removing attendee: $e');
      return false;
    }
  }

  /// Add multiple events at once
  static Future<int> addMultipleEvents({
    required String adminUid,
    required List<Map<String, dynamic>> eventsList,
    bool sendNotification = true,
  }) async {
    int successCount = 0;

    try {
      String? groupCode = await _getGroupCodeFromAdmin(adminUid);
      if (groupCode == null) {
        print('Could not find group code for admin: $adminUid');
        return 0;
      }

      for (var eventData in eventsList) {
        try {
          final eventId = await addEvent(
            title: eventData['title'].toString().trim(),
            description: eventData['description'] ?? '',
            date: eventData['date'] as DateTime,
            groupCode: groupCode,
            category: eventData['type'] ?? 'general',
          );

          if (eventId != null) {
            successCount++;
          }
        } catch (e) {
          print("Error adding event: ${eventData['title']} - $e");
        }
      }

      print("Successfully added $successCount out of ${eventsList.length} events");
      return successCount;
    } catch (e) {
      print("Error adding multiple events: $e");
      return successCount;
    }
  }

  /// Get group code from admin UID
  static Future<String?> _getGroupCodeFromAdmin(String adminUid) async {
    try {
      final doc = await _firestore
          .collection('Profile')
          .doc(adminUid)
          .get();

      if (doc.exists) {
        return doc.data()?['code'] as String?;
      }
    } catch (e) {
      print('Error getting group code from admin: $e');
    }
    return null;
  }

  // ...existing legacy methods for backward compatibility...
}
