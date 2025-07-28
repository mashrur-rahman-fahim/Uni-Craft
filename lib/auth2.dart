import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uni_craft/dashboard.dart';
import 'package:uni_craft/services/members_service.dart';
import 'Homepage.dart';

class Authpage2 extends StatefulWidget {
  const Authpage2({super.key});

  @override
  State<Authpage2> createState() => _AuthpageState2();
}

class _AuthpageState2 extends State<Authpage2> {
  final currentUser = FirebaseAuth.instance;

  var c1 = false, c2 = false, c3 = false;
  String collect1 = " ";
  var role, code, uid_admin;
  var snap = false;

  @override
  Widget build(BuildContext context) {
    double screenW = MediaQuery.of(context).size.width;
    double screenH = MediaQuery.of(context).size.height;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              height: screenH,
              width: screenW,
              child: FutureBuilder<bool>(
                future: _checkUserAccess(),
                builder: (context, accessSnapshot) {
                  // Handle loading state
                  if (accessSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  // If user doesn't have access or error occurred, redirect to Homepage
                  if (!accessSnapshot.hasData || !accessSnapshot.data!) {
                    return Homepage();
                  }

                  // User has access, proceed with normal auth flow
                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('Profile') // Use Profile collection for consistency
                        .snapshots(),
                    builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                      // Handle loading state
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      // Handle error state
                      if (snapshot.hasError) {
                        print('StreamBuilder error: ${snapshot.error}');
                        return Homepage(); // Fallback to Homepage on error
                      }

                      // Handle no data state
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Homepage(); // No user profiles, go to Homepage
                      }

                      try {
                        final res = snapshot.data!.docs.toList();

                        // Safely find user profile
                        for (var r in res) {
                          final data = r.data();
                          if (data is Map<String, dynamic> &&
                              data['uid'] == currentUser.currentUser?.uid) {
                            role = data['role'];
                            code = data['code'] ?? data['joinCode']; // Handle both field names
                            snap = true;
                            break;
                          }
                        }

                        // Safely find admin user
                        if (code != null) {
                          for (var i in res) {
                            final data = i.data();
                            if (data is Map<String, dynamic> &&
                                code == (data['code'] ?? data['joinCode']) &&
                                data['role'] == "Administrator") {
                              uid_admin = data['uid'];
                              break;
                            }
                          }
                        }

                        // Navigate based on user profile existence and role
                        if (snap == true && role != null) {
                          snap = false;
                          return Dashboard(role, uid_admin, code);
                        } else {
                          return Homepage();
                        }
                      } catch (e) {
                        print('Error processing user profile data: $e');
                        return Homepage(); // Fallback to Homepage on processing error
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Check if current user still has access to the group
  Future<bool> _checkUserAccess() async {
    try {
      final currentAuthUser = currentUser.currentUser;
      if (currentAuthUser == null) {
        return false; // No authenticated user
      }

      // Check if user still exists in the Profile collection (active member)
      final member = await MembersService.getCurrentMember();
      if (member == null) {
        print('User not found in group - redirecting to homepage');
        return false; // User has been removed from group
      }

      // Check if user is still active
      if (!member.isActive) {
        print('User account is inactive - redirecting to homepage');
        return false; // User account is deactivated
      }

      return true; // User has valid access
    } catch (e) {
      print('Error checking user access: $e');
      return false; // Error occurred, deny access for security
    }
  }
}
