import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/poll.dart';

class PollsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static const String _pollsCollection = 'polls';

  // Create a new poll
  static Future<String?> createPoll({
    required String title,
    required String description,
    required List<String> optionTexts,
    required String joinCode,
    DateTime? expiresAt,
    bool allowMultipleVotes = false,
    bool showResults = true,
    bool anonymousVoting = false,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Get current user's profile for creator name
      final userProfile = await _firestore
          .collection('Profile')
          .where('uid', isEqualTo: currentUser.uid)
          .limit(1)
          .get();

      String creatorName = 'Unknown';
      if (userProfile.docs.isNotEmpty) {
        creatorName = userProfile.docs.first.data()['name1'] ?? 'Unknown';
      }

      // Validate inputs
      if (title.trim().isEmpty) {
        throw Exception('Poll title cannot be empty');
      }
      if (optionTexts.length < 2) {
        throw Exception('Poll must have at least 2 options');
      }
      if (optionTexts.length > 10) {
        throw Exception('Poll cannot have more than 10 options');
      }

      // Create poll options
      final options = optionTexts
          .asMap()
          .entries
          .map((entry) => PollOption(
                id: entry.key.toString(),
                text: entry.value.trim(),
                votes: 0,
                voters: [],
              ))
          .toList();

      // Create poll object
      final poll = Poll(
        id: '', // Will be set by Firestore
        title: title.trim(),
        description: description.trim(),
        creatorUid: currentUser.uid,
        creatorName: creatorName,
        joinCode: joinCode,
        options: options,
        status: PollStatus.active,
        createdAt: DateTime.now(),
        expiresAt: expiresAt,
        allowMultipleVotes: allowMultipleVotes,
        showResults: showResults,
        anonymousVoting: anonymousVoting,
        totalVotes: 0,
        voters: [],
      );

      // Save to Firestore
      final docRef = await _firestore
          .collection(_pollsCollection)
          .add(poll.toFirestore());

      return docRef.id;
    } catch (e) {
      print('Error creating poll: $e');
      rethrow;
    }
  }

  // Get polls by join code
  static Stream<List<Poll>> getPollsByJoinCode(String joinCode) {
    return _firestore
        .collection(_pollsCollection)
        .where('joinCode', isEqualTo: joinCode)
        .snapshots()
        .map((snapshot) {
      final polls = snapshot.docs
          .map((doc) => Poll.fromFirestore(doc.data(), doc.id))
          .toList();

      // Sort by creation date on client side (newest first)
      polls.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return polls;
    });
  }

  // Get a specific poll by ID
  static Future<Poll?> getPollById(String pollId) async {
    try {
      final doc = await _firestore.collection(_pollsCollection).doc(pollId).get();
      if (doc.exists && doc.data() != null) {
        return Poll.fromFirestore(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      print('Error getting poll: $e');
      return null;
    }
  }

  // Vote on a poll
  static Future<bool> voteOnPoll({
    required String pollId,
    required int optionIndex,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      return await _firestore.runTransaction((transaction) async {
        final pollRef = _firestore.collection(_pollsCollection).doc(pollId);
        final pollDoc = await transaction.get(pollRef);

        if (!pollDoc.exists) {
          throw Exception('Poll not found');
        }

        final poll = Poll.fromFirestore(pollDoc.data()!, pollDoc.id);

        // Validate voting conditions
        if (!poll.canVote) {
          throw Exception('This poll is no longer accepting votes');
        }

        if (!poll.allowMultipleVotes && poll.hasUserVoted(currentUser.uid)) {
          throw Exception('You have already voted on this poll');
        }

        if (optionIndex < 0 || optionIndex >= poll.options.length) {
          throw Exception('Invalid option selected');
        }

        // Update poll data
        final updatedOptions = List<PollOption>.from(poll.options);
        final selectedOption = updatedOptions[optionIndex];

        // Add vote to option
        updatedOptions[optionIndex] = selectedOption.copyWith(
          votes: selectedOption.votes + 1,
          voters: [...selectedOption.voters, currentUser.uid],
        );

        // Update poll voters list if not already voted
        List<String> updatedVoters = List<String>.from(poll.voters);
        if (!poll.hasUserVoted(currentUser.uid)) {
          updatedVoters.add(currentUser.uid);
        }

        // Update Firestore document
        transaction.update(pollRef, {
          'options': updatedOptions.map((option) => option.toMap()).toList(),
          'totalVotes': poll.totalVotes + 1,
          'voters': updatedVoters,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        return true;
      });
    } catch (e) {
      print('Error voting on poll: $e');
      rethrow;
    }
  }

  // Update poll status
  static Future<bool> updatePollStatus(String pollId, PollStatus status) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      // Verify user has permission to update poll
      final poll = await getPollById(pollId);
      if (poll == null || poll.creatorUid != currentUser.uid) {
        return false;
      }

      await _firestore.collection(_pollsCollection).doc(pollId).update({
        'status': status == PollStatus.active
            ? 'active'
            : status == PollStatus.closed
                ? 'closed'
                : 'draft',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error updating poll status: $e');
      return false;
    }
  }

  // Delete a poll
  static Future<bool> deletePoll(String pollId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      // Verify user has permission to delete poll
      final poll = await getPollById(pollId);
      if (poll == null || poll.creatorUid != currentUser.uid) {
        return false;
      }

      await _firestore.collection(_pollsCollection).doc(pollId).delete();
      return true;
    } catch (e) {
      print('Error deleting poll: $e');
      return false;
    }
  }

  // Get polls created by current user
  static Stream<List<Poll>> getCurrentUserPolls() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection(_pollsCollection)
        .where('creatorUid', isEqualTo: currentUser.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Poll.fromFirestore(doc.data(), doc.id))
          .toList();
    });
  }

  // Get poll statistics
  static Future<Map<String, dynamic>> getPollStatistics(String joinCode) async {
    try {
      final querySnapshot = await _firestore
          .collection(_pollsCollection)
          .where('joinCode', isEqualTo: joinCode)
          .get();

      int totalPolls = querySnapshot.docs.length;
      int activePolls = 0;
      int closedPolls = 0;
      int totalVotes = 0;

      for (var doc in querySnapshot.docs) {
        final poll = Poll.fromFirestore(doc.data(), doc.id);
        totalVotes += poll.totalVotes;

        switch (poll.status) {
          case PollStatus.active:
            if (!poll.isExpired) activePolls++;
            break;
          case PollStatus.closed:
            closedPolls++;
            break;
          case PollStatus.draft:
            // Don't count drafts in active/closed
            break;
        }
      }

      return {
        'totalPolls': totalPolls,
        'activePolls': activePolls,
        'closedPolls': closedPolls,
        'totalVotes': totalVotes,
      };
    } catch (e) {
      print('Error getting poll statistics: $e');
      return {
        'totalPolls': 0,
        'activePolls': 0,
        'closedPolls': 0,
        'totalVotes': 0,
      };
    }
  }

  // Search polls
  static Future<List<Poll>> searchPolls(String joinCode, String query) async {
    try {
      final querySnapshot = await _firestore
          .collection(_pollsCollection)
          .where('joinCode', isEqualTo: joinCode)
          .get();

      final polls = querySnapshot.docs
          .map((doc) => Poll.fromFirestore(doc.data(), doc.id))
          .where((poll) {
        final searchQuery = query.toLowerCase();
        return poll.title.toLowerCase().contains(searchQuery) ||
               poll.description.toLowerCase().contains(searchQuery) ||
               poll.creatorName.toLowerCase().contains(searchQuery);
      }).toList();

      return polls;
    } catch (e) {
      print('Error searching polls: $e');
      return [];
    }
  }

  // Check if user can vote on poll
  static Future<bool> canUserVote(String pollId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      final poll = await getPollById(pollId);
      if (poll == null) return false;

      return poll.canVote &&
             (poll.allowMultipleVotes || !poll.hasUserVoted(currentUser.uid));
    } catch (e) {
      print('Error checking vote permission: $e');
      return false;
    }
  }
}
