import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/members_service.dart';
import '../Homepage.dart';

class AccessControlService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Check if current user has valid access to group features
  static Future<bool> hasValidAccess() async {
    try {
      final currentAuthUser = _auth.currentUser;
      if (currentAuthUser == null) {
        return false; // No authenticated user
      }

      // Check if user still exists in the group
      final member = await MembersService.getCurrentMember();
      if (member == null) {
        print('User not found in group - access denied');
        return false; // User has been removed from group
      }

      // Check if user account is still active
      if (!member.isActive) {
        print('User account is inactive - access denied');
        return false; // User account is deactivated
      }

      return true; // User has valid access
    } catch (e) {
      print('Error checking user access: $e');
      return false; // Error occurred, deny access for security
    }
  }

  // Redirect to homepage if user doesn't have access
  static Future<void> checkAccessAndRedirect(BuildContext context) async {
    final hasAccess = await hasValidAccess();
    if (!hasAccess && context.mounted) {
      // Clear navigation stack and go to homepage
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/',
        (route) => false,
      );
    }
  }

  // Widget wrapper that checks access before showing content
  static Widget buildAccessControlledWidget({
    required BuildContext context,
    required Widget child,
    Widget? fallbackWidget,
  }) {
    return FutureBuilder<bool>(
      future: hasValidAccess(),
      builder: (context, snapshot) {
        // Show loading indicator while checking access
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // If user doesn't have access, show fallback or redirect
        if (!snapshot.hasData || !snapshot.data!) {
          // Redirect to homepage after a short delay
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const Homepage()),
                (route) => false,
              );
            }
          });

          return fallbackWidget ?? const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red),
                  SizedBox(height: 16),
                  Text(
                    'Access Denied',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'You no longer have access to this group.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }

        // User has valid access, show the content
        return child;
      },
    );
  }
}
