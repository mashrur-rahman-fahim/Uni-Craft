import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uni_craft/auth-page.dart';
import 'package:uni_craft/Homepage.dart';
import 'package:uni_craft/dashboard.dart';

class Splash extends StatefulWidget {
  const Splash({super.key});

  @override
  State<Splash> createState() => _SplashState();
}

class _SplashState extends State<Splash> {
  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  void _checkAuthStatus() async {
    // Add a small delay to show splash screen
    await Future.delayed(const Duration(seconds: 2));

    // Check if user is already signed in
    User? user = FirebaseAuth.instance.currentUser;

    if (mounted) {
      if (user != null && user.emailVerified) {
        // User is signed in and verified, check if profile is complete
        final profileData = await _checkProfileCompletion(user.uid);
        
        if (profileData != null) {
          // Profile is complete, navigate to dashboard
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => Dashboard(
                profileData['role'], 
                user.uid, 
                profileData['code']
              ),
            ),
          );
        } else {
          // Profile incomplete, navigate to homepage for profile setup
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const Homepage()),
          );
        }
      } else {
        // User is not signed in or email not verified, navigate to auth page
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const AuthPage()),
        );
      }
    }
  }

  Future<Map<String, dynamic>?> _checkProfileCompletion(String uid) async {
    try {
      // Check if profile exists in Profile collection (complete profile)
      final profileQuery = await FirebaseFirestore.instance
          .collection('Profile')
          .where('uid', isEqualTo: uid)
          .get();

      if (profileQuery.docs.isNotEmpty) {
        final profileData = profileQuery.docs.first.data();
        final role = profileData['role'];
        final code = profileData['code'];
        
        // Return profile data if complete
        if (role != null && code != null) {
          return {
            'role': role,
            'code': code,
          };
        }
      }

      // Check userProfile collection for basic profile data
      final userProfileQuery = await FirebaseFirestore.instance
          .collection('userProfile')
          .where('uid', isEqualTo: uid)
          .get();

      if (userProfileQuery.docs.isNotEmpty) {
        final userData = userProfileQuery.docs.first.data();
        final isComplete = userData['isProfileComplete'] ?? false;
        
        if (isComplete) {
          final role = userData['role'];
          final code = userData['generatedCode'] ?? userData['joinCode'];
          
          if (role != null && code != null) {
            return {
              'role': role,
              'code': code,
            };
          }
        }
      }

      return null; // Profile incomplete
    } catch (e) {
      print('Error checking profile completion: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff1b6e70),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App Logo
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: const Icon(
                Icons.school,
                size: 60,
                color: Color(0xff1b6e70),
              ),
            ),
            
            const SizedBox(height: 30),
            
            // App Name
            const Text(
              'UniCraft',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 2,
              ),
            ),
            
            const SizedBox(height: 10),
            
            // App Tagline
            const Text(
              'University Management Made Easy',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
                fontWeight: FontWeight.w300,
              ),
            ),
            
            const SizedBox(height: 50),
            
            // Loading Indicator
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              strokeWidth: 3,
            ),
          ],
        ),
      ),
    );
  }
}
