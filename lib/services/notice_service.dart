import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NoticeService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Add a new notice
  static Future<bool> addNotice({
    required String title,
    required String content,
    required String groupCode,
    required String authorId,
    required String authorName,
    required String authorEmail,
    String category = 'general',
    String priority = 'normal',
    List<String> tags = const [],
    DateTime? expiryDate,
    bool sendNotification = true,
  }) async {
    try {
      final noticeData = {
        'title': title.trim(),
        'content': content.trim(),
        'groupCode': groupCode,
        'authorId': authorId,
        'authorName': authorName,
        'authorEmail': authorEmail,
        'category': category,
        'priority': priority,
        'tags': tags,
        'expiryDate': expiryDate,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'viewCount': 0,
        'likeCount': 0,
        'likedBy': <String>[],
        'readBy': <String>[],
      };

      await _firestore.collection('notices').add(noticeData);
      return true;
    } catch (e) {
      print('Error adding notice: $e');
      return false;
    }
  }

  /// Update an existing notice
  static Future<bool> updateNotice({
    required String noticeId,
    required String title,
    required String content,
    String? category,
    String? priority,
    List<String>? tags,
    DateTime? expiryDate,
  }) async {
    try {
      final updateData = {
        'title': title.trim(),
        'content': content.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (category != null) updateData['category'] = category;
      if (priority != null) updateData['priority'] = priority;
      if (tags != null) updateData['tags'] = tags;
      if (expiryDate != null) updateData['expiryDate'] = expiryDate;

      await _firestore.collection('notices').doc(noticeId).update(updateData);
      return true;
    } catch (e) {
      print('Error updating notice: $e');
      return false;
    }
  }

  /// Delete a notice
  static Future<bool> deleteNotice(String noticeId) async {
    try {
      await _firestore.collection('notices').doc(noticeId).delete();
      return true;
    } catch (e) {
      print('Error deleting notice: $e');
      return false;
    }
  }

  /// Get notices stream for a specific group
  static Stream<List<Map<String, dynamic>>> getNoticesStream(String groupCode, bool activeOnly) {
    // Use the simplest possible query to avoid any index requirements
    // Only filter by groupCode, then do all other filtering and sorting client-side
    return _firestore
        .collection('notices')
        .where('groupCode', isEqualTo: groupCode)
        .snapshots()
        .map((snapshot) {
      List<Map<String, dynamic>> notices = snapshot.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            return data;
          })
          .where((notice) => notice['isActive'] == activeOnly)
          .toList();

      // Sort by createdAt client-side
      notices.sort((a, b) {
        final aTime = a['createdAt'];
        final bTime = b['createdAt'];
        
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        
        DateTime aDate, bDate;
        if (aTime is Timestamp) {
          aDate = aTime.toDate();
        } else {
          aDate = aTime as DateTime;
        }
        
        if (bTime is Timestamp) {
          bDate = bTime.toDate();
        } else {
          bDate = bTime as DateTime;
        }
        
        return bDate.compareTo(aDate); // Descending order (newest first)
      });

      return notices;
    });
  }

  /// Get notice statistics
  static Future<Map<String, int>> getNoticeStats(String groupCode) async {
    try {
      // Get all notices for the group and filter client-side to avoid index issues
      final allNotices = await _firestore
          .collection('notices')
          .where('groupCode', isEqualTo: groupCode)
          .get();

      int activeCount = 0;
      int archivedCount = 0;
      int urgentCount = 0;
      int recentCount = 0;

      final DateTime weekAgo = DateTime.now().subtract(const Duration(days: 7));

      for (final doc in allNotices.docs) {
        final data = doc.data();
        final bool isActive = data['isActive'] ?? false;
        final String priority = data['priority'] ?? 'normal';
        final createdAt = data['createdAt'];

        if (isActive) {
          activeCount++;

          if (priority == 'high') {
            urgentCount++;
          }

          // Check if it's recent (created in last 7 days)
          if (createdAt != null) {
            DateTime? createdDate;
            if (createdAt is Timestamp) {
              createdDate = createdAt.toDate();
            }
            if (createdDate != null && createdDate.isAfter(weekAgo)) {
              recentCount++;
            }
          }
        } else {
          archivedCount++;
        }
      }

      return {
        'active': activeCount,
        'archived': archivedCount,
        'total': activeCount + archivedCount,
        'urgent': urgentCount,
        'recent': recentCount,
      };
    } catch (e) {
      print('Error getting notice stats: $e');
      return {
        'active': 0,
        'archived': 0,
        'total': 0,
        'urgent': 0,
        'recent': 0,
      };
    }
  }

  /// Increment view count for a notice
  static Future<bool> incrementViewCount(String noticeId) async {
    try {
      await _firestore.collection('notices').doc(noticeId).update({
        'viewCount': FieldValue.increment(1),
      });

      // Also add current user to readBy list if not already there
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        await _firestore.collection('notices').doc(noticeId).update({
          'readBy': FieldValue.arrayUnion([currentUser.uid]),
        });
      }

      return true;
    } catch (e) {
      print('Error incrementing view count: $e');
      return false;
    }
  }

  /// Toggle like status for a notice
  static Future<bool> toggleLike(String noticeId, String userId) async {
    try {
      final noticeRef = _firestore.collection('notices').doc(noticeId);
      final noticeDoc = await noticeRef.get();

      if (!noticeDoc.exists) return false;

      final data = noticeDoc.data() as Map<String, dynamic>;
      final List<String> likedBy = List<String>.from(data['likedBy'] ?? []);
      final bool isLiked = likedBy.contains(userId);

      if (isLiked) {
        // Remove like
        await noticeRef.update({
          'likedBy': FieldValue.arrayRemove([userId]),
          'likeCount': FieldValue.increment(-1),
        });
      } else {
        // Add like
        await noticeRef.update({
          'likedBy': FieldValue.arrayUnion([userId]),
          'likeCount': FieldValue.increment(1),
        });
      }

      return true;
    } catch (e) {
      print('Error toggling like: $e');
      return false;
    }
  }

  /// Check if a notice is liked by a specific user
  static Future<bool> isLikedByUser(String noticeId, String userId) async {
    try {
      final noticeDoc = await _firestore.collection('notices').doc(noticeId).get();
      if (!noticeDoc.exists) return false;

      final data = noticeDoc.data() as Map<String, dynamic>;
      final List<String> likedBy = List<String>.from(data['likedBy'] ?? []);
      return likedBy.contains(userId);
    } catch (e) {
      print('Error checking like status: $e');
      return false;
    }
  }

  /// Archive expired notices
  static Future<void> archiveExpiredNotices() async {
    try {
      final now = DateTime.now();

      // Get all active notices and filter client-side to avoid index issues
      final activeNotices = await _firestore
          .collection('notices')
          .where('isActive', isEqualTo: true)
          .get();

      final batch = _firestore.batch();
      int expiredCount = 0;

      for (final doc in activeNotices.docs) {
        final data = doc.data();
        final expiryDate = data['expiryDate'];

        if (expiryDate != null) {
          DateTime? expiry;
          if (expiryDate is Timestamp) {
            expiry = expiryDate.toDate();
          } else if (expiryDate is DateTime) {
            expiry = expiryDate;
          }

          if (expiry != null && expiry.isBefore(now)) {
            batch.update(doc.reference, {'isActive': false});
            expiredCount++;
          }
        }
      }

      if (expiredCount > 0) {
        await batch.commit();
        print('Archived $expiredCount expired notices');
      }
    } catch (e) {
      print('Error archiving expired notices: $e');
    }
  }

  /// Get a single notice by ID
  static Future<Map<String, dynamic>?> getNoticeById(String noticeId) async {
    try {
      final doc = await _firestore.collection('notices').doc(noticeId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }
      return null;
    } catch (e) {
      print('Error getting notice by ID: $e');
      return null;
    }
  }

  /// Mark notice as read by user
  static Future<bool> markAsRead(String noticeId, String userId) async {
    try {
      await _firestore.collection('notices').doc(noticeId).update({
        'readBy': FieldValue.arrayUnion([userId]),
      });
      return true;
    } catch (e) {
      print('Error marking notice as read: $e');
      return false;
    }
  }

  /// Get unread notices count for a user
  static Future<int> getUnreadNoticesCount(String groupCode, String userId) async {
    try {
      // Use simple query and filter client-side to avoid index issues
      final notices = await _firestore
          .collection('notices')
          .where('groupCode', isEqualTo: groupCode)
          .get();

      int unreadCount = 0;
      for (final doc in notices.docs) {
        final data = doc.data();
        final bool isActive = data['isActive'] ?? false;
        final List<String> readBy = List<String>.from(data['readBy'] ?? []);

        // Only count active notices that haven't been read by this user
        if (isActive && !readBy.contains(userId)) {
          unreadCount++;
        }
      }

      return unreadCount;
    } catch (e) {
      print('Error getting unread notices count: $e');
      return 0;
    }
  }

  /// Search notices
  static Future<List<Map<String, dynamic>>> searchNotices({
    required String groupCode,
    required String searchQuery,
    String? category,
    String? priority,
    bool activeOnly = true,
  }) async {
    try {
      // Use simple query and filter/sort client-side to avoid index issues
      final snapshot = await _firestore
          .collection('notices')
          .where('groupCode', isEqualTo: groupCode)
          .get();

      List<Map<String, dynamic>> notices = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();

      // Filter by isActive
      notices = notices.where((notice) => notice['isActive'] == activeOnly).toList();

      // Filter by category
      if (category != null && category != 'all') {
        notices = notices.where((notice) => notice['category'] == category).toList();
      }

      // Filter by priority
      if (priority != null && priority != 'all') {
        notices = notices.where((notice) => notice['priority'] == priority).toList();
      }

      // Filter by search query (client-side since Firestore doesn't support full-text search)
      if (searchQuery.isNotEmpty) {
        notices = notices.where((notice) {
          final title = (notice['title'] ?? '').toString().toLowerCase();
          final content = (notice['content'] ?? '').toString().toLowerCase();
          final authorName = (notice['authorName'] ?? '').toString().toLowerCase();
          final query = searchQuery.toLowerCase();

          return title.contains(query) ||
              content.contains(query) ||
              authorName.contains(query);
        }).toList();
      }

      // Sort by createdAt client-side
      notices.sort((a, b) {
        final aTime = a['createdAt'];
        final bTime = b['createdAt'];
        
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        
        DateTime aDate, bDate;
        if (aTime is Timestamp) {
          aDate = aTime.toDate();
        } else {
          aDate = aTime as DateTime;
        }
        
        if (bTime is Timestamp) {
          bDate = bTime.toDate();
        } else {
          bDate = bTime as DateTime;
        }
        
        return bDate.compareTo(aDate); // Descending order (newest first)
      });

      return notices;
    } catch (e) {
      print('Error searching notices: $e');
      return [];
    }
  }
}
