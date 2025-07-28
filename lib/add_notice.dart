import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uni_craft/services/notice_service.dart';
import 'package:uni_craft/utils.dart';

class AddNotice extends StatefulWidget {
  final dynamic code;
  final String role;
  final Map<String, dynamic>? editNotice;

  const AddNotice(this.code, this.role, {super.key, this.editNotice});

  @override
  State<AddNotice> createState() => _AddNoticeState();
}

class _AddNoticeState extends State<AddNotice> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;

  String _selectedCategory = 'general';
  String _selectedPriority = 'normal';
  DateTime? _expiryDate;
  List<String> _tags = [];
  final TextEditingController _tagController = TextEditingController();
  bool _sendNotification = true;

  final List<Map<String, dynamic>> _categories = [
    {'value': 'general', 'label': 'General', 'icon': Icons.info},
    {'value': 'academic', 'label': 'Academic', 'icon': Icons.school},
    {'value': 'event', 'label': 'Event', 'icon': Icons.event},
    {'value': 'announcement', 'label': 'Announcement', 'icon': Icons.campaign},
    {'value': 'urgent', 'label': 'Urgent', 'icon': Icons.warning},
  ];

  final List<Map<String, dynamic>> _priorities = [
    {'value': 'low', 'label': 'Low', 'color': Colors.green},
    {'value': 'normal', 'label': 'Normal', 'color': Color(0xff1b6e70)},
    {'value': 'medium', 'label': 'Medium', 'color': Colors.orange},
    {'value': 'high', 'label': 'High', 'color': Colors.red},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.editNotice != null) {
      _populateFields();
    }
  }

  void _populateFields() {
    final notice = widget.editNotice!;
    _titleController.text = notice['title'] ?? '';
    _contentController.text = notice['content'] ?? '';
    _selectedCategory = notice['category'] ?? 'general';
    _selectedPriority = notice['priority'] ?? 'normal';
    _tags = List<String>.from(notice['tags'] ?? []);

    if (notice['expiryDate'] != null) {
      _expiryDate = notice['expiryDate'].toDate();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _selectExpiryDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _expiryDate = picked;
      });
    }
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag) && _tags.length < 5) {
      setState(() {
        _tags.add(tag);
        _tagController.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  Future<void> _saveNotice() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        AppUtils.showErrorSnackBar(context, 'User not authenticated');
        return;
      }

      // Get user profile for author name
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('Profile')
          .doc(currentUser.uid)
          .get();

      String authorName = 'Unknown';
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>?;
        authorName = userData?['name'] ?? userData?['name1'] ?? 'Unknown';
      }

      bool success;
      if (widget.editNotice != null) {
        // Update existing notice
        success = await NoticeService.updateNotice(
          noticeId: widget.editNotice!['id'],
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
          category: _selectedCategory,
          priority: _selectedPriority,
          tags: _tags,
          expiryDate: _expiryDate,
        );
      } else {
        // Create new notice
        success = await NoticeService.addNotice(
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
          groupCode: widget.code.toString(),
          authorId: currentUser.uid,
          authorName: authorName,
          authorEmail: currentUser.email ?? '',
          category: _selectedCategory,
          priority: _selectedPriority,
          tags: _tags,
          expiryDate: _expiryDate,
          sendNotification: _sendNotification,
        );
      }

      if (success) {
        AppUtils.showSuccessSnackBar(
          context,
          widget.editNotice != null ? 'Notice updated successfully' : 'Notice added successfully'
        );
        Navigator.of(context).pop(true);
      } else {
        AppUtils.showErrorSnackBar(
          context,
          widget.editNotice != null ? 'Failed to update notice' : 'Failed to add notice'
        );
      }
    } catch (e) {
      AppUtils.showErrorSnackBar(context, 'Error: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isEdit = widget.editNotice != null;

    return Scaffold(
      backgroundColor: const Color(0xffb8d8d8),
      appBar: AppBar(
        title: Text(
          isEdit ? 'Edit Notice' : 'Add Notice',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xff1b6e70),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title Field
              const Text(
                'Notice Title',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xff1b6e70),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleController,
                style: const TextStyle(color: Colors.black),
                decoration: InputDecoration(
                  hintText: 'Enter notice title...',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xff4f6367)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xff1b6e70), width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xff4f6367)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a title';
                  }
                  if (value.trim().length < 3) {
                    return 'Title must be at least 3 characters';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // Category Selection
              const Text(
                'Category',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xff1b6e70),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xff4f6367)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCategory,
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedCategory = newValue!;
                      });
                    },
                    items: _categories.map<DropdownMenuItem<String>>((category) {
                      return DropdownMenuItem<String>(
                        value: category['value'],
                        child: Row(
                          children: [
                            Icon(category['icon'],
                                 color: const Color(0xff1b6e70), size: 20),
                            const SizedBox(width: 8),
                            Text(category['label']),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Priority Selection
              const Text(
                'Priority',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xff1b6e70),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xff4f6367)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedPriority,
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedPriority = newValue!;
                      });
                    },
                    items: _priorities.map<DropdownMenuItem<String>>((priority) {
                      return DropdownMenuItem<String>(
                        value: priority['value'],
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: priority['color'],
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(priority['label']),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Content Field
              const Text(
                'Notice Content',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xff1b6e70),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _contentController,
                style: const TextStyle(color: Colors.black),
                maxLines: 8,
                decoration: InputDecoration(
                  hintText: 'Enter notice content...',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xff4f6367)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xff1b6e70), width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xff4f6367)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter notice content';
                  }
                  if (value.trim().length < 10) {
                    return 'Content must be at least 10 characters';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // Tags Section
              const Text(
                'Tags (Optional)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xff1b6e70),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _tagController,
                      style: const TextStyle(color: Colors.black),
                      decoration: InputDecoration(
                        hintText: 'Add a tag...',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xff4f6367)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xff1b6e70), width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xff4f6367)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onFieldSubmitted: (_) => _addTag(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _addTag,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff1b6e70),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Icon(Icons.add, color: Colors.white),
                  ),
                ],
              ),

              // Display tags
              if (_tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: _tags.map((tag) {
                    return Chip(
                      label: Text(tag),
                      onDeleted: () => _removeTag(tag),
                      backgroundColor: const Color(0xff1b6e70).withValues(alpha: 0.1),
                      deleteIconColor: const Color(0xff1b6e70),
                    );
                  }).toList(),
                ),
              ],

              const SizedBox(height: 24),

              // Expiry Date
              const Text(
                'Expiry Date (Optional)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xff1b6e70),
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _selectExpiryDate,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xff4f6367)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, color: Color(0xff1b6e70)),
                      const SizedBox(width: 8),
                      Text(
                        _expiryDate != null
                            ? 'Expires: ${_expiryDate!.day}/${_expiryDate!.month}/${_expiryDate!.year}'
                            : 'Set expiry date',
                        style: TextStyle(
                          color: _expiryDate != null ? Colors.black : Colors.grey,
                        ),
                      ),
                      const Spacer(),
                      if (_expiryDate != null)
                        IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey),
                          onPressed: () {
                            setState(() {
                              _expiryDate = null;
                            });
                          },
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Send Notification Toggle (only for new notices)
              if (!isEdit) ...[
                Row(
                  children: [
                    Switch(
                      value: _sendNotification,
                      onChanged: (value) {
                        setState(() {
                          _sendNotification = value;
                        });
                      },
                      activeColor: const Color(0xff1b6e70),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Send push notification to all members',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xff1b6e70),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveNotice,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff1b6e70),
                    elevation: 8,
                    shadowColor: Colors.black26,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        )
                      : Text(
                          isEdit ? 'Update Notice' : 'Add Notice',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
