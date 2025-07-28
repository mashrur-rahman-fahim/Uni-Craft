import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PollService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Create a new poll (notification system removed)
  static Future<String?> createPoll({
    required String question,
    required List<String> options,
    required String groupCode,
    String? description,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return null;

      // Get creator's name (removed notification code)
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

      // Create poll document
      final pollDoc = await _firestore.collection('polls').add({
        'question': question,
        'options': options,
        'votes': Map<String, int>.fromIterable(
          options,
          key: (option) => option.toString(),
          value: (_) => 0,
        ),
        'voters': <String>[],
        'creatorUid': currentUser.uid,
        'creatorName': creatorName,
        'groupCode': groupCode,
        'description': description ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
      });

      // Poll created successfully (notification system removed)
      print('Poll created successfully');
      return pollDoc.id;
    } catch (e) {
      print('Error creating poll: $e');
      return null;
    }
  }

  /// Get polls for a group
  static Stream<List<Map<String, dynamic>>> getPolls(String groupCode) {
    return _firestore
        .collection('polls')
        .where('groupCode', isEqualTo: groupCode)
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// Vote on a poll
  static Future<bool> voteOnPoll({
    required String pollId,
    required int optionIndex,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      final pollRef = _firestore.collection('polls').doc(pollId);

      return await _firestore.runTransaction((transaction) async {
        final pollDoc = await transaction.get(pollRef);

        if (!pollDoc.exists) {
          throw Exception('Poll not found');
        }

        final pollData = pollDoc.data()!;
        final options = List<Map<String, dynamic>>.from(pollData['options']);
        final voters = List<String>.from(pollData['voters'] ?? []);
        final allowMultipleVotes = pollData['allowMultipleVotes'] ?? false;

        // Check if user already voted
        if (voters.contains(currentUser.uid) && !allowMultipleVotes) {
          throw Exception('User already voted');
        }

        // Check if poll is expired
        if (pollData['expiresAt'] != null) {
          final expiresAt = DateTime.fromMillisecondsSinceEpoch(pollData['expiresAt']);
          if (DateTime.now().isAfter(expiresAt)) {
            throw Exception('Poll has expired');
          }
        }

        // Add vote
        options[optionIndex]['votes'] = (options[optionIndex]['votes'] ?? 0) + 1;
        final optionVoters = List<String>.from(options[optionIndex]['voters'] ?? []);
        if (!optionVoters.contains(currentUser.uid)) {
          optionVoters.add(currentUser.uid);
          options[optionIndex]['voters'] = optionVoters;
        }

        // Add user to voters list if not already there
        if (!voters.contains(currentUser.uid)) {
          voters.add(currentUser.uid);
        }

        // Update poll
        transaction.update(pollRef, {
          'options': options,
          'voters': voters,
          'totalVotes': voters.length,
          'lastVoteAt': FieldValue.serverTimestamp(),
        });

        return true;
      });
    } catch (e) {
      print('Error voting on poll: $e');
      return false;
    }
  }

  /// Close/end a poll
  static Future<bool> closePoll(String pollId) async {
    try {
      await _firestore.collection('polls').doc(pollId).update({
        'isActive': false,
        'closedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error closing poll: $e');
      return false;
    }
  }

  /// Get poll results
  static Future<Map<String, dynamic>?> getPollResults(String pollId) async {
    try {
      final pollDoc = await _firestore.collection('polls').doc(pollId).get();

      if (!pollDoc.exists) return null;

      final data = pollDoc.data()!;
      final options = List<Map<String, dynamic>>.from(data['options']);
      final totalVotes = data['totalVotes'] ?? 0;

      // Calculate percentages
      for (var option in options) {
        final votes = option['votes'] ?? 0;
        option['percentage'] = totalVotes > 0 ? (votes / totalVotes * 100).round() : 0;
      }

      return {
        'id': pollDoc.id,
        'question': data['question'],
        'options': options,
        'totalVotes': totalVotes,
        'createdAt': data['createdAt'],
        'creatorName': data['creatorName'],
        'isActive': data['isActive'],
      };
    } catch (e) {
      print('Error getting poll results: $e');
      return null;
    }
  }
}
