import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:uni_craft/createPoll.dart';
import 'package:uni_craft/study_Materials.dart';
import 'package:uni_craft/viewPoll.dart';
import 'package:uni_craft/calendar.dart';
import 'package:uni_craft/admin_event_manager.dart';
import 'package:uni_craft/chat/chat.dart';
import 'package:uni_craft/notice.dart';
import 'package:uni_craft/profile_view.dart';
import 'package:uni_craft/edit_Profile.dart';
import 'package:uni_craft/members.dart';
import 'package:uni_craft/Credit.dart';
import 'package:uni_craft/widget/developer_credits_dialog.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:uni_craft/services/access_control_service.dart';
import 'package:uni_craft/auth-page.dart';

class Dashboard extends StatefulWidget {
  final String role;
  final String uid_admin;
  final dynamic code;

  const Dashboard(this.role, this.uid_admin, this.code, {super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  final currentUser = FirebaseAuth.instance;
  bool view_more = false;
  int c = 0;
  bool check = true;
  List profile_info = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      await _loadProfileInfo();
    } catch (e) {
      print("Error initializing dashboard data: $e");
    }
  }

  Future<void> _loadProfileInfo() async {
    try {
      final uid = currentUser.currentUser!.uid;

      // First try to get profile data from Profile collection (has imageLink)
      final profileQuery = await FirebaseFirestore.instance
          .collection('Profile')
          .where('uid', isEqualTo: uid)
          .get();

      if (profileQuery.docs.isNotEmpty) {
        setState(() {
          profile_info = [profileQuery.docs.first.data()];
        });
        return;
      }

      // Fallback to userProfile collection if Profile doesn't exist
      final userProfileQuery = await FirebaseFirestore.instance
          .collection('userProfile')
          .where('uid', isEqualTo: uid)
          .get();

      if (userProfileQuery.docs.isNotEmpty) {
        setState(() {
          profile_info = [userProfileQuery.docs.first.data()];
        });
      }
    } catch (e) {
      print("Error loading profile info: $e");
    }
  }

  Future<void> signout() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Clear all authentication data thoroughly
      final GoogleSignIn googleSign = GoogleSignIn();

      // Sign out from Google first
      await googleSign.signOut();

      // Try to disconnect, but don't fail if it doesn't work
      try {
        await googleSign.disconnect();
      } catch (e) {
        print("Google disconnect failed (this is okay): $e");
        // Continue with logout even if disconnect fails
      }

      // Sign out from Firebase
      await FirebaseAuth.instance.signOut();

      // Clear any cached user data
      setState(() {
        profile_info.clear();
      });

      if (mounted) {
        // Navigate directly to AuthPage and clear all routes
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const AuthPage(fromLogout: true), // Add fromLogout flag
            settings: const RouteSettings(name: '/auth'), // Set explicit route name
          ),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showDeveloperCreditsDialog() {
    showDialog(
      context: context,
      builder: (context) => const DeveloperCreditsDialog(),
    );
  }

