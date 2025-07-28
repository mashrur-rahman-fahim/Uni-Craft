import 'package:cloud_firestore/cloud_firestore.dart';

enum MemberRole {
  administrator,
  coAdministrator,
  generalMember,
}

class Member {
  final String uid;
  final String name;
  final String email;
  final String rollNumber;
  final String photoURL;
  final MemberRole role;
  final String joinCode;
  final DateTime joinedAt;
  final DateTime? lastActive;
  final bool isActive;

  Member({
    required this.uid,
    required this.name,
    required this.email,
    required this.rollNumber,
    required this.photoURL,
    required this.role,
    required this.joinCode,
    required this.joinedAt,
    this.lastActive,
    this.isActive = true,
  });

  factory Member.fromFirestore(Map<String, dynamic> data, String documentId) {
    return Member(
      uid: data['uid'] ?? '',
      name: data['name1'] ?? data['name'] ?? '',
      email: data['email'] ?? '',
      rollNumber: data['roll'] ?? data['rollNumber'] ?? '',
      photoURL: data['imageLink'] ?? data['photoURL'] ?? '',
      role: _parseRole(data['role'] ?? ''),
      joinCode: data['code'] ?? data['joinCode'] ?? '',
      joinedAt: _parseTimestamp(data['createdAt'] ?? data['joinedAt']),
      lastActive: _parseTimestamp(data['lastActive']),
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'name1': name,
      'name': name,
      'email': email,
      'roll': rollNumber,
      'rollNumber': rollNumber,
      'imageLink': photoURL,
      'photoURL': photoURL,
      'role': roleToString(role),
      'code': joinCode,
      'joinCode': joinCode,
      'createdAt': Timestamp.fromDate(joinedAt),
      'joinedAt': Timestamp.fromDate(joinedAt),
      'lastActive': lastActive != null ? Timestamp.fromDate(lastActive!) : null,
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static MemberRole _parseRole(String roleString) {
    switch (roleString.toLowerCase()) {
      case 'administrator':
        return MemberRole.administrator;
      case 'co-administrator':
        return MemberRole.coAdministrator;
      default:
        return MemberRole.generalMember;
    }
  }

  static DateTime _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return DateTime.now();
    if (timestamp is Timestamp) return timestamp.toDate();
    if (timestamp is String) return DateTime.tryParse(timestamp) ?? DateTime.now();
    return DateTime.now();
  }

  static String roleToString(MemberRole role) {
    switch (role) {
      case MemberRole.administrator:
        return 'Administrator';
      case MemberRole.coAdministrator:
        return 'Co-Administrator';
      case MemberRole.generalMember:
        return 'General member';
    }
  }

  String get roleDisplayName => roleToString(role);

  bool get isAdmin => role == MemberRole.administrator;
  bool get isCoAdmin => role == MemberRole.coAdministrator;
  bool get isGeneralMember => role == MemberRole.generalMember;

  // Proper hierarchy logic
  bool canRemove(Member targetMember) {
    // Cannot remove yourself
    if (uid == targetMember.uid) return false;

    // Administrator can remove Co-Admin and General Members
    if (isAdmin) {
      return targetMember.isCoAdmin || targetMember.isGeneralMember;
    }

    // Co-Administrator can only remove General Members
    if (isCoAdmin) {
      return targetMember.isGeneralMember;
    }

    // General Members cannot remove anyone
    return false;
  }

  bool canChangeRole(Member targetMember) {
    // Cannot change your own role
    if (uid == targetMember.uid) return false;

    // Only Administrator can change roles
    return isAdmin && !targetMember.isAdmin;
  }

  List<MemberRole> getAvailableRolesToAssign(Member targetMember) {
    // Only Administrator can assign roles
    if (!isAdmin || uid == targetMember.uid) return [];

    // Administrator can assign any role except Administrator to others
    return [MemberRole.coAdministrator, MemberRole.generalMember];
  }

  Member copyWith({
    String? uid,
    String? name,
    String? email,
    String? rollNumber,
    String? photoURL,
    MemberRole? role,
    String? joinCode,
    DateTime? joinedAt,
    DateTime? lastActive,
    bool? isActive,
  }) {
    return Member(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      rollNumber: rollNumber ?? this.rollNumber,
      photoURL: photoURL ?? this.photoURL,
      role: role ?? this.role,
      joinCode: joinCode ?? this.joinCode,
      joinedAt: joinedAt ?? this.joinedAt,
      lastActive: lastActive ?? this.lastActive,
      isActive: isActive ?? this.isActive,
    );
  }
}
