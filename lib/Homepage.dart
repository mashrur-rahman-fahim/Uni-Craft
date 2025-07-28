import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';

import 'package:uni_craft/resources/data.dart';
import 'package:uni_craft/utils.dart';
import 'package:uni_craft/dashboard.dart';

final formKey = GlobalKey<FormState>();

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  var name = TextEditingController();
  var age = TextEditingController();
  var roll = TextEditingController();
  var email = TextEditingController();
  var count = 0;
  var join_code = TextEditingController();
  final currentUser = FirebaseAuth.instance;
  bool check_for_save = false;
  var x = 0;
  var data = 1;
  var y;
  int c = 0;
  var val_join = false;
  var join_check = false;
  String dropdownvalue = 'Choose a ROLE';
  List token = [];
  var same_dev = false;

  var items = [
    'Choose a ROLE',
    'Administrator',
    'Co-Administrator',
    'General member',
  ];

  Uint8List? _image;

  String get email1 => FirebaseAuth.instance.currentUser?.email ?? '';

  @override
  void initState() {
    super.initState();
    _initializeProfile();
  }

  Future<void> _initializeProfile() async {
    // Initialize email field with current user's email
    if (FirebaseAuth.instance.currentUser != null) {
      email.text = FirebaseAuth.instance.currentUser!.email ?? '';

      // Check if user already has a profile and redirect to dashboard if complete
      await _checkExistingProfile();
    }
  }

  Future<void> _checkExistingProfile() async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;

      // Check if profile exists in Profile collection (complete profile)
      final profileQuery = await FirebaseFirestore.instance
          .collection('Profile')
          .where('uid', isEqualTo: uid)
          .get();

      if (profileQuery.docs.isNotEmpty && mounted) {
        final profileData = profileQuery.docs.first.data();
        final role = profileData['role'];
        final code = profileData['code'];

        // Navigate to dashboard if profile is complete
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => Dashboard(role, uid, code),
          ),
        );
        return;
      }

      // Check userProfile collection for basic profile data
      final userProfileQuery = await FirebaseFirestore.instance
          .collection('userProfile')
          .where('uid', isEqualTo: uid)
          .get();

      if (userProfileQuery.docs.isNotEmpty) {
        final userData = userProfileQuery.docs.first.data();

        // Pre-fill form if data exists
        if (userData['name']?.toString().isNotEmpty == true) {
          name.text = userData['name'];
        }
        if (userData['age']?.toString().isNotEmpty == true) {
          age.text = userData['age'];
        }
        if (userData['rollNumber']?.toString().isNotEmpty == true) {
          roll.text = userData['rollNumber'];
        }
        if (userData['role']?.toString().isNotEmpty == true && userData['role'] != 'Choose a ROLE') {
          dropdownvalue = userData['role'];
        }
        if (userData['joinCode']?.toString().isNotEmpty == true) {
          join_code.text = userData['joinCode'];
        }

        setState(() {});
      }
    } catch (e) {
      print('Error checking existing profile: $e');
    }
  }

  @override
  void dispose() {
    name.dispose();
    age.dispose();
    roll.dispose();
    email.dispose();
    join_code.dispose();
    super.dispose();
  }

  Future<void> signout() async {
    try {
      final GoogleSignIn googleSign = GoogleSignIn();
      await googleSign.signOut();
      await FirebaseAuth.instance.signOut();

      // Navigate back to auth page after successful sign out
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/auth',
          (route) => false,
        );
      }
    } catch (e) {
      // Show error if sign out fails
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void selectImage() async {
    try {
      Uint8List img = await pickImage(ImageSource.gallery);
      setState(() {
        _image = img;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting image: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> saveProfile() async {
    if (!formKey.currentState!.validate()) return;

    // Check internet connectivity
    try {
      final result = await InternetAddress.lookup('google.com');
      check_for_save = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      check_for_save = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No internet connection'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (!check_for_save) return;

    // Validate required fields
    if (dropdownvalue == 'Choose a ROLE') {
      _showErrorDialog("Please select a role");
      return;
    }

    // Validate administrator code generation
    if (x == 0 && dropdownvalue == 'Administrator') {
      _showErrorDialog("Please Generate a Code first");
      return;
    }

    // Validate join code for non-administrators
    if (dropdownvalue != "Administrator" && !val_join) {
      _showErrorDialog("Invalid joining code. Please check and try again.");
      return;
    }

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final uid = currentUser.currentUser!.uid;
      final name1 = name.text.trim();
      final age1 = age.text.trim();
      final roll1 = roll.text.trim();
      final email1 = email.text.trim();
      final role = dropdownvalue;
      
      // Determine the code to use
      final codeToSave = dropdownvalue == 'Administrator' ? x : y;
      
      // No longer collecting FCM tokens since notifications are removed
      String token1 = "";

      print('Saving profile with:');
      print('Name: $name1');
      print('Age: $age1');
      print('Role: $role');
      print('Code: $codeToSave');
      print('Has image: ${_image != null}');

      String result = "Error";

      if (_image != null) {
        // Try to save with image first
        try {
          result = await StoreData().savedData(
            name: name1,
            age: age1,
            file: _image!,
            roll: roll1,
            email: email1,
            role: role,
            token: token1,
            code: codeToSave,
          );
        } catch (e) {
          print('Image upload failed: $e');
          
          // If image upload fails due to storage permissions, save without image
          if (e.toString().contains('Storage access denied') || 
              e.toString().contains('unauthorized')) {
            
            // Show option to continue without image
            bool? continueWithoutImage = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Image Upload Failed'),
                content: const Text(
                  'Unable to upload profile image due to storage permissions. Would you like to continue without a profile image?'
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Continue'),
                  ),
                ],
              ),
            );

            if (continueWithoutImage == true) {
              result = await _saveProfileWithoutImage(
                uid, name1, age1, roll1, email1, role, token1, codeToSave
              );
            } else {
              if (mounted) {
                Navigator.of(context).pop(); // Close loading dialog
              }
              return;
            }
          } else {
            rethrow;
          }
        }
      } else {
        // Save without image if no image selected
        result = await _saveProfileWithoutImage(
          uid, name1, age1, roll1, email1, role, token1, codeToSave
        );
      }

      print('Save result: $result');

      if (result == 'Success') {
        // Update userProfile collection to mark profile as complete
        final userProfileQuery = await FirebaseFirestore.instance
            .collection('userProfile')
            .where('uid', isEqualTo: uid)
            .get();

        if (userProfileQuery.docs.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('userProfile')
              .doc(userProfileQuery.docs.first.id)
              .update({
            'name': name1,
            'age': age1,
            'rollNumber': roll1,
            'role': role,
            'joinCode': dropdownvalue != 'Administrator' ? join_code.text : '',
            'generatedCode': dropdownvalue == 'Administrator' ? codeToSave.toString() : '',
            'isProfileComplete': true,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          // Create new userProfile document if it doesn't exist
          await FirebaseFirestore.instance
              .collection('userProfile')
              .add({
            'uid': uid,
            'email': email1,
            'name': name1,
            'age': age1,
            'rollNumber': roll1,
            'role': role,
            'joinCode': dropdownvalue != 'Administrator' ? join_code.text : '',
            'generatedCode': dropdownvalue == 'Administrator' ? codeToSave.toString() : '',
            'photoURL': '',
            'isProfileComplete': true,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }

        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) {
          Navigator.of(context).pop(); // Close loading dialog
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => Dashboard(role, uid, codeToSave),
            ),
          );
        }
      } else {
        if (mounted) {
          Navigator.of(context).pop(); // Close loading dialog
          _showErrorDialog("Failed to save profile: $result");
        }
      }
    } catch (e) {
      print('Error in saveProfile: $e');
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        _showErrorDialog("Error saving profile: ${e.toString()}");
      }
    }
  }

  Future<String> _saveProfileWithoutImage(
    String uid, String name, String age, String roll, String email, 
    String role, String token, dynamic code
  ) async {
    try {
      // Prepare user data without image
      Map<String, dynamic> userData = {
        'name': name,
        'age': age,
        'roll': roll,
        'email': email,
        'uid': uid,
        'imageLink': '', // Empty image link
        'role': role,
        'code': code.toString(),
        'token': token,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isActive': true,
      };

      // Save to Profile collection
      await FirebaseFirestore.instance
          .collection("Profile")
          .doc(uid)
          .set(userData);

      print('Profile saved without image successfully');
      return 'Success';
    } catch (e) {
      print('Error saving profile without image: $e');
      return 'Error: ${e.toString()}';
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          elevation: 51,
          shadowColor: Colors.black26,
          icon: const Icon(Icons.warning_amber),
          iconColor: const Color(0xffff8080),
          backgroundColor: const Color(0xff35797a),
          title: Text(
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
        );
      },
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
        title: const Text('Profile Setup'),
        actions: [
          IconButton(
            onPressed: signout,
            icon: const Icon(Icons.logout),
          )
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // StreamBuilder to check if profile exists
              StreamBuilder<QuerySnapshot>(
                stream: currentUser.currentUser != null
                    ? FirebaseFirestore.instance
                        .collection("userProfile")
                        .where('uid', isEqualTo: currentUser.currentUser!.uid)
                        .snapshots()
                    : Stream.empty(),
                builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                  if (snapshot.hasData) {
                    data = snapshot.data!.docs.length;
                  }
                  return const SizedBox.shrink();
                },
              ),

              SizedBox(height: screenH * 0.02),

              const Text(
                "Set up your profile!",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 25,
                  color: Colors.black,
                ),
              ),

              SizedBox(height: screenH * 0.03),

              // Profile Image
              Stack(
                children: [
                  _image != null
                      ? CircleAvatar(
                          radius: 51,
                          backgroundImage: MemoryImage(_image!),
                        )
                      : const CircleAvatar(
                          radius: 51,
                          backgroundImage: AssetImage("assets/images/profile.png"),
                          backgroundColor: Color(0xff1b6e70),
                        ),
                  Positioned(
                    bottom: -5,
                    right: -7,
                    child: IconButton(
                      onPressed: selectImage,
                      icon: const Icon(
                        Icons.add_a_photo,
                        color: Color(0xffe0feff),
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: screenH * 0.03),

              // Role Dropdown
              DropdownButton<String>(
                value: dropdownvalue,
                dropdownColor: const Color(0xffb7eced),
                borderRadius: BorderRadius.circular(12),
                icon: const Icon(Icons.keyboard_arrow_down),
                items: items.map((String items) {
                  return DropdownMenuItem(
                    value: items,
                    child: Text(
                      items,
                      style: const TextStyle(color: Colors.black),
                    ),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    dropdownvalue = newValue!;
                  });
                },
              ),

              SizedBox(height: screenH * 0.02),

              // Form Fields
              Form(
                key: formKey,
                child: Column(
                  children: [
                    // Name Field
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: screenW * 0.05),
                      child: TextFormField(
                        style: const TextStyle(color: Colors.black),
                        controller: name,
                        decoration: InputDecoration(
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              width: 2,
                              color: Color(0xff4f6367),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              width: 2,
                              color: Color(0xff4f6367),
                            ),
                          ),
                          labelText: "Name",
                          labelStyle: const TextStyle(color: Colors.black),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty || !RegExp(r'[a-zA-Z]').hasMatch(value)) {
                            return "Enter your name";
                          }
                          return null;
                        },
                      ),
                    ),

                    SizedBox(height: screenH * 0.02),

                    // Age Field
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: screenW * 0.05),
                      child: TextFormField(
                        style: const TextStyle(color: Colors.black),
                        controller: age,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              width: 2,
                              color: Color(0xff4f6367),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              width: 2,
                              color: Color(0xff4f6367),
                            ),
                          ),
                          labelText: "Age",
                          labelStyle: const TextStyle(color: Colors.black),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "Enter your age";
                          }

                          int? ageValue = int.tryParse(value);
                          if (ageValue == null) {
                            return "Enter a valid age";
                          }

                          if (ageValue < 12) {
                            return "Age must be at least 16";
                          }

                          if (ageValue > 80) {
                            return "Age must be less than 80";
                          }

                          return null;
                        },
                      ),
                    ),

                    SizedBox(height: screenH * 0.02),

                    // Email Field
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: screenW * 0.05),
                      child: TextFormField(
                        style: const TextStyle(color: Colors.black),
                        controller: email,
                        decoration: InputDecoration(
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              width: 2,
                              color: Color(0xff4f6367),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              width: 2,
                              color: Color(0xff4f6367),
                            ),
                          ),
                          labelText: "Email Address",
                          labelStyle: const TextStyle(color: Colors.black),
                          hintText: email1,
                          hintStyle: const TextStyle(color: Colors.black26, fontSize: 15),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty || !value.contains('@') || !value.contains('.')) {
                            return "Enter a valid email address";
                          }
                          return null;
                        },
                      ),
                    ),

                    SizedBox(height: screenH * 0.02),

                    // Roll Number Field
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: screenW * 0.05),
                      child: TextFormField(
                        style: const TextStyle(color: Colors.black),
                        controller: roll,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              width: 2,
                              color: Color(0xff4f6367),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              width: 2,
                              color: Color(0xff4f6367),
                            ),
                          ),
                          labelText: "Roll Number",
                          labelStyle: const TextStyle(color: Colors.black),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty || !RegExp(r'[0-9]').hasMatch(value)) {
                            return "Enter your roll number";
                          }
                          return null;
                        },
                      ),
                    ),

                    SizedBox(height: screenH * 0.02),

                    // Join Code Section
                    dropdownvalue == "Administrator"
                        ? Container(
                            height: 50,
                            child: x != 0
                                ? Text(
                                    "Join code: $x",
                                    style: TextStyle(
                                      color: Colors.grey.shade800,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 19,
                                    ),
                                  )
                                : Text(
                                    "Please Generate Code",
                                    style: TextStyle(
                                      color: Colors.grey.shade800,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 19,
                                    ),
                                  ),
                          )
                        : Padding(
                            padding: EdgeInsets.symmetric(horizontal: screenW * 0.05),
                            child: TextFormField(
                              style: const TextStyle(color: Colors.black),
                              controller: join_code,
                              decoration: InputDecoration(
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    width: 2,
                                    color: Color(0xff4f6367),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    width: 2,
                                    color: Color(0xff4f6367),
                                  ),
                                ),
                                labelText: "Joining Code",
                                labelStyle: const TextStyle(color: Colors.black),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return "Enter joining code";
                                }
                                return null;
                              },
                            ),
                          ),
                  ],
                ),
              ),

              // StreamBuilder for join code validation
              dropdownvalue != 'Administrator'
                  ? StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('Profile')
                          .snapshots(),
                      builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                        if (snapshot.hasData) {
                          c = 0;
                          final res = snapshot.data?.docs.toList();

                          for (var r in res!) {
                            c++;
                            if (r['code'].toString() == join_code.text) {
                              try {
                                token.add(r['token']);
                              } catch (e) {
                                // Handle error
                              }
                            }

                            if (r['code'].toString() == join_code.text && r['role'] == "Administrator") {
                              val_join = true;
                              y = snapshot.data!.docs[c - 1]['code'];
                              break;
                            } else {
                              val_join = false;
                            }
                          }
                        }
                        return const SizedBox.shrink();
                      },
                    )
                  : const SizedBox.shrink(),

              SizedBox(height: screenH * 0.04),

              // Action Buttons
              dropdownvalue == "Administrator"
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xff35797a),
                            elevation: 6,
                            shadowColor: Colors.grey,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            setState(() {
                              if (x == 0) x = UniqueKey().hashCode.abs();
                            });
                          },
                          child: const Text(
                            "Generate Code",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xff35797a),
                            elevation: 6,
                            shadowColor: Colors.grey,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: saveProfile,
                          child: const Text(
                            "Save Profile",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    )
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff35797a),
                        elevation: 6,
                        shadowColor: Colors.grey,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                      ),
                      onPressed: saveProfile,
                      child: const Text(
                        "Save Profile",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),

              SizedBox(height: screenH * 0.03),
            ],
          ),
        ),
      ),
    );
  }
}