  void _showDeleteAccountDialog() async {
    Navigator.pop(context); // Close drawer first
    bool confirmDelete = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.red[600]),
              const SizedBox(width: 8),
              const Text("Delete Account"),
            ],
          ),
          content: const Text(
            "Are you sure you want to delete your account? This action cannot be undone and all your data will be permanently removed.",
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text("Cancel", style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text("Delete", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    ) ?? false;

    if (confirmDelete) {
      try {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          // Delete from Profile collection
          await FirebaseFirestore.instance
              .collection('Profile')
              .doc(uid)
              .delete();

          // Delete from userProfile collection
          final userProfileQuery = await FirebaseFirestore.instance
              .collection('userProfile')
              .where('uid', isEqualTo: uid)
              .get();

          for (var doc in userProfileQuery.docs) {
            await doc.reference.delete();
          }

          // Delete Firebase Auth account
          await FirebaseAuth.instance.currentUser?.delete();

          if (mounted) {
            Navigator.of(context).pushNamedAndRemoveUntil(
              '/auth',
              (route) => false,
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Account deleted successfully"),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Error deleting account: ${e.toString()}"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            // Drawer Header - Made more compact and responsive
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xff7a9e9f), Color(0xff1b6e70)],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Flexible(
                          child: Text(
                            "UniCraft",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close, color: Colors.white, size: 22),
                          constraints: const BoxConstraints(
                            minWidth: 40,
                            minHeight: 40,
                          ),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: CircleAvatar(
                        radius: 32,
                        backgroundColor: profile_info.isEmpty
                          ? const Color(0xff1b6e70)
                          : Colors.grey.shade200,
                        child: profile_info.isEmpty
                          ? const Icon(Icons.person, size: 32, color: Colors.white)
                          : _buildCompactProfileAvatar(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            profile_info.isNotEmpty
                                ? (profile_info[0]['name'] ?? 'User')
                                : "Loading...",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            profile_info.isNotEmpty
                                ? (profile_info[0]['email'] ?? 'No email')
                                : "Loading...",
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white70,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              widget.role,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Menu Items - Scrollable section
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    _buildDrawerItem(
                      icon: Icons.person,
                      title: 'View Profile',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ProfileView(),
                          ),
                        );
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.edit,
                      title: 'Edit Profile',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EditProfile(profile_info),
                          ),
                        );
                      },
                    ),
                    const Divider(color: Color(0xffE5E5E5), height: 16, thickness: 0.5),
                    _buildDrawerItem(
                      icon: Icons.settings,
                      title: 'Settings',
                      onTap: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Settings coming soon!")),
                        );
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.help_outline,
                      title: 'Help & Support',
                      onTap: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Help & Support coming soon!")),
                        );
                      },
                    ),
                    const Divider(color: Color(0xffE5E5E5), height: 16, thickness: 0.5),
                    _buildDrawerItem(
                      icon: Icons.code,
                      title: 'Developer Credits',
                      onTap: () {
                        Navigator.pop(context);
                        _showDeveloperCreditsDialog();
                      },
                    ),
                    const Divider(color: Color(0xffE5E5E5), height: 16, thickness: 0.5),
                    _buildDrawerItem(
                      icon: Icons.delete_forever,
                      title: 'Delete Account',
                      textColor: Colors.red,
                      iconColor: Colors.red,
                      onTap: _showDeleteAccountDialog,
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),

            // Bottom Section - Fixed at bottom
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Color(0xffE5E5E5), width: 0.5),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "UniCraft v1.0",
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Made with ❤️ by Mashrur Rahman Fahim",
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? textColor,
    Color? iconColor,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: iconColor ?? const Color(0xff1b6e70),
        size: 20,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textColor ?? const Color(0xff2d3748),
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      horizontalTitleGap: 12,
      minVerticalPadding: 8,
    );
  }

  Widget _buildCompactProfileAvatar() {
    final profileData = profile_info[0];
    final imageUrl = profileData['profile_picture'] ??
                    profileData['imageLink'] ??
                    profileData['photoURL'];

    if (imageUrl != null && imageUrl.toString().isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: imageUrl.toString(),
          width: 64,
          height: 64,
          fit: BoxFit.cover,
          placeholder: (context, url) => const CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xff1b6e70)),
          ),
          errorWidget: (context, url, error) => const Icon(
            Icons.person,
            size: 32,
            color: Color(0xff1b6e70),
          ),
        ),
      );
    }

    return Text(
      profileData['name']?.toString().substring(0, 1).toUpperCase() ?? 'U',
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }

  Widget _buildSmallProfileAvatar() {
    final profileData = profile_info[0];
    final imageUrl = profileData['profile_picture'] ??
                    profileData['imageLink'] ??
                    profileData['photoURL'];

    if (imageUrl != null && imageUrl.toString().isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: imageUrl.toString(),
          width: 60,
          height: 60,
          fit: BoxFit.cover,
          placeholder: (context, url) => const CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xff1b6e70)),
          ),
          errorWidget: (context, url, error) => const Icon(
            Icons.person,
            size: 30,
            color: Color(0xff1b6e70),
          ),
        ),
      );
    }

    return Text(
      profileData['name']?.toString().substring(0, 1).toUpperCase() ?? 'U',
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }

  Widget _buildDashboardCard({
    required String title,
    required String imagePath,
    required VoidCallback onTap,
    required Color color,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = (screenWidth - 48) / 2; // Account for padding and spacing

    return Flexible(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 160,
          width: cardWidth,
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color,
                color.withValues(alpha: 0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.3),
                offset: const Offset(0, 6),
                spreadRadius: 0,
                blurRadius: 15,
              )
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Image.asset(
                  imagePath,
                  height: 40,
                  width: 40,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      _getIconForTitle(title),
                      size: 40,
                      color: Colors.white,
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        offset: Offset(0, 1),
                        blurRadius: 3,
                        color: Colors.black26,
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIconForTitle(String title) {
    switch (title.toLowerCase()) {
      case 'study materials':
        return Icons.book;
      case 'chat':
        return Icons.chat;
      case 'calendar':
        return Icons.calendar_today;
      case 'notice':
        return Icons.notifications;
      case 'members':
        return Icons.people;
      case 'profile':
        return Icons.person;
      case 'create poll':
        return Icons.poll;
      case 'view polls':
        return Icons.bar_chart;
      default:
        return Icons.apps;
    }
  }

  Widget _buildProfileAvatar() {
    if (profile_info.isEmpty) {
      return CircleAvatar(
        radius: 40,
        backgroundColor: const Color(0xff1b6e70),
        child: const Icon(
          Icons.person,
          size: 40,
          color: Colors.white,
        ),
      );
    }

    final profileData = profile_info[0];
    final imageUrl = profileData['profile_picture'] ??
                    profileData['imageLink'] ??
                    profileData['photoURL'];

    if (imageUrl != null && imageUrl.toString().isNotEmpty) {
      return CircleAvatar(
        radius: 40,
        backgroundColor: Colors.grey.shade200,
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: imageUrl.toString(),
            width: 80,
            height: 80,
            fit: BoxFit.cover,
            placeholder: (context, url) => const CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xff1b6e70)),
            ),
            errorWidget: (context, url, error) => const Icon(
              Icons.person,
              size: 40,
              color: Color(0xff1b6e70),
            ),
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: 40,
      backgroundColor: const Color(0xff1b6e70),
      child: Text(
        profileData['name']?.toString().substring(0, 1).toUpperCase() ?? 'U',
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  // ...existing methods...

  @override
  Widget build(BuildContext context) {
    return AccessControlService.buildAccessControlledWidget(
      context: context,
      child: Scaffold(
        backgroundColor: const Color(0xfff8fafc),
        resizeToAvoidBottomInset: false,
        drawer: _buildDrawer(),
        appBar: AppBar(
          title: const Text(
            "Dashboard",
            style: TextStyle(
              fontSize: 20,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu, color: Colors.white, size: 26),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xff7a9e9f), Color(0xff1b6e70)],
              ),
            ),
          ),
          elevation: 0,
          actions: [
            IconButton(
              onPressed: _isLoading ? null : signout,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.logout, color: Colors.white),
              tooltip: "Sign Out",
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                // Hero Welcome Section
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xffffffff), Color(0xfff8fafc)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 15,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: const Color(0xff1b6e70).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: CircleAvatar(
                          radius: 30,
                          backgroundColor: profile_info.isEmpty
                            ? const Color(0xff1b6e70)
                            : Colors.grey.shade200,
                          child: profile_info.isEmpty
                            ? const Icon(Icons.person, size: 30, color: Colors.white)
                            : _buildSmallProfileAvatar(),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Welcome back! 👋",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xff1b6e70),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              profile_info.isNotEmpty
                                  ? (profile_info[0]['name'] ?? 'User')
                                  : "Loading...",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xff2d3748),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xff1b6e70).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    widget.role,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Color(0xff1b6e70),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (widget.role == "Administrator") ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xff059669).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      "Code: ${widget.code}",
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Color(0xff059669),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Admin Tools Section (Only for Administrators)
                if (widget.role == "Administrator") ...[
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xff7a9e9f), Color(0xff5f8ba3)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xff7a9e9f).withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.admin_panel_settings,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                "Administrator Tools",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  final hasAccess = await AccessControlService.hasValidAccess();
                                  if (hasAccess && context.mounted) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => Calendar(widget.uid_admin, widget.role),
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.calendar_today, size: 16),
                                label: const Text("Calendar", style: TextStyle(fontSize: 12)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xff7a9e9f),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  elevation: 2,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  final hasAccess = await AccessControlService.hasValidAccess();
                                  if (hasAccess && context.mounted) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => AdminEventManager(
                                          adminUid: widget.uid_admin,
                                          role: widget.role,
                                        ),
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.event_note, size: 16),
                                label: const Text("Events", style: TextStyle(fontSize: 12)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xff7a9e9f),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  elevation: 2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Quick Access Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Quick Access",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xff1b6e70),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xff1b6e70).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          "${_getVisibleCardsCount()} Features",
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xff1b6e70),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Dashboard Cards Grid
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    children: [
                      // First Row
                      Row(
                        children: [
                          _buildDashboardCard(
                            title: "Study Materials",
                            imagePath: "assets/images/material.png",
                            color: const Color(0xff6366f1),
                            onTap: () async {
                              final hasAccess = await AccessControlService.hasValidAccess();
                              if (hasAccess && context.mounted) {
                                try {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => StudyMaterials(
                                        userRole: widget.role,
                                        groupCode: widget.code
                                      ),
                                    ),
                                  );
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text("Error: ${e.toString()}")),
                                  );
                                }
                              }
                            },
                          ),
                          _buildDashboardCard(
                            title: "Chat",
                            imagePath: "assets/images/phoenix.png",
                            color: const Color(0xff10b981),
                            onTap: () async {
                              final hasAccess = await AccessControlService.hasValidAccess();
                              if (hasAccess && context.mounted) {
                                try {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => Chat(widget.role, widget.code),
                                    ),
                                  );
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text("Error: ${e.toString()}")),
                                  );
                                }
                              }
                            },
                          ),
                        ],
                      ),

                      // Second Row
                      Row(
                        children: [
                          _buildDashboardCard(
                            title: "Calendar",
                            imagePath: "assets/images/calendar.png",
                            color: const Color(0xfff59e0b),
                            onTap: () async {
                              final hasAccess = await AccessControlService.hasValidAccess();
                              if (hasAccess && context.mounted) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => Calendar(widget.uid_admin, widget.role),
                                  ),
                                );
                              }
                            },
                          ),
                          _buildDashboardCard(
                            title: "Notice",
                            imagePath: "assets/images/Notice.png",
                            color: const Color(0xffef4444),
                            onTap: () async {
                              final hasAccess = await AccessControlService.hasValidAccess();
                              if (hasAccess && context.mounted) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => Notice(widget.role, widget.code),
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ),

                      // Third Row
                      Row(
                        children: [
                          _buildDashboardCard(
                            title: "Members",
                            imagePath: "assets/images/members.png",
                            color: const Color(0xff8b5cf6),
                            onTap: () async {
                              final hasAccess = await AccessControlService.hasValidAccess();
                              if (hasAccess && context.mounted) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => MembersPage(),
                                  ),
                                );
                              }
                            },
                          ),
                          _buildDashboardCard(
                            title: "Profile",
                            imagePath: "assets/images/profile.png",
                            color: const Color(0xff06b6d4),
                            onTap: () async {
                              final hasAccess = await AccessControlService.hasValidAccess();
                              if (hasAccess && context.mounted) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const ProfileView(),
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ),

                      // Fourth Row - Poll Features
                      if (widget.role == "Administrator" || widget.role == "Co-Administrator") ...[
                        Row(
                          children: [
                            _buildDashboardCard(
                              title: "Create Poll",
                              imagePath: "assets/images/poll.png",
                              color: const Color(0xff14b8a6),
                              onTap: () async {
                                final hasAccess = await AccessControlService.hasValidAccess();
                                if (hasAccess && context.mounted) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => CreatePollPage(joinCode: widget.code.toString()),
                                    ),
                                  );
                                }
                              },
                            ),
                            _buildDashboardCard(
                              title: "View Polls",
                              imagePath: "assets/images/poll_v.png",
                              color: const Color(0xffec4899),
                              onTap: () async {
                                final hasAccess = await AccessControlService.hasValidAccess();
                                if (hasAccess && context.mounted) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ViewPollsPage(
                                        joinCode: widget.code.toString(),
                                        userRole: widget.role,
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  int _getVisibleCardsCount() {
    int baseCount = 6; // Study Materials, Chat, Calendar, Notice, Members, Profile
    if (widget.role == "Administrator" || widget.role == "Co-Administrator") {
      baseCount += 2; // Create Poll, View Polls
    }
    return baseCount;
  }
}

