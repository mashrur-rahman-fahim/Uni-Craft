import 'package:flutter/material.dart';
import '../models/member.dart';

class MembersUtils {
  /// Generates a color based on member role
  static Color getRoleColor(MemberRole role) {
    switch (role) {
      case MemberRole.administrator:
        return Colors.blue;
      case MemberRole.coAdministrator:
        return Colors.orange;
      case MemberRole.generalMember:
        return Colors.green;
    }
  }

  /// Gets the appropriate icon for a member role
  static IconData getRoleIcon(MemberRole role) {
    switch (role) {
      case MemberRole.administrator:
        return Icons.admin_panel_settings;
      case MemberRole.coAdministrator:
        return Icons.supervisor_account;
      case MemberRole.generalMember:
        return Icons.person;
    }
  }

  /// Formats a duration for display (e.g., "2 hours ago", "3 days ago")
  static String formatTimeDifference(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return '$years year${years == 1 ? '' : 's'} ago';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '$months month${months == 1 ? '' : 's'} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }

  /// Validates if a user can perform admin actions
  static bool canPerformAdminActions(Member? currentUser, Member targetMember) {
    if (currentUser == null) return false;
    if (currentUser.uid == targetMember.uid) return false; // Can't act on self

    // Only admins and co-admins can perform admin actions
    return currentUser.isAdmin || currentUser.isCoAdmin;
  }

  /// Validates if a user can change roles
  static bool canChangeRole(Member? currentUser, Member targetMember) {
    if (currentUser == null) return false;
    if (currentUser.uid == targetMember.uid) return false; // Can't change own role

    // Only administrators can change roles
    return currentUser.isAdmin;
  }

  /// Gets permission level for display
  static String getPermissionLevel(MemberRole role) {
    switch (role) {
      case MemberRole.administrator:
        return 'Full Access - Can manage all members and content';
      case MemberRole.coAdministrator:
        return 'Limited Admin - Can manage general members and content';
      case MemberRole.generalMember:
        return 'Standard Access - Can view and participate';
    }
  }

  /// Sorts members by priority (admin first, then co-admin, then general)
  static List<Member> sortMembersByPriority(List<Member> members, String? currentUserUid) {
    final sortedMembers = List<Member>.from(members);

    sortedMembers.sort((a, b) {
      // Current user always first
      if (a.uid == currentUserUid) return -1;
      if (b.uid == currentUserUid) return 1;

      // Then by role priority
      final roleOrder = {
        MemberRole.administrator: 0,
        MemberRole.coAdministrator: 1,
        MemberRole.generalMember: 2,
      };

      final roleComparison = (roleOrder[a.role] ?? 2).compareTo(roleOrder[b.role] ?? 2);
      if (roleComparison != 0) return roleComparison;

      // Finally by name alphabetically
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return sortedMembers;
  }

  /// Filters members based on search query
  static List<Member> filterMembers(List<Member> members, String query) {
    if (query.isEmpty) return members;

    final searchQuery = query.toLowerCase();
    return members.where((member) {
      return member.name.toLowerCase().contains(searchQuery) ||
             member.rollNumber.toLowerCase().contains(searchQuery) ||
             member.email.toLowerCase().contains(searchQuery) ||
             member.roleDisplayName.toLowerCase().contains(searchQuery);
    }).toList();
  }

  /// Generates member statistics
  static Map<String, dynamic> generateMemberStatistics(List<Member> members) {
    int totalMembers = members.length;
    int administrators = 0;
    int coAdministrators = 0;
    int generalMembers = 0;
    int activeToday = 0;
    int activeThisWeek = 0;

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = now.subtract(Duration(days: 7));

    for (var member in members) {
      // Count by role
      switch (member.role) {
        case MemberRole.administrator:
          administrators++;
          break;
        case MemberRole.coAdministrator:
          coAdministrators++;
          break;
        case MemberRole.generalMember:
          generalMembers++;
          break;
      }

      // Count activity
      if (member.lastActive != null) {
        if (member.lastActive!.isAfter(todayStart)) {
          activeToday++;
        }
        if (member.lastActive!.isAfter(weekStart)) {
          activeThisWeek++;
        }
      }
    }

    return {
      'total': totalMembers,
      'administrators': administrators,
      'coAdministrators': coAdministrators,
      'generalMembers': generalMembers,
      'activeToday': activeToday,
      'activeThisWeek': activeThisWeek,
      'inactiveMembers': totalMembers - activeThisWeek,
    };
  }

  /// Validates member data
  static String? validateMemberData({
    required String name,
    required String email,
    required String rollNumber,
  }) {
    if (name.trim().isEmpty) {
      return 'Name cannot be empty';
    }

    if (email.trim().isEmpty) {
      return 'Email cannot be empty';
    }

    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      return 'Please enter a valid email address';
    }

    if (rollNumber.trim().isEmpty) {
      return 'Roll number cannot be empty';
    }

    return null; // No validation errors
  }

  /// Gets appropriate card elevation based on role
  static double getCardElevation(MemberRole role, bool isCurrentUser) {
    if (isCurrentUser) return 12.0;

    switch (role) {
      case MemberRole.administrator:
        return 10.0;
      case MemberRole.coAdministrator:
        return 8.0;
      case MemberRole.generalMember:
        return 6.0;
    }
  }
}
