import 'dart:io';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:uni_craft/resources/update.dart';
import 'package:uni_craft/utils.dart';
import 'package:uni_craft/utils/auth_utils.dart';

class EditProfile extends StatefulWidget {
  final List<dynamic> profileInfo;

  const EditProfile(this.profileInfo, {super.key});

  @override
  State<EditProfile> createState() => _EditProfileState();
}

class _EditProfileState extends State<EditProfile> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  Uint8List? _image;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  late TextEditingController name;
  late TextEditingController age;
  late TextEditingController roll;
  late TextEditingController email;

  bool isDeleting = false;
  bool isSaving = false;
  bool check_for_save = false;

  String dropdownvalue = "General member";

  final items = [
    'Administrator',
    'Co-Administrator',
    'General member',
  ];

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    // Initialize controllers with existing profile data
    name = TextEditingController(text: widget.profileInfo.length > 1 ? widget.profileInfo[1].toString() : '');
    age = TextEditingController(text: widget.profileInfo.length > 2 ? widget.profileInfo[2].toString() : '');
    roll = TextEditingController(text: widget.profileInfo.length > 3 ? widget.profileInfo[3].toString() : '');
    email = TextEditingController(text: widget.profileInfo.length > 4 ? widget.profileInfo[4].toString() : '');

    // Set dropdown value
    if (widget.profileInfo.length > 5 && widget.profileInfo[5].toString().isNotEmpty) {
      String userRole = widget.profileInfo[5].toString();
      if (items.contains(userRole)) {
        dropdownvalue = userRole;
      }
    }
  }

  @override
  void dispose() {
    name.dispose();
    age.dispose();
    roll.dispose();
    email.dispose();
    super.dispose();
  }

  Future<String> uploadImagetoStorage(String childname, Uint8List file) async {
    try {
      Reference ref = _storage.ref().child(childname);
      UploadTask uploadTask = ref.putData(file);
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }

  void selectImage() async {
    try {
      Uint8List img = await AppUtils.pickImage(ImageSource.gallery);
      setState(() {
        _image = img;
      });
    } catch (e) {
      _showErrorSnackBar('Error selecting image: ${e.toString()}');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isSaving = true;
    });

    try {
      // Check internet connectivity
      try {
        final result = await InternetAddress.lookup('google.com');
        check_for_save = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      } on SocketException catch (_) {
        check_for_save = false;
        _showErrorSnackBar('No internet connection');
        setState(() {
          isSaving = false;
        });
        return;
      }

      if (!check_for_save) {
        setState(() {
          isSaving = false;
        });
        return;
      }

      final uid = FirebaseAuth.instance.currentUser!.uid;

      // Update Profile collection
      Map<String, dynamic> updates = {};

      if (name.text.trim() != widget.profileInfo[1] && name.text.trim().isNotEmpty) {
        updates['name1'] = name.text.trim();
      }
      if (age.text.trim() != widget.profileInfo[2] && age.text.trim().isNotEmpty) {
        updates['age1'] = age.text.trim();
      }
      if (email.text.trim() != widget.profileInfo[4] && email.text.trim().isNotEmpty) {
        updates['email'] = email.text.trim();
      }
      if (roll.text.trim() != widget.profileInfo[3] && roll.text.trim().isNotEmpty) {
        updates['roll'] = roll.text.trim();
      }
      if (dropdownvalue != widget.profileInfo[5] &&
          widget.profileInfo[5] != "Administrator") {
        updates['role'] = dropdownvalue;
      }

      // Update Profile document
      if (updates.isNotEmpty) {
        updates['updatedAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance
            .collection('Profile')
            .doc(uid)
            .update(updates);
      }

      // Update userProfile collection as well
      final userProfileQuery = await FirebaseFirestore.instance
          .collection('userProfile')
          .where('uid', isEqualTo: uid)
          .get();

      if (userProfileQuery.docs.isNotEmpty) {
        Map<String, dynamic> userUpdates = {};

        if (name.text.trim().isNotEmpty) userUpdates['name'] = name.text.trim();
        if (age.text.trim().isNotEmpty) userUpdates['age'] = age.text.trim();
        if (roll.text.trim().isNotEmpty) userUpdates['rollNumber'] = roll.text.trim();
        if (dropdownvalue != widget.profileInfo[5]) userUpdates['role'] = dropdownvalue;

        if (userUpdates.isNotEmpty) {
          userUpdates['updatedAt'] = FieldValue.serverTimestamp();
          await FirebaseFirestore.instance
              .collection('userProfile')
              .doc(userProfileQuery.docs.first.id)
              .update(userUpdates);
        }
      }

      // Upload new image if selected
      if (_image != null) {
        await UpdateData().savedData(file: _image!);
      }

      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        _showSuccessSnackBar('Profile updated successfully!');
        Navigator.of(context).pop();
      }
    } catch (e) {
      _showErrorSnackBar('Error updating profile: ${e.toString()}');
    } finally {
      setState(() {
        isSaving = false;
      });
    }
  }

  Future<void> _deleteProfile() async {
    // Show confirmation dialog
    bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Profile'),
        content: const Text(
          'Are you sure you want to delete your profile? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmDelete != true) return;

    setState(() {
      isDeleting = true;
    });

    try {
      // Check internet connectivity
      try {
        final result = await InternetAddress.lookup('google.com');
        check_for_save = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      } on SocketException catch (_) {
        check_for_save = false;
        _showErrorSnackBar('No internet connection');
        setState(() {
          isDeleting = false;
        });
        return;
      }

      if (!check_for_save) {
        setState(() {
          isDeleting = false;
        });
        return;
      }

      final uid = FirebaseAuth.instance.currentUser!.uid;

      // Delete from Profile collection
      await FirebaseFirestore.instance
          .collection('Profile')
          .doc(uid)
          .delete();

      // Update userProfile to mark as incomplete
      final userProfileQuery = await FirebaseFirestore.instance
          .collection('userProfile')
          .where('uid', isEqualTo: uid)
          .get();

      if (userProfileQuery.docs.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('userProfile')
            .doc(userProfileQuery.docs.first.id)
            .update({
          'isProfileComplete': false,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        _showSuccessSnackBar('Profile deleted successfully!');
        Navigator.of(context).pop();
      }
    } catch (e) {
      _showErrorSnackBar('Error deleting profile: ${e.toString()}');
    } finally {
      setState(() {
        isDeleting = false;
      });
    }
  }

  ImageProvider<Object> _getBackgroundImage() {
    if (_image != null) {
      return MemoryImage(_image!);
    } else if (widget.profileInfo.isNotEmpty &&
        widget.profileInfo[0] != null &&
        widget.profileInfo[0].toString().isNotEmpty) {
      return CachedNetworkImageProvider(widget.profileInfo[0].toString());
    } else {
      return const AssetImage('assets/images/default_profile.png');
    }
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
          'Edit Profile',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const SizedBox(height: 20),

              // Profile Image Section
              Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xff1b6e70),
                        width: 3,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.grey[300],
                      backgroundImage: _getBackgroundImage(),
                      child: (_image == null && 
                             (widget.profileInfo.isEmpty || 
                              widget.profileInfo[0] == null || 
                              widget.profileInfo[0].toString().isEmpty))
                          ? const Icon(Icons.person, size: 60, color: Colors.grey)
                          : null,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Color(0xff1b6e70),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: selectImage,
                        icon: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Role Dropdown (only for Co-Administrator)
              if (widget.profileInfo.length > 5 && widget.profileInfo[5].toString() == 'Co-Administrator')
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Role',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: dropdownvalue,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          items: items.map((String item) {
                            return DropdownMenuItem(
                              value: item,
                              child: Text(item),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              dropdownvalue = newValue!;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              // Form Fields
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Name Field
                    Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: TextFormField(
                          controller: name,
                          style: const TextStyle(fontSize: 16),
                          decoration: InputDecoration(
                            labelText: 'Full Name',
                            hintText: widget.profileInfo.length > 1 ? widget.profileInfo[1].toString() : 'Enter your full name',
                            prefixIcon: const Icon(Icons.person, color: Color(0xff1b6e70)),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xff1b6e70), width: 2),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your name';
                            }
                            if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value.trim())) {
                              return 'Please enter a valid name';
                            }
                            return null;
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Age Field
                    Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: TextFormField(
                          controller: age,
                          style: const TextStyle(fontSize: 16),
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Age',
                            hintText: widget.profileInfo.length > 2 ? widget.profileInfo[2].toString() : 'Enter your age',
                            prefixIcon: const Icon(Icons.cake, color: Color(0xff1b6e70)),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xff1b6e70), width: 2),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your age';
                            }
                            final age = int.tryParse(value.trim());
                            if (age == null || age < 1 || age > 120) {
                              return 'Please enter a valid age';
                            }
                            return null;
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Email Field
                    Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: TextFormField(
                          controller: email,
                          style: const TextStyle(fontSize: 16),
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: 'Email Address',
                            hintText: widget.profileInfo.length > 4 ? widget.profileInfo[4].toString() : 'Enter your email',
                            prefixIcon: const Icon(Icons.email, color: Color(0xff1b6e70)),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xff1b6e70), width: 2),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your email';
                            }
                            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                              return 'Please enter a valid email address';
                            }
                            return null;
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Roll Number Field
                    Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: TextFormField(
                          controller: roll,
                          style: const TextStyle(fontSize: 16),
                          keyboardType: TextInputType.text,
                          decoration: InputDecoration(
                            labelText: 'Roll Number',
                            hintText: widget.profileInfo.length > 3 ? widget.profileInfo[3].toString() : 'Enter your roll number',
                            prefixIcon: const Icon(Icons.numbers, color: Color(0xff1b6e70)),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xff1b6e70), width: 2),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your roll number';
                            }
                            return null;
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: isSaving ? null : _saveProfile,
                      icon: isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.save, color: Colors.white),
                      label: Text(
                        isSaving ? 'Saving...' : 'Save Changes',
                        style: const TextStyle(
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
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isDeleting ? null : _deleteProfile,
                      icon: isDeleting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red),
                            )
                          : const Icon(Icons.delete, color: Colors.red),
                      label: Text(
                        isDeleting ? 'Deleting...' : 'Delete Profile',
                        style: const TextStyle(
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

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
