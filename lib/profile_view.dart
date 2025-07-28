import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:uni_craft/auth-page.dart';
import 'package:uni_craft/edit_Profile.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  Map<String, dynamic>? profileData;
  bool isLoading = true;
  String? profileImageUrl;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      // First check Profile collection for detailed data
      final profileQuery = await FirebaseFirestore.instance
          .collection('Profile')
          .where('uid', isEqualTo: uid)
          .get();

      if (profileQuery.docs.isNotEmpty) {
        setState(() {
          profileData = profileQuery.docs.first.data();
          profileImageUrl = profileData?['imageLink'] ?? profileData?['photoURL'] ?? profileData?['image'];
          isLoading = false;
        });
        return;
      }

      // Fallback to userProfile collection
      final userProfileQuery = await FirebaseFirestore.instance
          .collection('userProfile')
          .where('uid', isEqualTo: uid)
          .get();

      if (userProfileQuery.docs.isNotEmpty) {
        setState(() {
          profileData = userProfileQuery.docs.first.data();
          profileImageUrl = profileData?['imageLink'] ?? profileData?['photoURL'];
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading profile: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _signOut() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final GoogleSignIn googleSignIn = GoogleSignIn();
      await googleSignIn.signOut();
      await FirebaseAuth.instance.signOut();

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthPage()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _editProfile() {
    if (profileData != null) {
      // Convert profile data to list format expected by EditProfile
      final profileInfo = [
        profileImageUrl ?? 'https://via.placeholder.com/150',
        profileData?['name1'] ?? profileData?['name'] ?? '',
        profileData?['age1'] ?? profileData?['age'] ?? '',
        profileData?['roll'] ?? profileData?['rollNumber'] ?? '',
        profileData?['email'] ?? '',
        profileData?['role'] ?? '',
        profileData?['code'] ?? '',
      ];

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => EditProfile(profileInfo),
        ),
      ).then((_) {
        // Reload profile data when returning from edit
        _loadProfileData();
      });
    }
  }

  Widget _buildInfoCard(String title, String value, IconData icon, {Color? valueColor}) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xff1b6e70).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: const Color(0xff1b6e70),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value.isEmpty ? 'Not provided' : value,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: valueColor ?? Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleBadge(String role) {
    Color roleColor;
    IconData roleIcon;

    switch (role.toLowerCase()) {
      case 'administrator':
        roleColor = Colors.red;
        roleIcon = Icons.admin_panel_settings;
        break;
      case 'co-administrator':
        roleColor = Colors.orange;
        roleIcon = Icons.supervisor_account;
        break;
      case 'general member':
        roleColor = Colors.blue;
        roleIcon = Icons.person;
        break;
      default:
        roleColor = Colors.grey;
        roleIcon = Icons.help_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: roleColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: roleColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(roleIcon, size: 16, color: roleColor),
          const SizedBox(width: 4),
          Text(
            role,
            style: TextStyle(
              color: roleColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double screenW = MediaQuery.of(context).size.width;
    double screenH = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xffb8d8d8),
      appBar: AppBar(
        backgroundColor: const Color(0xffb8d8d8),
        title: const Text(
          'My Profile',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _editProfile,
            icon: const Icon(Icons.edit, color: Color(0xff1b6e70)),
            tooltip: 'Edit Profile',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                _signOut();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Sign Out'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : profileData == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.person_off,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No profile data found',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pushReplacementNamed('/homepage');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xff1b6e70),
                        ),
                        child: const Text(
                          'Set Up Profile',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      // Profile Header
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            // Profile Image
                            Stack(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xff1b6e70),
                                      width: 4,
                                    ),
                                  ),
                                  child: CircleAvatar(
                                    radius: 60,
                                    backgroundColor: Colors.grey[300],
                                    backgroundImage: profileImageUrl != null && profileImageUrl!.isNotEmpty
                                        ? CachedNetworkImageProvider(profileImageUrl!)
                                        : null,
                                    child: profileImageUrl == null || profileImageUrl!.isEmpty
                                        ? const Icon(
                                            Icons.person,
                                            size: 60,
                                            color: Colors.grey,
                                          )
                                        : null,
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: const BoxDecoration(
                                      color: Color(0xff1b6e70),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.verified,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Name
                            Text(
                              profileData?['name1'] ?? profileData?['name'] ?? 'Unknown User',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Role Badge
                            _buildRoleBadge(profileData?['role'] ?? 'Unknown'),
                            const SizedBox(height: 8),

                            // Email
                            Text(
                              profileData?['email'] ?? '',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Profile Information Cards
                      _buildInfoCard(
                        'Full Name',
                        profileData?['name1'] ?? profileData?['name'] ?? '',
                        Icons.person,
                      ),
                      _buildInfoCard(
                        'Age',
                        profileData?['age1'] ?? profileData?['age'] ?? '',
                        Icons.cake,
                      ),
                      _buildInfoCard(
                        'Roll Number',
                        profileData?['roll'] ?? profileData?['rollNumber'] ?? '',
                        Icons.numbers,
                      ),
                      _buildInfoCard(
                        'Email Address',
                        profileData?['email'] ?? '',
                        Icons.email,
                      ),
                      _buildInfoCard(
                        'Role',
                        profileData?['role'] ?? '',
                        Icons.work,
                        valueColor: const Color(0xff1b6e70),
                      ),

                      // Join Code (if applicable)
                      if (profileData?['code'] != null && profileData!['code'].toString().isNotEmpty)
                        _buildInfoCard(
                          profileData?['role'] == 'Administrator' ? 'Generated Code' : 'Join Code',
                          profileData!['code'].toString(),
                          Icons.qr_code,
                          valueColor: Colors.purple,
                        ),

                      const SizedBox(height: 32),

                      // Action Buttons
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _editProfile,
                                icon: const Icon(Icons.edit, color: Colors.white),
                                label: const Text(
                                  'Edit Profile',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xff1b6e70),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _signOut,
                                icon: const Icon(Icons.logout, color: Colors.red),
                                label: const Text(
                                  'Sign Out',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.red),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
    );
  }
}

