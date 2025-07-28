import 'package:cloud_firestore/cloud_firestore.dart';

enum PollStatus {
  active,
  closed,
  draft,
}

class PollOption {
  final String id;
  final String text;
  final int votes;
  final List<String> voters; // UIDs of users who voted for this option

  PollOption({
    required this.id,
    required this.text,
    this.votes = 0,
    this.voters = const [],
  });

  factory PollOption.fromMap(Map<String, dynamic> data, String id) {
    return PollOption(
      id: id,
      text: data['text'] ?? '',
      votes: data['votes'] ?? 0,
      voters: List<String>.from(data['voters'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'votes': votes,
      'voters': voters,
    };
  }

  PollOption copyWith({
    String? id,
    String? text,
    int? votes,
    List<String>? voters,
  }) {
    return PollOption(
      id: id ?? this.id,
      text: text ?? this.text,
      votes: votes ?? this.votes,
      voters: voters ?? this.voters,
    );
  }
}

class Poll {
  final String id;
  final String title;
  final String description;
  final String creatorUid;
  final String creatorName;
  final String joinCode;
  final List<PollOption> options;
  final PollStatus status;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final bool allowMultipleVotes;
  final bool showResults;
  final bool anonymousVoting;
  final int totalVotes;
  final List<String> voters; // All users who have voted

  Poll({
    required this.id,
    required this.title,
    required this.description,
    required this.creatorUid,
    required this.creatorName,
    required this.joinCode,
    required this.options,
    this.status = PollStatus.active,
    required this.createdAt,
    this.expiresAt,
    this.allowMultipleVotes = false,
    this.showResults = true,
    this.anonymousVoting = false,
    this.totalVotes = 0,
    this.voters = const [],
  });

  factory Poll.fromFirestore(Map<String, dynamic> data, String documentId) {
    return Poll(
      id: documentId,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      creatorUid: data['creatorUid'] ?? '',
      creatorName: data['creatorName'] ?? '',
      joinCode: data['joinCode'] ?? '',
      options: (data['options'] as List<dynamic>? ?? [])
          .asMap()
          .entries
          .map((entry) => PollOption.fromMap(
              Map<String, dynamic>.from(entry.value), entry.key.toString()))
          .toList(),
      status: _parseStatus(data['status']),
      createdAt: _parseTimestamp(data['createdAt']),
      expiresAt: _parseTimestamp(data['expiresAt']),
      allowMultipleVotes: data['allowMultipleVotes'] ?? false,
      showResults: data['showResults'] ?? true,
      anonymousVoting: data['anonymousVoting'] ?? false,
      totalVotes: data['totalVotes'] ?? 0,
      voters: List<String>.from(data['voters'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'creatorUid': creatorUid,
      'creatorName': creatorName,
      'joinCode': joinCode,
      'options': options.map((option) => option.toMap()).toList(),
      'status': _statusToString(status),
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'allowMultipleVotes': allowMultipleVotes,
      'showResults': showResults,
      'anonymousVoting': anonymousVoting,
      'totalVotes': totalVotes,
      'voters': voters,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static PollStatus _parseStatus(dynamic status) {
    if (status == null) return PollStatus.active;
    switch (status.toString().toLowerCase()) {
      case 'closed':
        return PollStatus.closed;
      case 'draft':
        return PollStatus.draft;
      default:
        return PollStatus.active;
    }
  }

  static String _statusToString(PollStatus status) {
    switch (status) {
      case PollStatus.active:
        return 'active';
      case PollStatus.closed:
        return 'closed';
      case PollStatus.draft:
        return 'draft';
    }
  }

  static DateTime _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return DateTime.now();
    if (timestamp is Timestamp) return timestamp.toDate();
    if (timestamp is String) return DateTime.tryParse(timestamp) ?? DateTime.now();
    return DateTime.now();
  }

  bool get isActive => status == PollStatus.active && !isExpired;
  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);
  bool get canVote => isActive;
  bool get canEdit => status == PollStatus.draft;

  bool hasUserVoted(String userUid) {
    return voters.contains(userUid);
  }

  Poll copyWith({
    String? id,
    String? title,
    String? description,
    String? creatorUid,
    String? creatorName,
    String? joinCode,
    List<PollOption>? options,
    PollStatus? status,
    DateTime? createdAt,
    DateTime? expiresAt,
    bool? allowMultipleVotes,
    bool? showResults,
    bool? anonymousVoting,
    int? totalVotes,
    List<String>? voters,
  }) {
    return Poll(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      creatorUid: creatorUid ?? this.creatorUid,
      creatorName: creatorName ?? this.creatorName,
      joinCode: joinCode ?? this.joinCode,
      options: options ?? this.options,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      allowMultipleVotes: allowMultipleVotes ?? this.allowMultipleVotes,
      showResults: showResults ?? this.showResults,
      anonymousVoting: anonymousVoting ?? this.anonymousVoting,
      totalVotes: totalVotes ?? this.totalVotes,
      voters: voters ?? this.voters,
    );
  }

  double getOptionPercentage(int optionIndex) {
    if (totalVotes == 0 || optionIndex >= options.length) return 0.0;
    return (options[optionIndex].votes / totalVotes) * 100;
  }

  PollOption? getWinningOption() {
    if (options.isEmpty) return null;
    return options.reduce((a, b) => a.votes > b.votes ? a : b);
  }
}
