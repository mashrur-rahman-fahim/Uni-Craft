import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uni_craft/Homepage.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Email/Password Sign Up with enhanced error handling
  Future<void> _signUpWithEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (userCredential.user != null) {
        // Update display name
        await userCredential.user!.updateDisplayName(_nameController.text.trim());

        // Safely create user profile
        await _safelyCreateUserProfile(userCredential.user!);

        // Send email verification (but don't require it before profile setup)
        try {
          await userCredential.user!.sendEmailVerification();
        } catch (e) {
          print('Email verification send failed: $e');
          // Continue even if email verification fails
        }

        // Navigate to profile setup instead of signing out
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const Homepage()),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      _handleFirebaseAuthError(e);
    } catch (e) {
      print('Sign-up error: $e');
      _showErrorDialog('An unexpected error occurred during sign-up. Please try again.');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Safe Google Sign Up with proper error handling
  Future<void> _signUpWithGoogle() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Clear any existing Google Sign In state
      final GoogleSignIn googleSignIn = GoogleSignIn();
      await googleSignIn.signOut();

      // Attempt Google Sign In with timeout
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Google sign-up timed out. Please try again.');
        },
      );

      if (googleUser == null) {
        // User canceled the sign-up
        return;
      }

      // Safely get authentication details
      GoogleSignInAuthentication? googleAuth;
      try {
        googleAuth = await googleUser.authentication;
      } catch (e) {
        print('Error getting Google authentication: $e');
        throw Exception('Failed to authenticate with Google. Please try again.');
      }

      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        throw Exception('Google authentication failed. Missing credentials.');
      }

      // Create Firebase credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase
      UserCredential result = await FirebaseAuth.instance.signInWithCredential(credential);

      if (result.user != null) {
        // Safely create user profile
        await _safelyCreateUserProfile(result.user!);

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const Homepage()),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      print('FirebaseAuthException: ${e.code} - ${e.message}');
      _handleFirebaseAuthError(e);
    } catch (e) {
      print('Google sign-up error: $e');
      String errorMessage = 'Google sign-up failed. ';
      if (e.toString().contains('timeout')) {
        errorMessage += 'The request timed out. Please check your connection and try again.';
      } else if (e.toString().contains('PigeonUserDetails')) {
        errorMessage += 'There was a platform communication error. Please restart the app and try again.';
      } else {
        errorMessage += 'Please try again.';
      }
      _showErrorDialog(errorMessage);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Centralized Firebase Auth error handling
  void _handleFirebaseAuthError(FirebaseAuthException e) {
    String errorMessage = 'An error occurred';

    switch (e.code) {
      case 'weak-password':
        errorMessage = 'The password provided is too weak. Please use at least 6 characters.';
        break;
      case 'email-already-in-use':
        errorMessage = 'An account already exists for that email. Please sign in instead.';
        break;
      case 'invalid-email':
        errorMessage = 'The email address is not valid.';
        break;
      case 'operation-not-allowed':
        errorMessage = 'Email/password accounts are not enabled.';
        break;
      case 'account-exists-with-different-credential':
        errorMessage = 'An account already exists with this email using a different sign-in method.';
        break;
      case 'invalid-credential':
        errorMessage = 'The credential is invalid or has expired.';
        break;
      case 'user-disabled':
        errorMessage = 'This user account has been disabled.';
        break;
      case 'network-request-failed':
        errorMessage = 'Network error. Please check your connection and try again.';
        break;
      default:
        errorMessage = e.message ?? 'An unexpected error occurred';
    }

    _showErrorDialog(errorMessage);
  }

  // Safe user profile creation with comprehensive error handling and retry logic
  Future<void> _safelyCreateUserProfile(User user) async {
    int retryCount = 0;
    const maxRetries = 3;

    while (retryCount < maxRetries) {
      try {
        // Check if user profile already exists
        final userProfileQuery = await FirebaseFirestore.instance
            .collection('userProfile')
            .where('uid', isEqualTo: user.uid)
            .get()
            .timeout(const Duration(seconds: 10));

        if (userProfileQuery.docs.isEmpty) {
          await FirebaseFirestore.instance.collection('userProfile').add({
            'uid': user.uid,
            'email': user.email ?? '',
            'name': user.displayName ?? _nameController.text.trim(),
            'photoURL': user.photoURL ?? '',
            'role': 'General member',
            'age': '',
            'rollNumber': '',
            'joinCode': '',
            'createdAt': FieldValue.serverTimestamp(),
            'isProfileComplete': false,
          }).timeout(const Duration(seconds: 10));

          print('User profile created successfully');
          return; // Success, exit the retry loop
        } else {
          print('User profile already exists');
          return; // Profile exists, no need to create
        }
      } catch (e) {
        retryCount++;
        print('Error creating user profile (attempt $retryCount): $e');

        if (retryCount >= maxRetries) {
          print('Failed to create user profile after $maxRetries attempts');
          // Don't throw here - allow the user to proceed even if profile creation fails
          // They can complete their profile later
          return;
        }

        // Wait before retrying
        await Future.delayed(Duration(seconds: retryCount));
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Success!'),
        content: const Text(
          'Account created successfully! Please check your email and click the verification link before signing in.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Go back to login
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
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
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                SizedBox(height: screenH * 0.02),

                // Logo
                Container(
                  width: screenW * 0.25,
                  height: screenW * 0.25,
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage("assets/images/logo.png"),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),

                SizedBox(height: screenH * 0.02),

                // Welcome Text
                const Text(
                  "Create Account",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),

                const Text(
                  "Join UniCraft today",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                  ),
                ),

                SizedBox(height: screenH * 0.04),

                // Name Field
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: const Icon(Icons.person, color: Color(0xff1b6e70)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xff1b6e70), width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your full name';
                    }
                    if (value.length < 2) {
                      return 'Name must be at least 2 characters';
                    }
                    return null;
                  },
                ),

                SizedBox(height: screenH * 0.02),

                // Email Field
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: const Icon(Icons.email, color: Color(0xff1b6e70)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xff1b6e70), width: 2),
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
                  decoration: InputDecoration(
                    labelText: 'Password',
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
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xff1b6e70), width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    if (!RegExp(r'^(?=.*[a-zA-Z])(?=.*\d)').hasMatch(value)) {
                      return 'Password must contain at least one letter and one number';
                    }
                    return null;
                  },
                ),

                SizedBox(height: screenH * 0.02),

                // Confirm Password Field
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    prefixIcon: const Icon(Icons.lock_outline, color: Color(0xff1b6e70)),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                        color: const Color(0xff1b6e70),
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xff1b6e70), width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your password';
                    }
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),

                SizedBox(height: screenH * 0.03),

                // Sign Up Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _signUpWithEmail,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff1b6e70),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Sign Up',
                            style: TextStyle(fontSize: 16, color: Colors.white),
                          ),
                  ),
                ),

                SizedBox(height: screenH * 0.03),

                // Divider
                const Row(
                  children: [
                    Expanded(child: Divider(color: Colors.black54)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'OR',
                        style: TextStyle(color: Colors.black54),
                      ),
                    ),
                    Expanded(child: Divider(color: Colors.black54)),
                  ],
                ),

                SizedBox(height: screenH * 0.03),

                // Google Sign Up Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _signUpWithGoogle,
                    icon: Image.asset(
                      'assets/images/google.png',
                      height: 24,
                      width: 24,
                    ),
                    label: const Text(
                      'Continue with Google',
                      style: TextStyle(fontSize: 16, color: Colors.black87),
                    ),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: const BorderSide(color: Colors.black54),
                    ),
                  ),
                ),

                SizedBox(height: screenH * 0.04),

                // Sign In Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Already have an account? ",
                      style: TextStyle(color: Colors.black54),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text(
                        'Sign In',
                        style: TextStyle(
                          color: Color(0xff1b6e70),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
