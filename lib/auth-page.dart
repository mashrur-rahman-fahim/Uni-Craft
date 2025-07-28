import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uni_craft/Homepage.dart';
import 'package:uni_craft/register.dart';
import 'package:uni_craft/Forgotpass.dart';
import 'package:uni_craft/services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uni_craft/dashboard.dart';

class AuthPage extends StatefulWidget {
  final bool fromLogout;
  const AuthPage({super.key, this.fromLogout = false});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    // If coming from logout, don't auto-check authentication
    if (!widget.fromLogout) {
      _checkExistingAuth();
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Check if user is already authenticated and has profile
  Future<void> _checkExistingAuth() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.emailVerified) {
      // Small delay to avoid instant navigation
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        await _navigateBasedOnProfile();
      }
    }
  }

  // Enhanced Email/Password Sign In using AuthService
  Future<void> _signInWithEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await AuthService.signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (mounted) {
        // Check profile completion and navigate accordingly
        await _navigateBasedOnProfile();
      }
    } on FirebaseAuthException catch (e) {
      _handleFirebaseAuthError(e);
    } catch (e) {
      debugPrint('Sign-in error: $e');
      _showErrorDialog('An unexpected error occurred. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Optimized Google Sign In using AuthService
  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final UserCredential? userCredential = await AuthService.signInWithGoogle();

      // Check if user is signed in (either through UserCredential or linked account)
      User? currentUser = FirebaseAuth.instance.currentUser;

      if ((userCredential != null && userCredential.user != null) || currentUser != null) {
        if (mounted) {
          // Check profile completion and navigate accordingly
          await _navigateBasedOnProfile();
        }
      }
      // If both are null, user cancelled the sign-in

    } catch (e) {
      debugPrint('Google sign-in error: $e');
      _showErrorDialog('Google sign-in failed. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // New method to check profile and navigate accordingly
  Future<void> _navigateBasedOnProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Check if profile exists in Profile collection (complete profile)
      final profileQuery = await FirebaseFirestore.instance
          .collection('Profile')
          .where('uid', isEqualTo: user.uid)
          .get();

      if (profileQuery.docs.isNotEmpty) {
        final profileData = profileQuery.docs.first.data();
        final role = profileData['role'];
        final code = profileData['code'];

        if (role != null && code != null) {
          // Profile is complete, navigate to dashboard
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => Dashboard(role, user.uid, code),
            ),
          );
          return;
        }
      }

      // Check userProfile collection for basic profile data
      final userProfileQuery = await FirebaseFirestore.instance
          .collection('userProfile')
          .where('uid', isEqualTo: user.uid)
          .get();

      if (userProfileQuery.docs.isNotEmpty) {
        final userData = userProfileQuery.docs.first.data();
        final isComplete = userData['isProfileComplete'] ?? false;

        if (isComplete) {
          final role = userData['role'];
          final code = userData['generatedCode'] ?? userData['joinCode'];

          if (role != null && code != null) {
            // Profile is complete, navigate to dashboard
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => Dashboard(role, user.uid, code),
              ),
            );
            return;
          }
        }
      }

      // Profile incomplete or doesn't exist, navigate to profile setup
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const Homepage()),
      );

    } catch (e) {
      debugPrint('Error checking profile: $e');
      // On error, default to profile setup
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const Homepage()),
      );
    }
  }

  // Enhanced Firebase Auth error handling
  void _handleFirebaseAuthError(FirebaseAuthException e) {
    String errorMessage = 'An error occurred';

    switch (e.code) {
      case 'user-not-found':
        errorMessage = 'No user found for that email.';
        break;
      case 'wrong-password':
        errorMessage = 'Wrong password provided.';
        break;
      case 'invalid-email':
        errorMessage = 'The email address is not valid.';
        break;
      case 'user-disabled':
        errorMessage = 'This user account has been disabled.';
        break;
      case 'too-many-requests':
        errorMessage = 'Too many attempts. Please try again later.';
        break;
      case 'invalid-credential':
        errorMessage = 'Invalid email or password.';
        break;
      case 'account-exists-with-different-credential':
        errorMessage = 'An account already exists with this email using a different sign-in method. Please sign in with your email and password first, then link your Google account from profile settings.';
        break;
      case 'operation-not-allowed':
        errorMessage = 'This sign-in method is not enabled for this project.';
        break;
      case 'network-request-failed':
        errorMessage = 'Network error. Please check your connection and try again.';
        break;
      case 'google-sign-in-failed':
        errorMessage = 'Google sign-in failed. Please try again.';
        break;
      case 'missing-auth-tokens':
        errorMessage = 'Authentication failed. Please try again.';
        break;
      default:
        errorMessage = e.message ?? 'An unexpected error occurred';
    }

    _showErrorDialog(errorMessage);
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xff35797a),
        title: const Text(
          'Authentication Error',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'OK',
              style: TextStyle(color: Colors.white),
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: screenH * 0.08),

                // Logo
                Container(
                  width: screenW * 0.3,
                  height: screenW * 0.3,
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage("assets/images/logo.png"),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),

                SizedBox(height: screenH * 0.04),

                // Welcome Text
                const Text(
                  "Welcome to UniCraft!",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),

                const Text(
                  "Sign in to continue",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                  ),
                ),

                SizedBox(height: screenH * 0.05),

                // Email Field
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.black),
                  decoration: InputDecoration(
                    labelText: 'Email Address',
                    labelStyle: const TextStyle(color: Colors.black54),
                    prefixIcon: const Icon(Icons.email, color: Color(0xff1b6e70)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: const BorderSide(color: Color(0xff4f6367)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: const BorderSide(color: Color(0xff1b6e70), width: 2),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: const BorderSide(color: Color(0xff4f6367)),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),

                SizedBox(height: screenH * 0.02),

                // Password Field
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: const TextStyle(color: Colors.black),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    labelStyle: const TextStyle(color: Colors.black54),
                    prefixIcon: const Icon(Icons.lock, color: Color(0xff1b6e70)),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility : Icons.visibility_off,
                        color: const Color(0xff1b6e70),
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: const BorderSide(color: Color(0xff4f6367)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: const BorderSide(color: Color(0xff1b6e70), width: 2),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: const BorderSide(color: Color(0xff4f6367)),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),

                SizedBox(height: screenH * 0.01),

                // Forgot Password
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ForgotPasswordPage()),
                      );
                    },
                    child: const Text(
                      'Forgot Password?',
                      style: TextStyle(
                        color: Color(0xff1b6e70),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                SizedBox(height: screenH * 0.03),

                // Sign In Button
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _signInWithEmail,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff1b6e70),
                      elevation: 8,
                      shadowColor: Colors.black26,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          )
                        : const Text(
                            'Sign In',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),

                SizedBox(height: screenH * 0.04),

                // Divider
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 1,
                        color: Colors.black54,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'OR',
                        style: TextStyle(
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 1,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: screenH * 0.04),

                // Google Sign In Button
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _signInWithGoogle,
                    icon: Image.asset(
                      'assets/images/google.png',
                      height: 24,
                      width: 24,
                    ),
                    label: const Text(
                      'Continue with Google',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      elevation: 4,
                      shadowColor: Colors.black26,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      side: const BorderSide(color: Colors.black26),
                    ),
                  ),
                ),

                SizedBox(height: screenH * 0.05),

                // Sign Up Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Don't have an account? ",
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: 16,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const RegisterPage()),
                        );
                      },
                      child: const Text(
                        'Sign Up',
                        style: TextStyle(
                          color: Color(0xff1b6e70),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: screenH * 0.02),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
